#!/bin/bash

TARGET_REPO="${1:-namidaco/namida-snapshots}"

release_info=$(curl -s -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/${TARGET_REPO}/releases/latest)

PREVIOUS_RELEASE_DATE=$(echo "$release_info" | grep '"published_at":' | sed -E 's/.*"published_at": ?"([^"]+)".*/\1/')

REPO_URL="https://github.com/namidaco/namida/commit/"
COMMITS=$(git log --pretty=format:"%H %s" --decorate --no-abbrev-commit --after="$PREVIOUS_RELEASE_DATE")
CHANGELOG=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  HASH=$(echo "$line" | awk '{print $1}')
  MESSAGE=$(echo "$line" | cut -d' ' -f2-)
  MESSAGE=$(echo "$MESSAGE" | sed 's/ - /\n   - /g')
  CHANGELOG="${CHANGELOG}- ${REPO_URL}${HASH} ${MESSAGE}"$'\n'
done <<< "$COMMITS"

CHANGELOG=$(echo "$CHANGELOG" | sed '$d')

printf '%s\n' "$CHANGELOG" > beta_changelog.md