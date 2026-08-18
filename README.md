# United Campus Ambassadors

A one-page site where students find their campus ambassador, request a meeting, and see
upcoming events. Four campuses, each with an airport-style school code: Howard (HOW),
Michigan (UMI), Illinois (ILL), Purdue (PUR).

No build step, no backend, no dependencies — one HTML file.

## Editing the roster

Everything you need to change lives in one block near the bottom of `index.html`, under
`ROSTER DATA`. Three arrays:

**`SCHOOLS`** — the four campuses. You shouldn't need to touch this unless a campus is added.

**`AMBASSADORS`** — one object per person:

```js
{ name:'Amara Bell', school:'howard', year:'Class of 2026', major:'Computer Science',
  email:'amara.bell@bison.howard.edu',
  booking:'',                                  // Calendly/Google link, or '' to use the form
  focus:['Tech roles','Resume review'],        // shows as tags on the card
  bio:'One sentence on what you can help with.',
  placeholder:true }                           // set false once the details are real
```

- `school` must match a `SCHOOLS` id: `howard`, `michigan`, `uiuc`, `purdue`.
- `email` — any address containing `add-email` is treated as missing: the Email
  button is hidden and the person is left out of meeting/RSVP recipients until
  you put the real address in.
- `photo` — a key into the `PHOTOS` block. Photos are embedded by
  `embed-photos.ps1`: edit the file-path map at the top of that script, then run
  it (right-click → Run with PowerShell). It crops each portrait square,
  shrinks it to 320px, and writes it into `index.html` between the
  `PHOTOS-START`/`PHOTOS-END` markers. Never hand-edit that block.
- `booking` — paste a scheduling link and the card's **Book time** button goes straight
  there. Leave it as `''` and the button jumps to the meeting request form instead.
- `placeholder:true` shows an amber **SAMPLE** flag on the card. Flip it to `false` when
  the person's real details are in. **All eight are currently `true`.**

Adding a ninth ambassador is one more object in the array — counts, filters, the form and
the RSVP recipients all update on their own.

**`EVENTS`** — one object per event:

```js
{ date:'2026-09-10', time:'6:00 PM', school:'howard', kind:'info',
  title:'Careers at United: fall info session',
  place:'Blackburn Center, Room 148',
  note:'Recruiters on site. RSVP requested.',
  placeholder:true }
```

- `date` must be `YYYY-MM-DD`. Events sort by date automatically; past ones are not hidden,
  so delete them when they're done.
- `school:'all'` puts an event on every campus's board.
- `kind` is `info`, `career` or `social` — it sets the colored label.
- **RSVP** opens an email to every ambassador at that campus.

## Publishing

**GitHub Pages** — push this folder to a repo, then Settings → Pages → deploy from
`main` / root. `index.html` is served as-is.

**Anywhere else** — `index.html` is fully self-contained. Drag it into Netlify, Vercel,
or any web host.

**Claude Artifact** — `artifact.html` is a generated copy with the `<html>`/`<head>`/`<body>`
wrapper stripped, which is the format Artifacts expect. After editing `index.html`:

```bash
bash build-artifact.sh
```

Then republish `artifact.html`. Never edit `artifact.html` by hand — it gets overwritten.

## Live job postings

The "Open roles right now" section reads `united-jobs.json`, which is generated from
United's careers site by `fetch-jobs.mjs` (the careers pages embed their search results
as JSON, so the script just downloads a few pages and extracts it — no API keys).

- **On GitHub Pages** this is automatic: `.github/workflows/update-jobs.yml` reruns the
  script daily (~6am ET) and commits the file when it changes. You can also trigger it
  manually from the repo's Actions tab ("Run workflow").
- The feed prefers roles with intern/co-op/graduate/student in the title; when none are
  posted (they're seasonal — most drop in early fall), it shows the newest US postings
  with a note saying so.
- Where the JSON can't load (the Claude Artifact preview, opening the file directly),
  the section falls back to two buttons linking to United's student programs page and
  the full job search — so it's never broken, just less live.
- To refresh by hand on a machine with Node 18+: `node fetch-jobs.mjs`.

## Notes

- The meeting form composes a `mailto:` — nothing is stored or sent anywhere. **Copy the
  email** is the fallback for students whose browser has no mail app configured.
- Single light theme, matching united.com (which doesn't ship a dark mode).
- The footer states this is a student-run page and not an official United Airlines site.
  Keep that line — it's what makes the United-styled design safe to publish.
