#!/bin/bash
set -e

# OpenClaw Workspace Installation Script
# Installs agents, skills, and commands to ~/.openclaw/workspace-chess-ai-coach
#
# Expected OpenClaw workspace structure:
#   <workspace>/
#   ├── AGENTS.md                  ← workspace rules & workflow
#   ├── IDENTITY.md                ← agent identity
#   ├── SOUL.md                   ← core values
#   ├── USER.md                   ← user info
#   ├── BOOTSTRAP.md              ← first-run bootstrap (delete after use)
#   ├── HEARTBEAT.md              ← proactive tasks
#   ├── TOOLS.md                  ← tool config
#   ├── skills/                    ← skills directory
#   │   ├── chess-analysis/
#   │   └── chess-game-history/
#   ├── memory/                    ← daily memory files
#   └── commands/                  ← (optional)

TARGET_DIR="$HOME/.openclaw/workspace-chess-ai-coach"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== OpenClaw Workspace Installer ==="
echo "Target: $TARGET_DIR"
echo "Source: $SCRIPT_DIR"
echo ""

# Create target directory and standard subdirectories
mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_DIR/skills"
mkdir -p "$TARGET_DIR/memory"

# Function to safely create a single symlink
symlink_to() {
    local src="$1"
    local dest="$2"
    local name="$(basename "$src")"
    local dest_path="$dest/$name"

    if [ -L "$dest_path" ]; then
        echo "  Removing existing symlink: $name"
        rm "$dest_path"
    elif [ -e "$dest_path" ]; then
        echo "  Warning: $name exists and is not a symlink, skipping"
        return 1
    fi

    echo "  Symlink: $name -> $src"
    ln -s "$src" "$dest_path"
}

# Install each skill directory into <workspace>/skills/
echo "[1/3] Installing skills -> <workspace>/skills/ ..."
if [ -d "$SCRIPT_DIR/skills" ]; then
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        if [ -d "$skill_dir" ]; then
            symlink_to "$skill_dir" "$TARGET_DIR/skills"
        fi
    done
else
    echo "  Warning: skills directory not found, skipping"
fi

# Install agent files into <workspace>/ (at root level)
echo "[2/3] Installing agents -> <workspace>/ ..."
if [ -d "$SCRIPT_DIR/agents" ]; then
    for agent_file in "$SCRIPT_DIR/agents"/*; do
        if [ -f "$agent_file" ]; then
            symlink_to "$agent_file" "$TARGET_DIR"
        fi
    done
else
    echo "  Warning: agents directory not found, skipping"
fi

# Install commands (if any) into <workspace>/commands/
echo "[3/3] Installing commands -> <workspace>/commands/ ..."
if [ -d "$SCRIPT_DIR/commands" ] && [ "$(ls -A "$SCRIPT_DIR/commands" 2>/dev/null)" ]; then
    mkdir -p "$TARGET_DIR/commands"
    for cmd_file in "$SCRIPT_DIR/commands"/*; do
        if [ -f "$cmd_file" ]; then
            symlink_to "$cmd_file" "$TARGET_DIR/commands"
        fi
    done
else
    echo "  Warning: commands directory not found or empty, skipping"
fi

echo ""
echo "=== Installation Complete ==="
ls -la "$TARGET_DIR"
