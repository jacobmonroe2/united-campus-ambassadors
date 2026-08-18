// Fetches current job postings from careers.united.com and writes united-jobs.json.
// The careers site embeds its search results as JSON (phApp.ddo) in the page HTML,
// so this just downloads a few search pages and extracts that block. No API keys.
// Runs on a schedule via .github/workflows/update-jobs.yml — Node 18+, no deps.
import { writeFileSync } from 'node:fs';

const BASE = 'https://careers.united.com/us/en/search-results';
const HEADERS = {
  'user-agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36',
  'accept': 'text/html',
};
const STUDENT_RE = /\bintern(ship)?\b|co-?op|early.?career|graduate|student|university/i;

function extractDdo(html) {
  const key = 'phApp.ddo = ';
  const i = html.indexOf(key);
  if (i < 0) return null;
  let depth = 0, start = i + key.length, end = -1, inStr = false, esc = false;
  for (let p = start; p < html.length; p++) {
    const c = html[p];
    if (inStr) { if (esc) esc = false; else if (c === '\\') esc = true; else if (c === '"') inStr = false; continue; }
    if (c === '"') inStr = true;
    else if (c === '{') depth++;
    else if (c === '}') { depth--; if (!depth) { end = p + 1; break; } }
  }
  return end < 0 ? null : JSON.parse(html.slice(start, end));
}

async function jobsFor(qs) {
  const res = await fetch(`${BASE}?${qs}`, { headers: HEADERS });
  if (!res.ok) throw new Error(`${res.status} for ${qs}`);
  const ddo = extractDdo(await res.text());
  return ddo?.eagerLoadRefineSearch?.data?.jobs ?? [];
}

const slim = j => ({
  id: j.jobId, title: j.title, city: j.city, state: j.state, country: j.country,
  category: j.category, level: j.jobLevel, posted: (j.postedDate || '').slice(0, 10),
  // the embedded data has no canonical page URL; ID-only links resolve fine
  url: `https://careers.united.com/us/en/job/${j.jobId}`,
});

// Student/early-career roles: sweep a few keyword searches, keep title matches
const seen = new Map();
for (const kw of ['intern', 'co-op', 'graduate', 'student', 'university']) {
  for (const j of await jobsFor(`keywords=${encodeURIComponent(kw)}`)) {
    if (!seen.has(j.jobId)) seen.set(j.jobId, slim(j));
  }
}
const student = [...seen.values()].filter(j => STUDENT_RE.test(j.title));

// Newest US postings overall (two pages of 10)
const recent = [];
for (const from of [0, 10]) {
  for (const j of await jobsFor(`sortBy=${encodeURIComponent('Most recent')}&from=${from}`)) {
    const s = slim(j);
    if (s.country === 'United States' && !recent.some(r => r.id === s.id)) recent.push(s);
  }
}

const out = {
  updated: new Date().toISOString().slice(0, 10),
  student,
  recent: recent.slice(0, 12),
};
writeFileSync(new URL('./united-jobs.json', import.meta.url), JSON.stringify(out, null, 2) + '\n');
console.log(`united-jobs.json: ${student.length} student roles, ${out.recent.length} recent postings`);
