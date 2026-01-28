#!/bin/bash

# Ralph-TM Setup Script
# Creates state file for in-session Ralph loop with Task Master integration

set -euo pipefail

# Parse arguments
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"
TM_TAG=""
TM_TASK=""

# Parse options and positional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Ralph-TM - Self-referential development loop with Task Master integration

USAGE:
  /ralph-tm [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Initial prompt to start the loop (can be multiple words)

OPTIONS:
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase that signals completion
  --tag <tag>                    Task Master tag (enables fresh task state each iteration)
  --task <id>                    Task Master task ID (requires --tag)
  -h, --help                     Show this help message

DESCRIPTION:
  Starts a Ralph Loop in your CURRENT session. The stop hook prevents
  exit and feeds your output back as input until completion or iteration limit.

  To signal completion, output: <promise>YOUR_PHRASE</promise>

TASK MASTER INTEGRATION:
  When --tag and --task are provided, each iteration receives fresh task state
  from Task Master, showing subtask progress without burning conversation context.

  Example:
    /ralph-tm --tag 458-service --task 1.2 Implement the feature --completion-promise PR_READY

IMPORTANT - $ARGUMENTS LIMITATION:
  Claude Code's ! block handler does not support quoted $ARGUMENTS.
  Callers (like /tm) must sanitize prompts to avoid shell metacharacters:
    UNSAFE: ( ) # & ; | > < ! $ ` \
  Use simple alphanumeric text, spaces, periods, commas, and dashes.

STOPPING:
  Only by reaching --max-iterations or detecting --completion-promise.
  No manual stop - Ralph runs infinitely by default!

MONITORING:
  grep '^iteration:' .claude/ralph-loop-*.local.md
  ls -la .claude/ralph-loop-*.local.md 2>/dev/null
HELP_EOF
      exit 0
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --max-iterations requires a number argument" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations must be a positive integer or 0, got: $2" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --completion-promise requires a text argument" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    --tag)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --tag requires a Task Master tag name" >&2
        exit 1
      fi
      TM_TAG="$2"
      shift 2
      ;;
    --task)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --task requires a Task Master task ID" >&2
        exit 1
      fi
      TM_TASK="$2"
      shift 2
      ;;
    *)
      # Non-option argument - collect as prompt parts
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

# Join all prompt parts with spaces
PROMPT="${PROMPT_PARTS[*]}"

# Validate prompt is non-empty
if [[ -z "$PROMPT" ]]; then
  echo "Error: No prompt provided" >&2
  echo "  Example: /ralph-tm Build a REST API --max-iterations 20" >&2
  echo "  For help: /ralph-tm --help" >&2
  exit 1
fi

# Validate Task Master options
if [[ -n "$TM_TASK" ]] && [[ -z "$TM_TAG" ]]; then
  echo "Error: --task requires --tag to be specified" >&2
  echo "  Example: /ralph-tm --tag 458-service --task 1.2 Implement feature" >&2
  exit 1
fi

# Create state file directory
mkdir -p .claude

# Derive session ID from CWD to create session-specific state file
# This prevents context bleeding between concurrent sessions
PROJECT_DIR="${HOME}/.claude/projects/$(pwd | tr '/' '-' | tr '.' '-')"
SESSION_ID=""

if [[ -d "$PROJECT_DIR" ]]; then
  # Find the most recently modified transcript (current session)
  # Exclude agent-* files which are subagent transcripts
  CURRENT_TRANSCRIPT=$(ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | grep -v '/agent-' | head -1 || true)
  if [[ -n "$CURRENT_TRANSCRIPT" ]]; then
    SESSION_ID=$(basename "$CURRENT_TRANSCRIPT" .jsonl)
  fi
fi

# Fallback to timestamp+random if session ID couldn't be determined
if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID="fallback-$(date +%s)-$$"
  echo "Warning: Could not determine session ID, using fallback: $SESSION_ID" >&2
fi

RALPH_STATE_FILE=".claude/ralph-loop-${SESSION_ID}.local.md"

# Quote completion promise for YAML if it contains special chars or is not null
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

# Build Task Master YAML fields (only if tag is set)
TM_YAML=""
if [[ -n "$TM_TAG" ]]; then
  TM_YAML="tm_tag: \"$TM_TAG\""
  if [[ -n "$TM_TASK" ]]; then
    TM_YAML="$TM_YAML
tm_task: \"$TM_TASK\""
  fi
fi

cat > "$RALPH_STATE_FILE" <<EOF
---
active: true
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
${TM_YAML:+$TM_YAML}
---

$PROMPT
EOF

# Build Task Master status line
TM_STATUS=""
if [[ -n "$TM_TAG" ]]; then
  if [[ -n "$TM_TASK" ]]; then
    TM_STATUS="Task Master: $TM_TAG / task $TM_TASK (fresh state injected each iteration)"
  else
    TM_STATUS="Task Master: $TM_TAG (tag only, no specific task)"
  fi
fi

# Output setup message
cat <<EOF
Ralph-TM loop activated!

Iteration: 1
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "${COMPLETION_PROMISE//\"/} (ONLY output when TRUE)"; else echo "none (runs forever)"; fi)
${TM_STATUS:+$TM_STATUS}

Session ID: $SESSION_ID
State file: $RALPH_STATE_FILE

WARNING: This loop cannot be stopped manually. It runs until
--max-iterations is reached or --completion-promise is output.

EOF

# Output the initial prompt
if [[ -n "$PROMPT" ]]; then
  echo "$PROMPT"
fi

# Display completion promise requirements if set
if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  cat <<EOF

---
COMPLETION PROMISE: To complete this loop, output exactly:
  <promise>$COMPLETION_PROMISE</promise>

The statement MUST be TRUE. Do not lie to escape the loop.
---
EOF
fi
