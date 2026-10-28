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
git reset -q

if [ ! -s "$PATCH" ]; then
    rm -f "$PATCH"
    die "No changes relative to '$BASE_TAG': nothing to submit. Did you save your files?"
fi

if ! git diff --quiet "$BASE_TAG" -- tools Makefile .gitignore .gitattributes; then
    echo "*** WARNING: course files were modified (tools/, Makefile, .gitignore, .gitattributes)."
    echo "*** Only the UPROGS line in the Makefile may be changed."
fi

echo "Created $PATCH"
git apply --stat "$PATCH"

if grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL: put a copy on the Windows Desktop (handles OneDrive-redirected Desktops).
    PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
    WIN=$("$PS" -NoProfile -Command "[Environment]::GetFolderPath('Desktop')" 2>/dev/null | tr -d '\r')
    DESKTOP=$(wslpath -u "$WIN" 2>/dev/null)
    if [ -d "$DESKTOP" ] && cp "$PATCH" "$DESKTOP/"; then
        echo "A copy was placed on your Windows Desktop: $WIN\\$PATCH"
    else
        echo "To open this folder in Windows Explorer run:  explorer.exe ."
    fi
else
    IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo "To copy the patch to your computer, run there (not in the VM):"
    echo "    scp $(id -un)@${IP:-<vm-ip>}:$(pwd)/$PATCH ~/Desktop/"
    echo "(VirtualBox with port forwarding: scp -P 2222 $(id -un)@localhost:$(pwd)/$PATCH ~/Desktop/)"
fi
echo "Upload $PATCH together with your PDF to Moodle."
