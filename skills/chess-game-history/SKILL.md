---
name: chess-game-history
description: >
  获取指定棋手的历史对局记录。当用户说"查一下某人的对局"、
  "获取某账号的棋谱"、"某人在XX平台的历史战绩"、
  "帮我找某人的比赛记录"、"某玩家的对局列表"时触发此 skill。
  Also triggers when user provides a chess platform username and asks for their games.
---

# Chess Game History Fetcher

获取棋手的历史对局记录，并提取完整 PGN 供后续分析。

## 平台支持

| Platform | API Base | Rate Limit |
|---|---|---|
| **Chess.com** | `https://api.chess.com/pub/player/{username}` | ~1000/day |
| **Lichess** | `https://lichess.org/api` | ~300/min |

两者均有免费公开 API，无需 API key。

> ⚠️ **重要：Chess.com 对局列表按时间正序（最旧在前），永远不要直接取 `games[0]`！**
> API 返回的列表第一个是最旧的棋局，最新的在列表末尾。
> 正确做法：`latest_game = max(games, key=lambda g: g.get("end_time", 0))`

---

## 工作流程（检查本地缓存 → API → Fallback）

### 第0步：检查本地缓存（优先）

获取棋手最新对局前，先检查本地是否已有分析记录：

```bash
ANALYSES_DIR="$HOME/.openclaw/workspace-chess-ai-coach/analyses"

# 列出该棋手已有的分析文件
ls "$ANALYSES_DIR/"*_{username}_* 2>/dev/null
```

**判断逻辑：**
```
1. 从 API 获取目标对局基本信息（时间、对手、回合数）
2. 构造文件名：{日期}_{game_id}_{白方}_{胜负}_{黑方}_{回合数}步_{time_control}.md
   示例：2026-04-14_167293652644_aaronwang2026_执白胜_Clement924810_19步_10+0.md
   time_control 格式："10+0"（10分钟+0秒加成）或 "30+0"（30分钟慢棋）
3. 检查 ~/.openclaw/workspace-chess-ai-coach/analyses/ 是否存在同名文件
4. 如已存在 → 直接读取本地文件输出，跳过 API 调用
5. 如不存在 → 继续第1步 API 获取 PGN
```

**重要：** 每次获取对局前必须先执行此检查，避免重复分析同一对局，节省 API 调用。

### 第1步：API 获取 PGN（快）

**适用**：用户提供了 game ID，或者需要先搜索找到目标对局。

```bash
# Chess.com — 获取某月对局
curl "https://api.chess.com/pub/player/{username}/games/{YYYY}/{MM}"

# Chess.com — 获取最近对局（按时间倒序）
curl "https://api.chess.com/pub/player/{username}/games?max=100&until=YYYY-MM-DD"

# Chess.com — 玩家基本信息
curl "https://api.chess.com/pub/player/{username}"

# Lichess — 批量导出
curl "https://lichess.org/api/games/user/{username}?max=100&opts=pgn,evals,opening"
```

**返回数据包含**：
- `pgn` — PGN 字符串
- `white` / `black` — 对手信息（用户名、ELO）
- `result`、`end_time`、`time_control`
- `url` — 游戏页面 URL（含 game ID）

### 第2步：尝试解析（自动判断）

用 `analyze.py` 尝试解析 PGN：

```python
# 伪代码
try:
    analyze_game(pgn, depth=16)  # 如果 PGN 损坏会抛出 illegal san 异常
    print("✅ PGN 正常，直接分析")
except ValueError as e:
    print("⚠️ PGN 损坏，切换到浏览器获取")
    # 触发 agent-browser 流程
```

### 第3步（Fallback）：agent-browser 重新获取 PGN（准）

**触发条件**：analyze.py 解析失败（Chess.com API PGN 数据损坏）

**用户提示**：
```
🔍 正在打开对局页面...
⏳ 正在加载棋谱...
🖱️ 正在提取 PGN...
✅ 获取完成，开始分析...
```

**操作步骤**：
```bash
# 复用已有 session，打开游戏页面
agent-browser open "https://www.chess.com/game/live/{game_id}"
agent-browser wait --load networkidle

# 点击 Share 按钮（通过 snapshot 找到 ref）
agent-browser click @share_ref
agent-browser wait 1000

# 点击 PGN 按钮
agent-browser click @pgn_ref
agent-browser wait 1000

# 获取 PGN 文本
agent-browser get text @pgn_textbox_ref
```

---

## 响应格式（列表展示）

```
📋 {Username} 的对局记录 — {Platform}

共获取 {N} 盘棋 | 胜 {W} / 平 {D} / 负 {L}

---
📅 {Date} | {TimeControl} | {Opening}
⚪ {WhitePlayer} ({Rating}) vs ⚫ {BlackPlayer} ({Rating})
结果：{Result}
🔗 {GameURL}
```

---

## 重要提示

- **Chess.com PGN 损坏**：约 20-30% 的对局 API PGN 在第 11 步附近损坏（着法不合法）。先 try-parse，失败再 fallback 到浏览器。
- **Lichess 数据较干净**：Lichess API 的 PGN 通常可直接使用，fallback 情况较少。
- **Game ID 获取**：用户没给 ID 时，用 API 按时间/月份筛选找到目标对局。
- **Rate Limit**：Chess.com 约 1 req/sec，Lichess 约 5 req/sec。
- **隐私**：Lichess 私密用户无法获取，请告知用户。

## 后续处理

PGN 验证通过后，交给 `chess-analysis` skill 进行详细分析：

```bash
# 调用 chess-analysis skill 的 analyze.py
python3 ~/.agents/skills/chess-analysis/scripts/analyze.py --pgn-file /tmp/game.pgn 16
```

**或**：直接调用 `chess-analysis` skill 进行完整复盘分析。
