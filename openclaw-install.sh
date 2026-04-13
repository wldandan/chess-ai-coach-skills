#!/bin/bash
set -e

# OpenClaw Workspace Installation Script
# Installs agents, skills, and commands to ~/.openclaw/workspace-chess-ai-coach
#
# Skills are installed globally to ~/.agents/skills/ (unified, all agents use them).
# Workspace gets symlinks pointing to global skills.
#
# Expected source structure:
#   <repo>/
#   ├── skills/
#   │   ├── chess-analysis/
#   │   └── chess-game-history/
#   ├── agents/           ← workspace definition files (AGENTS.md, SOUL.md, etc.)
#   ├── commands/          ← (optional)
#   └── openclaw-install.sh
#
# Expected target structure after install:
#   ~/.agents/skills/                   ← global, all agents share
#   │   ├── chess-analysis/
#   │   └── chess-game-history/
#   ~/.openclaw/workspace-chess-ai-coach/
#   │   ├── skills/                      ← symlinks to ~/.agents/skills/
#   │   │   ├── chess-analysis  -> ~/.agents/skills/chess-analysis/
#   │   │   └── chess-game-history -> ~/.agents/skills/chess-game-history/
#   │   ├── AGENTS.md / SOUL.md / etc.   ← workspace definition files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_WORKSPACE="$HOME/.openclaw/workspace-chess-ai-coach"
GLOBAL_SKILLS="$HOME/.agents/skills"
SKILLS_SRC="$SCRIPT_DIR/skills"

echo "=== OpenClaw Chess AI Coach Installer ==="
echo "Global skills: $GLOBAL_SKILLS"
echo "Workspace:    $TARGET_WORKSPACE"
echo ""

# ── 1. Install skills GLOBALLY (source of truth for all agents) ─────────────
echo "[1/3] Installing skills globally -> $GLOBAL_SKILLS ..."

mkdir -p "$GLOBAL_SKILLS"

if [ -d "$SKILLS_SRC" ]; then
    for skill_dir in "$SKILLS_SRC"/*; do
        if [ -d "$skill_dir" ]; then
            skill_name="$(basename "$skill_dir")"
            dest="$GLOBAL_SKILLS/$skill_name"

            if [ -L "$dest" ]; then
                existing=$(readlink "$dest")
                if [ "$existing" = "$skill_dir" ]; then
                    echo "  [ok]   $skill_name: already symlinked correctly"
                else
                    echo "  [warn] $skill_name: symlink exists but points elsewhere, updating"
                    rm "$dest"
                    ln -s "$skill_dir" "$dest"
                fi
            elif [ -e "$dest" ]; then
                echo "  [skip] $skill_name: $dest exists (not a symlink, not overwriting)"
            else
                echo "  [link] $skill_name -> $skill_dir"
                ln -s "$skill_dir" "$dest"
            fi
        fi
    done
else
    echo "  Warning: skills directory not found, skipping"
fi

# ── 2. Create workspace/skills/ with symlinks to global skills ──────────────
echo ""
echo "[2/3] Symlinking workspace/skills/ -> global skills ..."

mkdir -p "$TARGET_WORKSPACE/skills"

for skill_name in chess-analysis chess-game-history; do
    global_path="$GLOBAL_SKILLS/$skill_name"
    ws_link="$TARGET_WORKSPACE/skills/$skill_name"

    if [ ! -e "$global_path" ]; then
        echo "  [skip] $skill_name: not installed globally, cannot symlink"
        continue
    fi

    if [ -L "$ws_link" ]; then
        existing=$(readlink "$ws_link")
        if [ "$existing" = "$global_path" ]; then
            echo "  [ok]   $skill_name: already symlinked correctly"
        else
            echo "  [warn] $skill_name: symlink exists but points elsewhere ($existing), updating"
            rm "$ws_link"
            ln -s "$global_path" "$ws_link"
        fi
    elif [ -e "$ws_link" ]; then
        echo "  [skip] $skill_name: $ws_link exists and is not a symlink"
    else
        echo "  [link] $skill_name -> $global_path"
        ln -s "$global_path" "$ws_link"
    fi
done

# ── 3. Install workspace definition files (AGENTS.md, SOUL.md, etc.) ───────
echo ""
echo "[3/3] Installing workspace files -> $TARGET_WORKSPACE ..."

AGENTS_SRC="$SCRIPT_DIR/agents"
if [ -d "$AGENTS_SRC" ]; then
    for file in "$AGENTS_SRC"/*; do
        if [ -f "$file" ]; then
            fname="$(basename "$file")"
            dest="$TARGET_WORKSPACE/$fname"

            # Skip if workspace already has this file and it's different
            if [ -f "$dest" ]; then
                if cmp -s "$file" "$dest"; then
                    echo "  [skip] $fname: already identical in workspace"
                    continue
                else
                    echo "  [warn] $fname: exists in workspace with different content, skipping"
                    continue
                fi
            fi
            echo "  [copy] $fname -> $dest"
            cp "$file" "$dest"
        fi
    done
else
    echo "  Warning: agents directory not found, skipping"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Global skills (~/.agents/skills/):"
ls -la "$GLOBAL_SKILLS/" 2>/dev/null | grep "^d\|chess" | awk '{print "  " $0}' || echo "  (empty)"
echo ""
echo "Workspace skills (~/.openclaw/workspace-chess-ai-coach/skills/):"
ls -la "$TARGET_WORKSPACE/skills/" 2>/dev/null | awk '{print "  " $0}' || echo "  (empty)"
echo ""
echo "Workspace files:"
ls "$TARGET_WORKSPACE/" 2>/dev/null | grep -v "^skills$\|^memory$\|^commands$\|^\.openclaw\|^\.DS" | awk '{print "  " $0}' || echo "  (empty)"
