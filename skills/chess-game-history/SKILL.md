---
name: chess-game-history
description: >
  获取指定棋手的歷史对局记录。当用户说"查一下某人的对局"、
  "获取某账号的棋谱"、"某人在XX平台的历史战绩"、
  "帮我找某人的比赛记录"、" lichess/chess.com 历史对局"、
  "某玩家的对局列表"时触发此 skill。
  触发词包括：历史对局、比赛记录、棋谱查询、战绩、
  games、history、player games、username 的对局。
  Also triggers when user provides a chess platform username and asks for their games.
---

# Chess Game History Fetcher

Fetches historical chess game records for a given account on chess platforms.

## Supported Platforms

| Platform | API Base | Rate Limit |
|---|---|---|
| **Chess.com** | `https://api.chess.com/pub/player/{username}` | ~1000/day |
| **Lichess** | `https://lichess.org/api` | ~300/min |

Both platforms have free public APIs — no API key required.

## Input Parameters

Collect from the user (ask if missing):
- **Username** (required): the player's username on the platform
- **Platform** (optional, default: auto-detect from username format or ask):
  - `chess.com` — usernames with `/` (e.g. `fabiano_caruana`)
  - `lichess` — usernames with `@` prefix or lichess.org URL
- **Time control filter** (optional): `blitz` / `rapid` / `classical` / `bullet` / `all` (default: `all`)
- **Color filter** (optional): `white` / `black` / `both` (default: `both`)
- **Limit** (optional, default 10, max 100): number of games to fetch
- **Date range** (optional): e.g. `2024-01` to `2024-12`

## How to Fetch

### Chess.com

```bash
# Get player's games for a specific month
curl "https://api.chess.com/pub/player/{username}/games/2024/01"

# Get most recent games (paginated, max ~300/month per request)
curl "https://api.chess.com/pub/player/{username}/games?max=100&until=YYYY-MM-DD"

# Player profile (to verify username exists)
curl "https://api.chess.com/pub/player/{username}"
```

Response is JSON. Each game object contains:
- `pgn` — full PGN string
- `white`, `black` — opponent info with `rating`
- `result`, `end_time`, `time_control`, `rules` (chess variant)
- `url` — the game's page URL

### Lichess

```bash
# Export games (best for bulk)
curl "https://lichess.org/api/games/user/{username}?max=100&opts=pgn,evals,opening"

# With filters
curl "https://lichess.org/api/games/user/{username}?max=100&since=1704067200000&until=1735689600000&clocks=true&evals=true&opening=true"

# Player info
curl "https://lichess.org/api/user/{username}"
```

Lichess returns ndjson (newline-delimited JSON). Parse line by line.

## Response Format

Always present the fetched data as:

```
📋 [{Username}] 的对局记录 — [{Platform}]

共获取 {N} 盘棋 | 胜 {W} 胜 / {D} 平 / {L} 负

---
📅 {Date} | {TimeControl} | {Opening}
⚪ {WhitePlayer} ({WhiteRating}) vs ⚫ {BlackPlayer} ({BlackRating})
结果：{Result}
🔗 {GameURL}
```

Then optionally show the full PGN for 1-3 selected games (the most interesting ones).

## Important Notes

- **Pagination**: Chess.com limits ~100 games per month. For more games, loop through months.
- **Auto-detect platform**: if user gives `lichess.org//@username` URL, extract username and use Lichess API.
- **Rate limits**: add a short sleep between requests if fetching multiple months. Chess.com is stricter — do not exceed ~1 req/sec.
- **Error handling**: if username not found, tell the user clearly. If API returns 0 games, say so and suggest different filters.
- **Privacy**: some Lichess users have private profiles — note if games are not accessible.
- **Variant**: default to `chess` (standard). Some users may ask for `chess960` or `fromPosition` — support if requested.

## PGN Processing

After fetching PGN strings, you can pass them to the `chess-analysis` skill for detailed review of individual games. Just summarize the game list here and offer to analyze specific games.
