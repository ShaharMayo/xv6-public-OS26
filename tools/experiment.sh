#!/bin/sh
# Run one HW2 experiment: a fixed list of scheduler configurations on one
# workload, merged into exp<N>.tsv. Invoked by `make experiment EXP=<N>`.

die() { printf '\n*** %s\n' "$*" >&2; exit 1; }

case "$1" in
  1) CONFIGS="FCFS:1 SJF:1 PRIORITY:1" ;;
  2) CONFIGS="FCFS:1 RR:1 RR:10 RR:100 RR:200" ;;
  3) CONFIGS="SJF:1 SRTF:1 SRTF:10 SRTF:50 SRTF:150" ;;
  *) die "Usage: make experiment EXP=1   (or 2, or 3)" ;;
esac
WORKLOAD="exp$1"
export WORKLOAD

OUT="exp$1.tsv"
rm -f "$OUT"
for c in $CONFIGS; do
    s=${c%%:*}
    q=${c##*:}
    make -s measure SCHED="$s" QUANTUM="$q" \
        || die "Experiment $1 stopped at $s (quantum $q)."
    f="results_${WORKLOAD}_${s}_q${q}.tsv"
    if [ -f "$OUT" ]; then tail -n +2 "$f" >>"$OUT"; else cat "$f" >"$OUT"; fi
done
printf '\n==> Saved %s\n' "$OUT"
