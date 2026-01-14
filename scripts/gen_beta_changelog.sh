#!/bin/sh

release_info=$(curl -s -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/namidaco/namida-snapshots/releases/latest)
# PREVIOUS_RELEASE_DATE=$(echo "$release_info" | jq -r '.published_at')    
PREVIOUS_RELEASE_DATE=$(echo "$release_info" | grep '"published_at":' | sed -E 's/.*"published_at": ?"([^"]+)".*/\1/')

REPO_URL="https://github.com/namidaco/namida/commit/"
COMMITS=$(git log --pretty=format:"%H %s" --decorate --no-abbrev-commit --after="$PREVIOUS_RELEASE_DATE")
CHANGELOG=""
while IFS= read -r line; do
  HASH=$(echo "$line" | awk '{print $1}')
  MESSAGE=$(echo "$line" | cut -d' ' -f2-) 
  MESSAGE="${MESSAGE//' - '/'\n   - '}"
  CHANGELOG="${CHANGELOG}- ${REPO_URL}${HASH} ${MESSAGE}"$'\n'
done <<< "$COMMITS"

# Remove the trailing newline
CHANGELOG=$(echo "$CHANGELOG" | sed '$d')

# Encode special characters
# CHANGELOG="${CHANGELOG//'%'/'%25'}"
# CHANGELOG="${CHANGELOG//$'\n'/'%0A'}"
# CHANGELOG="${CHANGELOG//$'\r'/'%0D'}"

echo -e "$CHANGELOG" > beta_changelog.md

