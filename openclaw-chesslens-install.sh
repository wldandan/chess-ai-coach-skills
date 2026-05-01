#!/bin/bash
set -e

# chessLens Skills Installer for OpenClaw main agent
# Installs skills (chess + NBA) to OpenClaw main workspace via symlinks
#
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/wldandan/chess-ai-coach-skills/main/openclaw-chesslens-install.sh | bash
#
# Options:
#   CHESS_LENS_DIR=/path/to/chess-ai-coach-skills curl -fsSL ... | bash

REPO_URL="https://github.com/wldandan/chess-ai-coach-skills"
BRANCH="main"

# ── Resolve source directory ─────────────────────────────────────────────────
REPO_INSTALL_DIR="${CHESS_LENS_DIR:-$HOME/chessLens/chess-ai-coach-skills}"

if [ -n "$_CHESS_LENS_DIR" ] && [ -d "$_CHESS_LENS_DIR" ]; then
    SCRIPT_DIR="$_CHESS_LENS_DIR"
else
    _bs="${BASH_SOURCE[0]}"
    _resolved_dir=""
    if [ -n "$_bs" ]; then
        _resolved_dir="$(cd "$(dirname "$_bs")" && pwd 2>/dev/null)"
    fi
    if [ -z "$_resolved_dir" ] || [ ! -d "$_resolved_dir/.git" ]; then
        echo "=== Self-download mode: cloning from $REPO_URL ==="
        if [ -d "$REPO_INSTALL_DIR/.git" ]; then
            echo "Repo already exists at $REPO_INSTALL_DIR, pulling latest..."
            cd "$REPO_INSTALL_DIR" && git pull
        else
            echo "Cloning repo to $REPO_INSTALL_DIR ..."
            mkdir -p "$(dirname "$REPO_INSTALL_DIR")"
            git clone --depth 1 "$REPO_URL" "$REPO_INSTALL_DIR"
        fi
        echo "Running install from $REPO_INSTALL_DIR ..."
        _CHESS_LENS_DIR="$REPO_INSTALL_DIR" bash "$REPO_INSTALL_DIR/openclaw-chesslens-install.sh"
        exit $?
    fi
    SCRIPT_DIR="$_resolved_dir"
fi

SKILLS_SRC="$SCRIPT_DIR/skills"
OPENCLAW_WORKSPACE="$HOME/.openclaw/workspace"
TARGET_SKILLS="$OPENCLAW_WORKSPACE/skills"

echo "=== chessLens Skills Installer for OpenClaw ==="
echo "Source:     $SKILLS_SRC"
echo "Workspace: $TARGET_SKILLS"
echo ""

# ── 1. Create workspace/skills directory if not exists ───────────────────────
mkdir -p "$TARGET_SKILLS"

# ── 2. Symlink skills into main workspace ────────────────────────────────────
SKILLS_TO_LINK=(
    "chess-analysis"
    "chess-game-history"
    "chess-player-stats"
    "nba-daily-brief"
)

for skill_name in "${SKILLS_TO_LINK[@]}"; do
    src="$SKILLS_SRC/$skill_name"
    dest="$TARGET_SKILLS/$skill_name"

    if [ ! -d "$src" ]; then
        echo "  [skip] $skill_name: source not found at $src"
        continue
    fi

    if [ -L "$dest" ]; then
        existing="$(readlink "$dest")"
        if [ "$existing" = "$src" ]; then
            echo "  [ok]   $skill_name: already symlinked correctly"
        else
            echo "  [warn] $skill_name: symlink exists but points elsewhere ($existing), updating"
            rm "$dest"
            ln -s "$src" "$dest"
        fi
    elif [ -e "$dest" ]; then
        echo "  [skip] $skill_name: $dest exists and is not a symlink"
    else
        echo "  [link] $skill_name -> $src"
        ln -s "$src" "$dest"
    fi
done

# ── 3. Verify ──────────────────────────────────────────────────────────────────
echo ""
echo "=== Installed Skills ==="
ls -la "$TARGET_SKILLS/" 2>/dev/null | grep "^l\|drwx" | awk '{print "  " $0}'

echo ""
echo "Done. Skills are now available to the main OpenClaw agent."
echo "Restart the OpenClaw gateway to load the new skills."
