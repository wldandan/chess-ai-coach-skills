#!/bin/bash
# commit-if-changed.sh — 检测 analyses 目录变更，立即 commit + push

set -e

REVIEWS_DIR="$HOME/.openclaw/workspace-chess-ai-coach/analyses"
GIT_DIR="$HOME/Projects/tutorials/chess-reviews-summary"
AUTHOR_NAME="aaronwang2026 Analyst"
AUTHOR_EMAIL="5109343@qq.com"

cd "$GIT_DIR"
git config user.name "$AUTHOR_NAME" 2>/dev/null || true
git config user.email "$AUTHOR_EMAIL" 2>/dev/null || true

# 同步最新文件
cp -f "$REVIEWS_DIR"/*.md "$GIT_DIR/" 2>/dev/null || true

# 检查是否有变更
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
    echo "No changes detected"
    exit 0
fi

# Commit + Push（立即同步）
git add -A
git commit -m "Auto-commit: chess reviews $(date '+%Y-%m-%d %H:%M')"
git push origin main

echo "Done: committed and pushed"
