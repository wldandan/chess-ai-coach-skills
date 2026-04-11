#!/bin/bash
set -e

# OpenClaw Workspace Installation Script
# Installs agents, skills, and commands to ~/.openclaw/workspace-chess-ai-coach

TARGET_DIR="$HOME/.openclaw/workspace-chess-ai-coach"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== OpenClaw Workspace Installer ==="
echo "Target: $TARGET_DIR"
echo "Source: $SCRIPT_DIR"
echo ""

# Create target directory
mkdir -p "$TARGET_DIR"

# Function to create symlink or copy
link_or_copy() {
    local src="$1"
    local dest="$2"
    local name="$(basename "$src")"

    if [ -L "$dest/$name" ]; then
        echo "  Removing existing symlink: $name"
        rm "$dest/$name"
    elif [ -e "$dest/$name" ]; then
        echo "  Warning: $name exists and is not a symlink, skipping"
        return 1
    fi

    echo "  Creating symlink: $name -> $src"
    ln -s "$src" "$dest/$name"
}

# Function to install directory contents individually
install_dir_contents() {
    local src_dir="$1"
    local dest_dir="$2"
    local name="$3"

    if [ ! -d "$src_dir" ]; then
        echo "  Warning: $name directory not found, skipping"
        return
    fi

    echo "  Installing $name..."
    for item in "$src_dir"/*; do
        if [ -e "$item" ]; then
            local item_name="$(basename "$item")"
            local dest_path="$dest_dir/$item_name"

            if [ -L "$dest_path" ]; then
                echo "    Removing existing symlink: $item_name"
                rm "$dest_path"
            elif [ -e "$dest_path" ]; then
                echo "    Warning: $item_name exists, skipping"
                continue
            fi

            echo "    Creating symlink: $item_name -> $item"
            ln -s "$item" "$dest_path"
        fi
    done
}

# Install agents individually
echo "[1/3] Installing agents..."
install_dir_contents "$SCRIPT_DIR/agents" "$TARGET_DIR" "agents"

# Install skills individually (each skill subdirectory)
echo "[2/3] Installing skills..."
install_dir_contents "$SCRIPT_DIR/skills" "$TARGET_DIR" "skills"

# Install commands individually
echo "[3/3] Installing commands..."
install_dir_contents "$SCRIPT_DIR/commands" "$TARGET_DIR" "commands"

echo ""
echo "=== Installation Complete ==="
echo "Installed to: $TARGET_DIR"
echo ""
echo "Contents:"
ls -la "$TARGET_DIR"
