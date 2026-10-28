#!/usr/bin/env python3
"""Boot xv6 headlessly under QEMU, run shell commands, capture their output.

Used by `make verify` and by the course grading harness. Standard library
only, so it runs on a stock Ubuntu python3.

    python3 tools/xv6run.py [options] CMD [CMD ...]

Options:
    --cwd DIR           repository to run in (default: current directory)
    --timeout SECONDS   per-step timeout: boot, and each command (default 60)
    --expect TEXT       exit 0 only if TEXT appears in the commands' output
    --quiet             print only the commands' output, not the boot log

Exit codes: 0 ok, 2 timeout, 3 expected text missing, 4 QEMU exited early,
5 usage/setup error.
"""

import argparse
import os
import subprocess
import sys
import threading
import time

PROMPT = b"\n$ "          # xv6 shell prompt at the start of a line
BOOT_MARK = b"init: starting sh"


class Xv6:
    def __init__(self, cwd, timeout):
        self.timeout = timeout
        self.buf = bytearray()
        self.lock = threading.Condition()
        self.closed = False
        env = dict(os.environ, CPUS="1")
        self.proc = subprocess.Popen(
            ["make", "-s", "qemu-nox"], cwd=cwd, env=env,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, bufsize=0)
        threading.Thread(target=self._reader, daemon=True).start()

    def _reader(self):
        while True:
            chunk = self.proc.stdout.read(4096)
            with self.lock:
                if not chunk:
                    self.closed = True
                    self.lock.notify_all()
                    return
                self.buf.extend(chunk)
                self.lock.notify_all()

    def wait_for(self, marker):
        """Block until marker appears; return bytes up to and excluding it."""
        deadline = time.monotonic() + self.timeout
        with self.lock:
            while True:
                i = self.buf.find(marker)
                if i >= 0:
                    out = bytes(self.buf[:i])
                    del self.buf[:i + len(marker)]
                    return out
                if self.closed:
                    raise EOFError(bytes(self.buf).decode(errors="replace"))
                left = deadline - time.monotonic()
                if left <= 0:
                    raise TimeoutError(bytes(self.buf).decode(errors="replace"))
                self.lock.wait(left)

    def send(self, line):
        self.proc.stdin.write(line.encode() + b"\n")
        self.proc.stdin.flush()

    def close(self):
        try:
            self.proc.stdin.write(b"\x01x")   # Ctrl-a x: quit QEMU
            self.proc.stdin.flush()
            self.proc.wait(timeout=5)
        except Exception:
            self.proc.kill()
            self.proc.wait()


def clean(b):
    return b.decode(errors="replace").replace("\r", "")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--cwd", default=".")
    ap.add_argument("--timeout", type=float, default=60)
    ap.add_argument("--expect")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("commands", nargs="+", metavar="CMD")
    args = ap.parse_args()

    if not os.path.isfile(os.path.join(args.cwd, "Makefile")):
        print("xv6run: no Makefile in", args.cwd, file=sys.stderr)
        return 5

    vm = Xv6(args.cwd, args.timeout)
    outputs = []
    try:
        boot = vm.wait_for(BOOT_MARK)
        vm.wait_for(PROMPT)
        if not args.quiet:
            print(clean(boot) + clean(BOOT_MARK))
        for cmd in args.commands:
            vm.send(cmd)
            raw = vm.wait_for(PROMPT)
            text = clean(raw)
            # Drop the echo of the command itself (first line).
            body = text.split("\n", 1)[1] if "\n" in text else ""
            outputs.append(body)
            print("$ " + cmd)
            print(body, end="" if body.endswith("\n") else "\n")
    except TimeoutError as e:
        print("\n*** TIMEOUT waiting for xv6 (last output below)\n" + str(e),
              file=sys.stderr)
        return 2
    except EOFError as e:
        print("\n*** QEMU exited before xv6 was ready:\n" + str(e), file=sys.stderr)
        return 4
    finally:
        vm.close()

    if args.expect is not None:
        if any(args.expect in o for o in outputs):
            print("*** OK: found %r" % args.expect)
            return 0
        print("*** FAIL: expected output %r not found" % args.expect, file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())