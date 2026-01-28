# Ralph-TM

Self-referential AI development loops with Task Master integration for Claude Code.

## Installation

```bash
# Install from GitHub
/plugin install bjcoombs/ralph-tm
```

## Quick Start

```bash
# Basic loop
/ralph-tm Fix the auth bug --max-iterations 10

# With Task Master
/ralph-tm --tag my-tag --task 1.2 Implement feature --completion-promise PR_READY --max-iterations 20
```

## Features

- **Self-referential loops**: Claude sees the same prompt each iteration, building on previous work visible in files/git
- **Task Master integration**: Fresh task state injected each iteration via `--tag` and `--task`
- **Session isolation**: Multiple concurrent sessions don't interfere with each other
- **Context protection**: PreCompact hook clears state before context compaction

## Commands

| Command | Description |
|---------|-------------|
| `/ralph-tm` | Start a loop |
| `/ralph-tm:cancel` | Cancel active loop |
| `/ralph-tm:help` | Show help |

## Options

| Option | Description |
|--------|-------------|
| `--max-iterations N` | Iteration limit |
| `--completion-promise TEXT` | Stop when `<promise>TEXT</promise>` output |
| `--tag TAG` | Task Master tag |
| `--task ID` | Task Master task ID |

## Shell Metacharacter Limitation

Claude Code's `!` block handler does not support quoted `$ARGUMENTS`. Callers (like `/tm`) must avoid shell metacharacters in prompts:

**Unsafe:** `( ) # & ; | > < ! $ \` \`

**Safe:** Letters, numbers, spaces, periods, commas, dashes, underscores

## License

MIT
