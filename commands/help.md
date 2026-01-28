---
description: "Show Ralph-TM help and usage"
---

# Ralph-TM Help

Ralph-TM is a self-referential development loop with Task Master integration.

## Commands

| Command | Description |
|---------|-------------|
| `/ralph-tm <prompt> [options]` | Start a new loop |
| `/ralph-tm:cancel` | Cancel active loop |
| `/ralph-tm:help` | Show this help |

## Options

| Option | Description |
|--------|-------------|
| `--max-iterations N` | Stop after N iterations (default: unlimited) |
| `--completion-promise TEXT` | Stop when `<promise>TEXT</promise>` is output |
| `--tag TAG` | Task Master tag for fresh state injection |
| `--task ID` | Task Master task ID (requires --tag) |

## Examples

```bash
# Basic loop with iteration limit
/ralph-tm Fix the auth bug --max-iterations 10

# With completion promise
/ralph-tm Implement feature X --completion-promise DONE --max-iterations 20

# With Task Master integration
/ralph-tm --tag 458-service --task 1.2 Implement feature --completion-promise PR_READY --max-iterations 20
```

## How It Works

1. **Setup**: Creates a state file in `.claude/` with the prompt and settings
2. **Stop Hook**: When you try to exit, the hook detects the state file and:
   - Checks if max iterations reached → allows exit
   - Checks for completion promise → allows exit if found
   - Otherwise → feeds the SAME PROMPT back as a new message
3. **Task Master**: If `--tag` and `--task` set, each iteration gets fresh task state

## Shell Metacharacter Limitation

Claude Code's `!` block handler does not support quoted arguments.
**Avoid these characters in prompts:** `( ) # & ; | > < ! $ \` \`

Use simple text with spaces, periods, commas, and dashes.

## Monitoring

```bash
# Check iteration count
grep '^iteration:' .claude/ralph-loop-*.local.md

# List active loops
ls -la .claude/ralph-loop-*.local.md
```
