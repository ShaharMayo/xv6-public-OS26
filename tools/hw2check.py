#!/usr/bin/env python3
"""HW2 checks, run by `make verify` on a built copy of a submission.

    python3 tools/hw2check.py DIR

For each pick_* function: fail if it still calls the placeholder
pick_default(); otherwise build the kernel with the matching policy, run one
small schedtest workload, and compare every job's waiting time with the
expected value (within TOLERANCE ticks).

Exit code 0 if every function passed, 1 otherwise. Standard library only.
"""

import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TOLERANCE = 3

# Workloads are "priority length arrival" triples, one per job.
T = "5 25 0  3 30 5  1 20 15  2 10 10"
TESTS = [
    # function,       SCHED,      QUANTUM, workload,                  expected waiting
    ("pick_fcfs",     "FCFS",     1,  T,                         [0, 20, 50, 45]),
    ("pick_sjf",      "SJF",      1,  T,                         [0, 50, 20, 15]),
    ("pick_priority", "PRIORITY", 1,  T,                         [0, 50, 10, 35]),
    ("pick_rr",       "RR",       10, "1 20 0  1 20 5  1 20 0",  [20, 35, 30]),
    ("pick_srtf",     "SRTF",     1,  "1 30 0  1 20 15  1 5 20", [5, 20, 0]),
]


def placeholder_users(workdir):
    """Names of the functions in proc.c that still call pick_default()."""
    users, current = set(), None
    with open(os.path.join(workdir, "proc.c"), errors="replace") as f:
        for line in f:
            m = re.match(r"(\w+)\s*\(", line)      # a definition starts at column 0
            if m:
                current = m.group(1)
            code = line.split("//")[0]
            if current and re.search(r"\bpick_default\s*\(\s*\)", code):
                users.add(current)
    return users


def run_schedtest(workdir, sched, quantum, workload):
    """Boot xv6 built with the given policy and run schedtest; return rows."""
    env = dict(os.environ, SCHED=sched, QUANTUM=str(quantum))
    for name in ("MAKEFLAGS", "MFLAGS", "MAKEOVERRIDES", "MAKELEVEL"):
        env.pop(name, None)
    cmd = [sys.executable, os.path.join(HERE, "xv6run.py"), "--cwd", workdir,
           "--quiet", "--timeout", "180", "schedtest " + " ".join(workload.split())]
    p = subprocess.run(cmd, env=env, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, universal_newlines=True)
    rows = [l.split("\t")[1:] for l in p.stdout.splitlines()
            if l.startswith("SCHEDTEST\t")]
    if p.returncode == 2:
        return None, "xv6 hung, or schedtest never finished"
    if p.returncode != 0:
        return None, "the kernel did not build or boot with SCHED=%s" % sched
    if len(rows) < 2:
        return None, "schedtest printed no results"
    return [dict(zip(rows[0], r)) for r in rows[1:]], None


def order(arrivals, lengths, waits):
    """Job numbers in the order the jobs finished."""
    finish = [a + l + w for a, l, w in zip(arrivals, lengths, waits)]
    return ",".join(str(i) for i in sorted(range(len(finish)), key=lambda i: finish[i]))


def main():
    if len(sys.argv) != 2:
        print("usage: hw2check.py DIR", file=sys.stderr)
        return 1
    workdir = sys.argv[1]
    leftover = placeholder_users(workdir)
    passed = 0
    for func, sched, quantum, workload, expected in TESTS:
        print("%-15s" % func, end=" ", flush=True)
        if func in leftover:
            print("FAIL  still calls the placeholder pick_default()")
            continue
        rows, err = run_schedtest(workdir, sched, quantum, workload)
        if err:
            print("FAIL  " + err)
            continue
        nums = [int(x) for x in workload.split()]
        lengths, arrivals = nums[1::3], nums[2::3]
        try:
            waits = [int(r["waiting"]) for r in rows]
        except (KeyError, ValueError):
            print("FAIL  could not read the schedtest output")
            continue
        if len(waits) == len(expected) and \
           all(abs(w - e) <= TOLERANCE for w, e in zip(waits, expected)):
            print("PASS")
            passed += 1
        else:
            print("FAIL  jobs finished in order %s (expected %s); waiting times %s (expected %s)"
                  % (order(arrivals, lengths, waits), order(arrivals, lengths, expected),
                     ",".join(map(str, waits)), ",".join(map(str, expected))))
    print("\n%d of %d functions passed." % (passed, len(TESTS)))
    return 0 if passed == len(TESTS) else 1


if __name__ == "__main__":
    sys.exit(main())