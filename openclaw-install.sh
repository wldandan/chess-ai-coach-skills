#!/bin/bash
set -e

# OpenClaw Workspace Installation Script
# Installs agents, skills, and commands to ~/.openclaw/workspace-chess-ai-coach
#
# One-line install (clones repo to ~/Projects/chess-ai-coach-skills):
#   curl -fsSL https://raw.githubusercontent.com/wldandan/chess-ai-coach-skills/main/openclaw-install.sh | bash
#
# To specify a different install location:
#   OPENCLAW_REPO_DIR=/path/to/repo curl -fsSL ... | bash
#
# Skills are installed globally to ~/.agents/skills/ (unified, all agents use them).
# Workspace gets symlinks pointing to global skills.
#
# Expected source structure:
#   <repo>/
#   ├── skills/
#   │   ├── chess-analysis/
#   │   │   └── scripts/
#   │   │       ├── analyze.py
#   │   │       └── git-sync.sh
#   │   └── chess-game-history/
#   ├── agents/           ← workspace definition files (AGENTS.md, SOUL.md, etc.)
#   ├── commands/          ← (optional)
#   └── openclaw-install.sh
#
# Expected target structure after install:
#   ~/.agents/skills/                   ← global, all agents share
#   │   ├── chess-analysis/            ← symlink to repo
#   │   └── chess-game-history/       ← symlink to repo
#   ~/.openclaw/workspace-chess-ai-coach/
#   │   ├── skills/                    ← symlinks to ~/.agents/skills/
#   │   ├── analyses/                  ← chess review files (auto-committed to GitHub)
#   │   ├── AGENTS.md / SOUL.md / etc.← workspace definition files

REPO_URL="https://github.com/wldandan/chess-ai-coach-skills"
BRANCH="main"

# ── Resolve SCRIPT_DIR: use explicit repo dir, or detect from BASH_SOURCE ─────
REPO_INSTALL_DIR="${OPENCLAW_REPO_DIR:-$HOME/Projects/chess-ai-coach-skills}"

if [ -n "$_OPENCLAW_REPO_DIR" ] && [ -d "$_OPENCLAW_REPO_DIR" ]; then
    SCRIPT_DIR="$_OPENCLAW_REPO_DIR"
else
    base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)"
    if [ -z "$base_dir" ] || [ ! -d "$base_dir/skills" ]; then
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
        _OPENCLAW_REPO_DIR="$REPO_INSTALL_DIR" bash "$REPO_INSTALL_DIR/openclaw-install.sh"
        exit $?
    fi
    SCRIPT_DIR="$base_dir"
fi

TARGET_WORKSPACE="$HOME/.openclaw/workspace-chess-ai-coach"
GLOBAL_SKILLS="$HOME/.agents/skills"
SKILLS_SRC="$SCRIPT_DIR/skills"

echo "=== OpenClaw Chess AI Coach Installer ==="
echo "Global skills: $GLOBAL_SKILLS"
echo "Workspace:    $TARGET_WORKSPACE"
echo ""

# ── 0. Install Stockfish if not present ─────────────────────────────────────
echo "[0/7] Checking Stockfish..."

check_stockfish() {
    command -v stockfish >/dev/null 2>&1 || \
    [ -f "/opt/homebrew/bin/stockfish" ] || \
    [ -f "/opt/homebrew/bin/stockfish-mac" ] || \
    [ -f "/usr/games/stockfish" ] || \
    [ -f "/usr/local/bin/stockfish" ]
}

if check_stockfish; then
    echo "  [ok] Stockfish found"
else
    echo "  [install] Stockfish not found, installing..."
    if command -v brew >/dev/null 2>&1; then
        brew install stockfish
    elif command -v apt >/dev/null 2>&1; then
        sudo apt install stockfish -y
    else
        echo "  [warn] No brew or apt found. Please install Stockfish manually:"
        echo "         macOS: brew install stockfish"
        echo "         Linux: sudo apt install stockfish"
    fi
fi

# ── 1. Install skills GLOBALLY (source of truth for all agents) ─────────────
echo ""
echo "[1/7] Installing skills globally -> $GLOBAL_SKILLS ..."

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
echo "[2/7] Symlinking workspace/skills/ -> global skills ..."

mkdir -p "$TARGET_WORKSPACE/skills"

for skill_name in chess-analysis chess-game-history chess-player-stats; do
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
echo "[3/7] Installing workspace files -> $TARGET_WORKSPACE ..."

AGENTS_SRC="$SCRIPT_DIR/agents"
if [ -d "$AGENTS_SRC" ]; then
    for file in "$AGENTS_SRC"/*; do
        if [ -f "$file" ]; then
            fname="$(basename "$file")"
            dest="$TARGET_WORKSPACE/$fname"

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

# ── 4. Create analyses directory ──────────────────────────────────────────
echo ""
echo "[4/7] Creating analyses directory..."

mkdir -p "$TARGET_WORKSPACE/analyses"
echo "  [ok] $TARGET_WORKSPACE/analyses/"

# ── 5. Git repo setup (chess-reviews-summary) ──────────────────────────
echo ""
echo "[5/7] Setting up Git repo for chess-reviews-summary..."

GIT_DIR="$HOME/Projects/tutorials/chess-reviews-summary"
if [ -d "$GIT_DIR/.git" ]; then
    echo "  [ok] Git repo already exists: $GIT_DIR"
else
    echo "  [init] Initializing new git repo: $GIT_DIR"
    mkdir -p "$GIT_DIR"
    cd "$GIT_DIR"
    git init
    git remote add origin git@github.com:wldandan/chess-reviews-summary.git
    echo "  [ok] Git repo initialized with remote"
    cd "$SCRIPT_DIR"
fi

# ── 6. Install OpenClaw Cron Job (backup auto-commit) ──────────────────
echo ""
echo "[6/7] Setting up OpenClaw cron job (backup auto-commit)..."

CRON_JOB_NAME="chess-reviews-auto-commit-backup"
if openclaw cron list --json 2>/dev/null | grep -q "$CRON_JOB_NAME"; then
    echo "  [skip] cron job '$CRON_JOB_NAME' already exists"
else
    echo "  [create] $CRON_JOB_NAME (every 30m, isolated session, no-deliver)"
    openclaw cron add \
        --name "$CRON_JOB_NAME" \
        --every "30m" \
        --session isolated \
        --no-deliver \
        --description "Backup: auto-commit chess reviews to GitHub every 30 mins if missed" \
        --message "Run the following shell command and reply HEARTBEAT_OK:\n\n  ~/.agents/skills/chess-analysis/scripts/commit-if-changed.sh"
    echo "  [ok] cron job created"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Global skills (~/.agents/skills/):"
ls -la "$GLOBAL_SKILLS/" 2>/dev/null | grep "^d\|chess" | awk '{print "  " $0}' || echo "  (empty)"
echo ""
echo "Workspace (~/.openclaw/workspace-chess-ai-coach/):"
echo "  skills/:"
ls -la "$TARGET_WORKSPACE/skills/" 2>/dev/null | awk '{print "    " $0}' || echo "    (empty)"
echo "  analyses/:"
ls "$TARGET_WORKSPACE/analyses/" 2>/dev/null | awk '{print "    " $0}' || echo "    (empty)"
echo ""
echo "Git repo: $GIT_DIR"
echo "Cron job: $CRON_JOB_NAME (every 30m, isolated)"
echo ""
echo "Run 'openclaw cron list' to verify cron job is active."
