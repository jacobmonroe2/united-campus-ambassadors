#!/usr/bin/env bash
# Regenerates artifact.html (the Claude Artifact copy) from index.html.
# index.html is the source of truth — edit it, then run: bash build-artifact.sh
set -euo pipefail
cd "$(dirname "$0")"
{
  sed -n "/ART-A-START/,/ART-A-END/{//!p}" index.html
  sed -n "/ART-B-START/,/ART-B-END/{//!p}" index.html
} > artifact.html
echo "artifact.html rebuilt ($(wc -l < artifact.html) lines)"
