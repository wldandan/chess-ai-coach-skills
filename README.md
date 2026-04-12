# Chess AI Coach Skills

国际象棋 AI 教练工具集，提供棋局分析和对局历史查询功能。

## 安装

```bash
./openclaw-install.sh
```

安装到 `~/.openclaw/workspace-chess-ai-coach/`

## 功能

### Skills

| Skill | 功能 |
|-------|------|
| `chess-analysis` | 棋局分析，支持 PGN/FEN/图片识别 |
| `chess-game-history` | 查询 Chess.com/Lichess 用户历史对局 |

### Agents

包含 Input Handling Workflow，自动识别用户输入类型并调用对应 skill。

## 使用

1. **分析棋谱**：直接发送 PGN、FEN 或棋盘截图
2. **查询对局**：发送 Chess.com/Lichess 用户名或链接
3. **复盘**：获取历史对局后可进一步分析

## 项目结构

```
├── agents/          # Agent 配置和 Workflow
├── skills/          # Skill 定义
│   ├── chess-analysis/
│   └── chess-game-history/
├── commands/        # 命令集
└── openclaw-install.sh
```
