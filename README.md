# Chess AI Coach Skills

国际象棋 AI 教练工具集，提供棋局分析和对局历史查询功能。

## 安装

**一条命令安装（推荐）：**
```bash
curl -fsSL https://raw.githubusercontent.com/wldandan/chess-ai-coach-skills/main/openclaw-install.sh | bash
```

这会自动：
1. 克隆代码到 `~/Projects/chess-ai-coach-skills`
2. 安装 Stockfish（如未安装）
3. 配置全局 Skills 和工作区

**自定义安装目录：**
```bash
OPENCLAW_REPO_DIR=/path/to/repo curl -fsSL https://raw.githubusercontent.com/wldandan/chess-ai-coach-skills/main/openclaw-install.sh | bash
```

安装到 `~/.openclaw/workspace-chess-ai-coach/`

## 功能

### Skills

| Skill | 功能 |
|-------|------|
| `chess-analysis` | 棋局分析，支持 PGN/FEN/图片识别 |
| `chess-game-history` | 查询 Chess.com/Lichess 用户历史对局 |
| `chess-player-stats` | 棋手统计数据查询和分析 |

### Agents

包含 Input Handling Workflow，自动识别用户输入类型并调用对应 skill。

## 使用

1. **分析棋谱**：直接发送 PGN、FEN 或棋盘截图
2. **查询对局**：发送 Chess.com/Lichess 用户名或链接
3. **复盘**：获取历史对局后可进一步分析
4. **查询战绩**：发送用户名查询胜率、等级分等统计

## 项目结构

```
├── agents/          # Agent 配置和 Workflow
├── skills/          # Skill 定义
│   ├── chess-analysis/
│   ├── chess-game-history/
│   └── chess-player-stats/
├── hooks/           # OpenClaw Hooks
│   └── review-sync/ # 自动同步复盘到 Git
├── commands/        # 命令集
├── claudecode-install.sh  # Claude Code 安装脚本
└── openclaw-install.sh
```

## 复盘同步

复盘结果自动保存到 `~/.openclaw/workspace-chess-ai-coach/analyses/`，并通过双重机制同步到 Git：

1. **主流程**：每次复盘后立即 commit + push
2. **备用兜底**：Cron 每 30 分钟检查遗漏

## 代码更新

修改代码后提交：

```bash
cd ~/Projects/chess-ai-coach-skills
git add .
git commit -m "描述改动"
git push
```

其他机器重新运行安装命令即可更新。
