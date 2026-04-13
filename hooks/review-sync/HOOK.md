---
name: review-sync
description: "Syncs chess review results to git after analysis is sent"
metadata:
  openclaw:
    emoji: "🔄"
    events: ["message:sent"]
    requires:
      bins: ["git", "bash"]
---

# Review Sync Hook

Automatically syncs chess review results to `git@github.com:wldandan/chess-reviews-summary.git` after analysis is sent.

## What it does

1. Listens for outbound messages containing chess analysis
2. Extracts review content from the message
3. Saves to workspace memory if not already saved
4. Commits and pushes to the reviews repo

## Configuration

None required. Uses default paths:
- Workspace memory: `~/.openclaw/workspace-chess-ai-coach/memory/`
- Reviews repo: `git@github.com:wldandan/chess-reviews-summary.git`
