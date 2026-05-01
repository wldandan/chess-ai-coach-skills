#!/bin/bash
set -e

# OpenClaw Chess AI Coach 安装脚本
#
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/wldandan/chess-ai-coach-skills/main/openclaw-install.sh | bash
#
# 共享目录结构：
#   $HOME/chessLens/
#   ├── chess-ai-coach-skills/   ← skills 源码（通过 git clone）
#   └── chess-reviews-summary/   ← 分析结果（git repo, push 到 GitHub Pages）
#
# 两个 agent 共享 analyses：
#   - main agent：直接处理棋类需求，写入共享目录
#   - chess-ai-coach agent：独立处理棋类需求，写入同一共享目录
#
# 安装后技能位于 ~/.agents/skills/（全局共享）

REPO_URL="https://github.com/wldandan/chess-ai-coach-skills"
REVIEWS_REPO_URL="git@github.com:wldandan/chess-reviews-summary.git"
CHESSLENS_DIR="$HOME/chessLens"
SKILLS_INSTALL_DIR="$CHESSLENS_DIR/chess-ai-coach-skills"
REVIEWS_DIR="$CHESSLENS_DIR/chess-reviews-summary"
GLOBAL_SKILLS="$HOME/.agents/skills"

# ── Resolve SCRIPT_DIR ─────────────────────────────────────────────────────────
detect_script_dir() {
    local _bs="${BASH_SOURCE[0]}"
    if [ -n "$_bs" ] && [ -f "$_bs" ]; then
        echo "$(cd "$(dirname "$_bs")" && pwd)"
    else
        echo "$(pwd)"
    fi
}

SCRIPT_DIR="${OPENCLAW_SCRIPT_DIR:-$(detect_script_dir)}"

# ── Self-download if run directly from curl ───────────────────────────────────
if [ ! -d "$SCRIPT_DIR/skills/chess-analysis" ]; then
    echo "=== Self-download mode: cloning from $REPO_URL ==="
    if [ -d "$SKILLS_INSTALL_DIR/.git" ]; then
        echo "Repo already exists, pulling latest..."
        cd "$SKILLS_INSTALL_DIR" && git pull
    else
        mkdir -p "$(dirname "$SKILLS_INSTALL_DIR")"
        git clone --recursive "$REPO_URL" "$SKILLS_INSTALL_DIR"
    fi
    echo "Running install from $SKILLS_INSTALL_DIR ..."
    OPENCLAW_SCRIPT_DIR="$SKILLS_INSTALL_DIR" bash "$SKILLS_INSTALL_DIR/openclaw-install.sh"
    exit $?
fi

echo "=== OpenClaw Chess AI Coach Installer ==="
echo "Shared dir:   $CHESSLENS_DIR"
echo "Global skills: $GLOBAL_SKILLS"
echo ""

# ── 0. Check/install Stockfish ─────────────────────────────────────────────
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

# ── 1. Setup $HOME/chessLens/ shared directory ─────────────────────────────
echo ""
echo "[1/7] Setting up shared directory $CHESSLENS_DIR ..."

mkdir -p "$CHESSLENS_DIR"

if [ -L "$SKILLS_INSTALL_DIR" ] || [ -d "$SKILLS_INSTALL_DIR/.git" ]; then
    echo "  [ok] chess-ai-coach-skills already exists"
else
    echo "  [clone] Cloning skills repo..."
    git clone --recursive "$REPO_URL" "$SKILLS_INSTALL_DIR"
fi

if [ -L "$REVIEWS_DIR" ] || [ -d "$REVIEWS_DIR/.git" ]; then
    echo "  [ok] chess-reviews-summary already exists"
else
    echo "  [clone] Cloning reviews repo..."
    git clone "$REVIEWS_REPO_URL" "$REVIEWS_DIR"
fi

# ── 2. Install skills globally ──────────────────────────────────────────────
echo ""
echo "[2/7] Installing skills globally -> $GLOBAL_SKILLS ..."

mkdir -p "$GLOBAL_SKILLS"

for skill_dir in "$SKILLS_INSTALL_DIR/skills"/*; do
    if [ -d "$skill_dir" ]; then
        skill_name="$(basename "$skill_dir")"
        dest="$GLOBAL_SKILLS/$skill_name"

        if [ -L "$dest" ]; then
            existing=$(readlink "$dest")
            if [ "$existing" = "$skill_dir" ]; then
                echo "  [ok]   $skill_name"
            else
                echo "  [更新] $skill_name"
                rm "$dest"; ln -s "$skill_dir" "$dest"
            fi
        elif [ -e "$dest" ]; then
            echo "  [skip] $skill_name: exists"
        else
            echo "  [link] $skill_name"
            ln -s "$skill_dir" "$dest"
        fi
    fi
done

# ── 3. Ensure docs/ directory exists in reviews repo ─────────────────────────
echo ""
echo "[3/7] Ensuring docs/ directory in reviews repo..."

mkdir -p "$REVIEWS_DIR/docs"
echo "  [ok] $REVIEWS_DIR/docs/"

# ── 4. Update main workspace SOUL.md (Chess Analysis Workflow) ──────────────
echo ""
echo "[4/7] Updating main workspace SOUL.md ..."

MAIN_SOUL="$HOME/.openclaw/workspace/SOUL.md"
if [ -f "$MAIN_SOUL" ]; then
    if grep -q "Chess Analysis Workflow\|直接处理.*棋类\|chess-game-history.*skill" "$MAIN_SOUL" 2>/dev/null; then
        echo "  [skip] Chess section already exists"
    elif grep -q "sessions_send.*chess-ai-coach" "$MAIN_SOUL" 2>/dev/null; then
        echo "  [patch] Removing delegation to chess-ai-coach, enabling direct processing..."
        MAIN_SOUL_PATH="$HOME/.openclaw/workspace/SOUL.md"
        python3 << PYEOF
import re
with open("$MAIN_SOUL_PATH", 'r') as f:
    content = f.read()
new_section = """## 棋类相关需求

当用户提到以下内容时，直接处理（不 delegation）：
- 棋、象棋、国际象棋、chess
- 想分析棋局、复盘、查对局
- Chess.com 用户名查询

**处理方式**：
使用 \`chess-game-history\` skill 获取棋谱，\`chess-analysis\` skill 进行 Stockfish 分析。
参考 \`~/.agents/skills/chess-game-history/SKILL.md\` 和 \`~/.agents/skills/chess-analysis/SKILL.md\`。

**共享资源**：
- 分析结果保存到 \`\$HOME/chessLens/chess-reviews-summary/docs/\`
- 与 chess-ai-coach agent 共用同一份 analyses

"""
content = re.sub(r'## 棋类相关需求.*?(?=\n## Vibe|\n## Boundaries)', new_section, content, flags=re.DOTALL, count=1)
with open('$MAIN_SOUL_PATH', 'w') as f:
    f.write(content)
PYEOF
        echo "  [ok] Updated"
    else
        echo "  [insert] Adding chess section to SOUL.md..."
        MAIN_SOUL_PATH="$HOME/.openclaw/workspace/SOUL.md"
        python3 << PYEOF
import re
with open("$MAIN_SOUL_PATH", 'r') as f:
    content = f.read()
new_section = """
## 棋类相关需求

当用户提到以下内容时，直接处理（不 delegation）：
- 棋、象棋、国际象棋、chess
- 想分析棋局、复盘、查对局
- Chess.com 用户名查询

**处理方式**：
使用 \`chess-game-history\` skill 获取棋谱，\`chess-analysis\` skill 进行 Stockfish 分析。
参考 \`~/.agents/skills/chess-game-history/SKILL.md\` 和 \`~/.agents/skills/chess-analysis/SKILL.md\`。

**共享资源**：
- 分析结果保存到 \`\$HOME/chessLens/chess-reviews-summary/docs/\`
- 与 chess-ai-coach agent 共用同一份 analyses

"""
if re.search(r'\n## Vibe', content):
    content = re.sub(r'(\n## Vibe)', new_section + r'\1', content, count=1)
elif re.search(r'\n## Boundaries', content):
    content = re.sub(r'(\n## Boundaries)', new_section + r'\1', content, count=1)
with open('$MAIN_SOUL_PATH', 'w') as f:
    f.write(content)
PYEOF
        echo "  [ok] Inserted"
    fi
else
    echo "  [skip] Main SOUL.md not found at $MAIN_SOUL"
fi

# ── 5. Update main workspace AGENTS.md (Chess Analysis Workflow) ──────────────
echo ""
echo "[5/7] Updating main workspace AGENTS.md ..."

MAIN_AGENTS="$HOME/.openclaw/workspace/AGENTS.md"
if [ -f "$MAIN_AGENTS" ]; then
    if ! grep -q "Chess Analysis Workflow" "$MAIN_AGENTS" 2>/dev/null; then
        # 在 ## Group Chats 前插入 Chess Analysis Workflow
        CHESS_WORKFLOW='## Chess Analysis Workflow

当用户请求分析棋局时，遵循以下流程（skills 位于 `~/.agents/skills/chess-*/`）：

```
🔧 棋类分析工作流程：

Step 1️⃣  chess-game-history（获取棋谱）
   ├── 从 API 获取最新对局 ID
   ├── 检查 $HOME/chessLens/chess-reviews-summary/docs/ 是否已有该 ID 分析
   │   ├── 如已有 → 拉回本地，跳过分析
   │   └── 如没有 → 获取 PGN
   └── 保存 PGN 到 /tmp/game.pgn

Step 2️⃣  chess-analysis（Stockfish 分析）
   └── analyze.py 深度分析（depth=16）+ 生成报告

Step 3️⃣  保存结果
   ├── 写入 $HOME/chessLens/chess-reviews-summary/docs/
   └── commit-if-changed.sh 同步 GitHub

Step 4️⃣  验证 ChessLens 页面
   └── 对比 亮点/失误/步数 字段与列表页是否一致
```

**参考文档**：
- `~/.agents/skills/chess-game-history/SKILL.md`
- `~/.agents/skills/chess-analysis/SKILL.md`

'
        # 用 awk 插入到 "## Group Chats" 之前
        if grep -q "## Group Chats" "$MAIN_AGENTS"; then
            awk -v chunk="$CHESS_WORKFLOW" '/## Group Chats/{print chunk; print; next} 1' "$MAIN_AGENTS" > "$MAIN_AGENTS.tmp" && mv "$MAIN_AGENTS.tmp" "$MAIN_AGENTS"
            echo "  [ok] Inserted Chess Analysis Workflow"
        else
            echo "  [skip] ## Group Chats not found, cannot insert"
        fi
    else
        echo "  [skip] Already has Chess Analysis Workflow"
    fi
else
    echo "  [skip] Main AGENTS.md not found at $MAIN_AGENTS"
fi

# ── 6. Register chess-ai-coach agent ────────────────────────────────────────
echo ""
echo "[6/7] Registering chess-ai-coach agent ..."

TARGET_WORKSPACE="$HOME/.openclaw/workspace-chess-ai-coach"
if openclaw agents list --json 2>/dev/null | grep -q '"id": "chess-ai-coach"'; then
    echo "  [skip] chess-ai-coach agent already registered"
else
    echo "  [register] chess-ai-coach agent..."
    mkdir -p "$TARGET_WORKSPACE"
    openclaw agents add \
        --name chess-ai-coach \
        --workspace "$TARGET_WORKSPACE" \
        --non-interactive
    echo "  [ok] chess-ai-coach agent registered"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Shared directory: $CHESSLENS_DIR"
echo "  ├── chess-ai-coach-skills/  (skills 源码)"
echo "  └── chess-reviews-summary/docs/  (分析结果)"
echo ""
echo "Global skills: $GLOBAL_SKILLS/"
ls "$GLOBAL_SKILLS/" 2>/dev/null | grep chess | sed 's/^/  /'
echo ""
echo "Main workspace updated: SOUL.md + AGENTS.md"
echo "Agent registered: chess-ai-coach"
