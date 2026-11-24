#!/bin/sh
set -e
ID="$1"
die() { printf '\n*** %s\n' "$*" >&2; exit 1; }

case "$ID" in
    "")       die "Missing student ID. Usage:  make submit ID=<your id number>" ;;
    *[!0-9]*) die "Student ID must contain digits only (got '$ID')" ;;
esac
git rev-parse -q --verify "refs/tags/$BASE_TAG" >/dev/null \
    || die "Tag '$BASE_TAG' not found. Did you clone the course repository?"

PATCH="${ID}_assignment${ASSIGNMENT}.patch"
git add -A
git diff --cached --binary "$BASE_TAG" > "$PATCH"
CHANGED=$(git diff --cached --name-only "$BASE_TAG")
git reset -q

if [ ! -s "$PATCH" ]; then
    rm -f "$PATCH"
    die "No changes relative to '$BASE_TAG': nothing to submit. Did you save your files?"
fi

if [ -n "$SUBMIT_ALLOWED" ]; then
    for f in $CHANGED; do
        case " $SUBMIT_ALLOWED " in
            *" $f "*) ;;
            *) echo "*** WARNING: $f was modified. In this assignment only these files should change: $SUBMIT_ALLOWED" ;;
        esac
    done
elif ! git diff --quiet "$BASE_TAG" -- tools Makefile .gitignore .gitattributes; then
    echo "*** WARNING: course files were modified (tools/, Makefile, .gitignore, .gitattributes)."
    echo "*** Only the UPROGS line in the Makefile may be changed."
fi

echo "Created $PATCH"
git apply --stat "$PATCH"

TSVS=""
if [ -n "$SUBMIT_EXPERIMENTS" ]; then
    printf '\nRunning the experiments on your code. This takes several minutes.\n'
    for n in $SUBMIT_EXPERIMENTS; do
        sh tools/experiment.sh "$n" || die "Experiment $n failed."
        TSVS="$TSVS exp$n.tsv"
    done
    printf '\nResults for your analysis:%s\n' "$TSVS"
fi

if grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL: put copies on the Windows Desktop (handles OneDrive-redirected Desktops).
    PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
    WIN=$("$PS" -NoProfile -Command "[Environment]::GetFolderPath('Desktop')" 2>/dev/null | tr -d '\r')
    DESKTOP=$(wslpath -u "$WIN" 2>/dev/null)
    if [ -d "$DESKTOP" ] && cp "$PATCH" $TSVS "$DESKTOP/"; then
        echo "Copies were placed on your Windows Desktop: $WIN"
    else
        echo "To open this folder in Windows Explorer run:  explorer.exe ."
    fi
else
    IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo "To copy the files to your computer, run there (not in the VM):"
    echo "    scp $(id -un)@${IP:-<vm-ip>}:$(pwd)/$PATCH ~/Desktop/"
    [ -n "$TSVS" ] && echo "    scp \"$(id -un)@${IP:-<vm-ip>}:$(pwd)/exp*.tsv\" ~/Desktop/"
    echo "(VirtualBox with port forwarding: add  -P 2222  and use  localhost  as the address)"
fi
echo "Upload $PATCH together with your PDF to Moodle."
[ -n "$TSVS" ] && echo "The exp*.tsv files are for your analysis. Do not upload them."
