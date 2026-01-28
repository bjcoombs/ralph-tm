#!/bin/bash

# Ralph-TM Stop Hook
# Prevents session exit when a ralph-loop is active
# Feeds Claude's output back as input to continue the loop
# Injects fresh Task Master state each iteration

set -euo pipefail

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

# Extract session ID from transcript path for session-specific state file
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')
if [[ -z "$TRANSCRIPT_PATH" ]] || [[ "$TRANSCRIPT_PATH" == "null" ]]; then
  exit 0  # No transcript - allow exit
fi

SESSION_ID=$(basename "$TRANSCRIPT_PATH" .jsonl)

# Check if ralph-loop is active for THIS session
RALPH_STATE_FILE=".claude/ralph-loop-${SESSION_ID}.local.md"

if [[ ! -f "$RALPH_STATE_FILE" ]]; then
  exit 0  # No active loop - allow exit
fi

# Parse markdown frontmatter (YAML between ---) and extract values
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')
TM_TAG=$(echo "$FRONTMATTER" | grep '^tm_tag:' | sed 's/tm_tag: *//' | sed 's/^"\(.*\)"$/\1/')
TM_TASK=$(echo "$FRONTMATTER" | grep '^tm_task:' | sed 's/tm_task: *//' | sed 's/^"\(.*\)"$/\1/')

# Validate numeric fields
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Ralph-TM: State file corrupted, stopping loop" >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Check if max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Ralph-TM: Max iterations ($MAX_ITERATIONS) reached"
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Verify transcript exists
if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "Ralph-TM: Transcript not found, stopping loop" >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Extract last assistant message
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "Ralph-TM: No assistant messages found, stopping loop" >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>/dev/null || echo "")

if [[ -z "$LAST_OUTPUT" ]]; then
  echo "Ralph-TM: Failed to parse assistant output, stopping loop" >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Check for completion promise
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "Ralph-TM: Completion promise detected - <promise>$COMPLETION_PROMISE</promise>"
    rm "$RALPH_STATE_FILE"
    exit 0
  fi
fi

# Continue loop with SAME PROMPT
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt (everything after the closing ---)
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$RALPH_STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "Ralph-TM: No prompt found in state file, stopping loop" >&2
  rm "$RALPH_STATE_FILE"
  exit 0
fi

# Update iteration in state file
TEMP_FILE="${RALPH_STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$RALPH_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$RALPH_STATE_FILE"

# Fetch fresh Task Master state if configured
TM_STATE=""
if [[ -n "$TM_TAG" ]] && [[ -n "$TM_TASK" ]]; then
  TM_JSON=$(task-master tags use "$TM_TAG" && task-master show "$TM_TASK" --json 2>/dev/null || echo "")
  if [[ -n "$TM_JSON" ]]; then
    TM_SUMMARY=$(echo "$TM_JSON" | jq -r '
      "Task: " + .title[0:60] + " [" + .status + "]" +
      if .subtasks and (.subtasks | length) > 0 then
        "\nSubtasks: " + ([.subtasks[] | .id + ":" + .status[0:4]] | join(" "))
      else "" end
    ' 2>/dev/null || echo "")
    if [[ -n "$TM_SUMMARY" ]]; then
      TM_STATE="
--- Task Master ---
$TM_SUMMARY
-------------------"
    fi
  fi
fi

# Build system message
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="Ralph-TM iteration $NEXT_ITERATION | Complete: <promise>$COMPLETION_PROMISE</promise> (only when TRUE)${TM_STATE}"
else
  SYSTEM_MSG="Ralph-TM iteration $NEXT_ITERATION | No completion promise - loop runs forever${TM_STATE}"
fi

# Output JSON to block stop and feed prompt back
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
