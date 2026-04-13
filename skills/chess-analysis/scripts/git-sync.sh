#!/bin/bash
# git-sync.sh — 提交并推送复盘文件到 GitHub
# 用法: ./git-sync.sh "commit message"

set -e

REVIEWS_DIR="$HOME/.openclaw/workspace-chess-ai-coach/analyses"
GIT_DIR="$HOME/Projects/tutorials/chess-reviews-summary"
AUTHOR_NAME="aaronwang2026 Analyst"
AUTHOR_EMAIL="5109343@qq.com"

cd "$GIT_DIR"

if [ ! -d ".git" ]; then
    echo "Error: $GIT_DIR is not a git repo"
    exit 1
fi

# 检查是否有新文件或变更
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "Nothing to commit"
    exit 0
fi

# 配置 git（防止全局配置干扰）
git config user.name "$AUTHOR_NAME"
git config user.email "$AUTHOR_EMAIL"

# 同步最新文件
rsync -av --include='*/' --exclude='*' "$REVIEWS_DIR/" "$GIT_DIR/" 2>/dev/null || cp "$REVIEWS_DIR"/*.md "$GIT_DIR/" 2>/dev/null || true

# 添加所有变更
git add -A

# 提交
MSG="${1:-"Update chess reviews $(date '+%Y-%m-%d %H:%M')"}"
git commit -m "$MSG"

# 推送到远程
git push origin main

echo "Done: $MSG"
