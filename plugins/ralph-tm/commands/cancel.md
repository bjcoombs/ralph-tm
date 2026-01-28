---
description: "Cancel active Ralph-TM loop"
---

# Cancel Ralph-TM Loop

To cancel an active Ralph-TM loop, remove the state file:

```bash
# Find active loop state files
ls -la .claude/ralph-loop-*.local.md 2>/dev/null

# Remove them to cancel
rm .claude/ralph-loop-*.local.md 2>/dev/null && echo "Ralph-TM loop cancelled" || echo "No active loop found"
```

After cancelling, the next time you try to exit the session, it will complete normally instead of looping.
