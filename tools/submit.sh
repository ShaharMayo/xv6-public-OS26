#!/bin/sh
set -e
ID="$1"
PATCH="${ID}_assignment${ASSIGNMENT}.patch"

git add -A
git diff --cached --binary "$BASE_TAG" > "$PATCH"
echo "Created $PATCH"