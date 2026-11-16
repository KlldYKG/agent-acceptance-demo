#!/usr/bin/env bash
# Upsert the report comment: one comment per PR, edited in place via a hidden marker.
# Uses documented GitHub REST APIs via gh; falls back to a new comment if marker search fails.
set -euo pipefail
REPORT="$1"; NUMBER="$2"; REPO="$3"
MARKER="<!-- agent-acceptance:report -->"

COMMENT_ID="$(gh api "repos/$REPO/issues/$NUMBER/comments" \
  --jq ".[] | select(.body | contains(\"$MARKER\")) | .id" | head -n 1 || true)"

if [ -n "$COMMENT_ID" ]; then
  gh api -X PATCH "repos/$REPO/issues/$NUMBER/comments/$COMMENT_ID" \
    -F body="@$REPORT" >/dev/null
  echo "[agent-acceptance] updated existing comment $COMMENT_ID"
else
  gh pr comment "$NUMBER" --repo "$REPO" --body-file "$REPORT" >/dev/null
  echo "[agent-acceptance] posted new comment"
fi
