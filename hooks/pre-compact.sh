#!/bin/bash
# Ralph-TM PreCompact Hook
# Clears Ralph state to allow context compaction to proceed

set -euo pipefail

HOOK_INPUT=$(cat)

# Extract session ID from transcript path
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')
SESSION_ID=""

if [[ -n "$TRANSCRIPT_PATH" ]] && [[ "$TRANSCRIPT_PATH" != "null" ]]; then
  SESSION_ID=$(basename "$TRANSCRIPT_PATH" .jsonl)
fi

# Clear session-specific state file
if [[ -n "$SESSION_ID" ]]; then
  STATE_FILE=".claude/ralph-loop-${SESSION_ID}.local.md"
  if [[ -f "$STATE_FILE" ]]; then
    ITERATION=$(grep '^iteration:' "$STATE_FILE" | sed 's/iteration: *//' || echo "?")
    echo "Ralph-TM: Context compaction triggered at iteration $ITERATION"
    echo "   Clearing state to allow compaction. Restart with /ralph-tm after."
    rm "$STATE_FILE"
  fi
fi

# Always exit 0 to allow compaction
exit 0
