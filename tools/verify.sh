#!/bin/sh
# Apply a submission patch to a clean checkout of the baseline, build it,
# boot xv6 and run the assignment's smoke test - exactly as the grader does.
# Invoked by `make verify PATCH=<file>` (default: newest *.patch here).

die()  { printf '\n*** %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

ROOT=$(git rev-parse --show-toplevel) || die "Not inside the course repository."
cd "$ROOT"
git rev-parse -q --verify "refs/tags/$BASE_TAG" >/dev/null || die "Tag '$BASE_TAG' not found."
command -v python3 >/dev/null || die "python3 is required."

PATCH="$1"
[ -n "$PATCH" ] || PATCH=$(ls -t ./*.patch 2>/dev/null | head -n 1)
[ -n "$PATCH" ] || die "No patch given and none found. Run 'make submit ID=...' first."
[ -f "$PATCH" ] || die "Patch file not found: $PATCH"
basename "$PATCH" | grep -Eq "^[0-9]{5,10}_assignment${ASSIGNMENT}\.patch$" \
    || die "Patch must be named <id>_assignment${ASSIGNMENT}.patch (got $(basename "$PATCH"))."
PATCH_ABS=$(cd "$(dirname "$PATCH")" && pwd)/$(basename "$PATCH")

WORK=$(mktemp -d /tmp/xv6-verify.XXXXXX) || die "mktemp failed"
LOG="$WORK.log"
cleanup() { git worktree remove --force "$WORK" >/dev/null 2>&1; rm -rf "$WORK" "$LOG"; }
trap cleanup EXIT INT TERM

step "Checking out '$BASE_TAG' into $WORK"
git worktree add --detach "$WORK" "$BASE_TAG" >/dev/null 2>&1 || die "git worktree add failed"

step "Applying $(basename "$PATCH")"
git -C "$WORK" apply --check "$PATCH_ABS" || die "RESULT: FAIL - patch does not apply cleanly to '$BASE_TAG'."
git -C "$WORK" apply "$PATCH_ABS" || die "RESULT: FAIL - git apply failed."
git -C "$WORK" status --short | sed 's/^/    /'

step "Building"
if ! (make -C "$WORK" -s >"$LOG" 2>&1 && make -C "$WORK" -s fs.img >>"$LOG" 2>&1); then
    grep -vE '^ld: (warning|NOTE)' "$LOG" | tail -n 25
    die "RESULT: FAIL - build error (see above)."
fi
echo "    kernel and fs.img built"

step "Booting xv6 and running '$VERIFY_CMD' (expecting \"$VERIFY_EXPECT\")"
python3 "$ROOT/tools/xv6run.py" --quiet --cwd "$WORK" --timeout 120 \
    --expect "$VERIFY_EXPECT" "$VERIFY_CMD"
case $? in
    0) printf '\nRESULT: PASS - %s is ready to submit.\n' "$(basename "$PATCH")" ;;
    2) die "RESULT: FAIL - xv6 hung or the command never returned." ;;
    3) die "RESULT: FAIL - '$VERIFY_CMD' ran but did not print \"$VERIFY_EXPECT\"." ;;
    *) die "RESULT: FAIL - xv6 did not boot." ;;
esac