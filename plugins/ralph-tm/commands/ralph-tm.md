---
description: "Start Ralph-TM loop with Task Master integration"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT] [--tag TAG] [--task ID]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Ralph-TM Command

Execute the setup script to initialize the loop:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" $ARGUMENTS
```

Work on the task. When you try to exit, the Ralph loop feeds the SAME PROMPT back to you for the next iteration. You'll see your previous work in files and git history, allowing you to iterate and improve.

CRITICAL: If a completion promise is set, you may ONLY output `<promise>TEXT</promise>` when the statement is completely and unequivocally TRUE. Do not lie to escape the loop.

IMPORTANT - Shell Metacharacter Limitation:
Claude Code's `!` block handler does not support quoted $ARGUMENTS. Callers must avoid shell metacharacters in prompts: ( ) # & ; | > < ! $ ` \
Use simple text with spaces, periods, commas, and dashes only.
