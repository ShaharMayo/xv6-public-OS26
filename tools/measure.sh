#!/bin/sh
# Run schedtest under one scheduling policy and save its table as a TSV file.
# Invoked by `make measure SCHED=<policy> [QUANTUM=<n>]`.

die() { printf '\n*** %s\n' "$*" >&2; exit 1; }

ROOT=$(git rev-parse --show-toplevel) || die "Not inside the course repository."
cd "$ROOT"
command -v python3 >/dev/null || die "python3 is required."

OUT="results_${SCHED}_q${QUANTUM}.tsv"
RAW=$(mktemp) || die "mktemp failed"
trap 'rm -f "$RAW"' EXIT INT TERM

printf '==> Running schedtest with SCHED=%s QUANTUM=%s\n' "$SCHED" "$QUANTUM"
python3 tools/xv6run.py --quiet --timeout 300 schedtest >"$RAW" 2>&1 \
    || { tail -n 25 "$RAW"; die "xv6 did not run schedtest to completion."; }

grep '^SCHEDTEST' "$RAW" | cut -f2- >"$OUT"
[ "$(wc -l <"$OUT")" -ge 2 ] || die "schedtest printed no results."

cat "$OUT"
printf '==> Saved %s\n' "$OUT"
