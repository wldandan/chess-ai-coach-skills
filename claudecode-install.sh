#!/bin/bash
set -e

# Claude Code Skills Installation Script
# Installs skills globally to ~/.claude/skills/
#
# Expected source structure:
#   <repo>/
#   ├── skills/
#   │   ├── chess-analysis/
#   │   │   └── scripts/
#   │   │       ├── analyze.py
#   │   │       └── git-sync.sh
#   │   └── chess-game-history/
#   └── claudecode-install.sh
#
# After install:
#   ~/.claude/skills/
#   │   ├── chess-analysis/     ← symlink to repo
#   │   ├── chess-game-history/ ← symlink to repo
#   │   └── chess-player-stats/ ← symlink to repo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_SKILLS="$HOME/.claude/skills"
SKILLS_SRC="$SCRIPT_DIR/skills"

echo "=== Claude Code Chess AI Coach Installer ==="
echo "Skills: $GLOBAL_SKILLS"
echo ""

# ── Install skills GLOBALLY ───────────────────────────────────────────────────
echo "[1/1] Installing skills globally -> $GLOBAL_SKILLS ..."

mkdir -p "$GLOBAL_SKILLS"

if [ -d "$SKILLS_SRC" ]; then
    for skill_dir in "$SKILLS_SRC"/*; do
        if [ -d "$skill_dir" ] && [ "$(basename "$skill_dir")" != "__pycache__" ]; then
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

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Global skills (~/.claude/skills/):"
ls -la "$GLOBAL_SKILLS/" 2>/dev/null | grep "^d\|chess\|->" | awk '{print "  " $0}' || echo "  (empty)"
echo ""
echo "Skills are now available globally. Restart claude to use them."
