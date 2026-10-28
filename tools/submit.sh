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