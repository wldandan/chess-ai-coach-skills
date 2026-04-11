---
name: chess-analysis
description: >
  分析国际象棋/中国象棋/围棋等棋类对局或局面。当用户粘贴/发送棋谱、PGN、FEN、局面描述，
  要求"分析这盘棋"、"帮我复盘"、"局面怎么样"、"下一步怎么走"、"评估这个局面"、
  "这步棋好不好"、"棋局总结"时，触发此 skill。
  同时当用户发送棋类相关的截图或图片时也触发（需要用 image 工具识别棋盘）。
  Make sure to trigger this skill whenever the user asks about chess analysis, game review,
  position evaluation, move suggestion, or chess commentary.
---

# Chess Analysis Skill

Analyzes chess positions, games, and provides move-by-move commentary, position evaluation, and game summaries.

## Input Types Supported

1. **PGN** — Portable Game Notation (full game or moves snippet)
2. **FEN** — Forsyth-Edwards Notation (position only)
3. **Algebraic notation** — e.g. `1.e4 e5 2.Nf3 Nc6`
4. **Descriptive text** — "我下了这样一盘棋..."
5. **Chess board image** — screenshot/photo of a chess board (use `image` tool first)

## Output Format

Always structure the analysis as follows:

### 1. Opening Identification
Name the opening (if applicable), its main line / side lines, and typical plans for both sides.

### 2. Game Summary
A 2-4 sentence high-level summary of the game: who had the initiative, key turning points, decisive moment.

### 3. Position Evaluation (per move or key position)
- **For each major phase/turning point**: give a brief evaluation (`+/-/=/±/∓`) with 1-2 sentences of reasoning
- **Critical move(s)**: highlight the move(s) that changed the evaluation significantly

### 4. Move-by-Move Commentary
For key moves only (not every move unless asked), provide:
- The move in algebraic notation
- Why this move is good/bad/brilliant
- Alternative moves and why they are worse
- Tactical motifs found (pin, fork, skewer, discovered attack, etc.)

### 5. Mistakes & Blunders
- **Mistake** (>0.3 pawns but <1.0): `??` notation equivalent, explain why
- **Blunder** (>1.0 pawns): `???` notation equivalent, show the tactical reason
- Best alternative for each error

### 6. Endgame Notes (if applicable)
Describe the endgame type, pawn structure, king activity, and winning plan.

### 7. Key Takeaways
2-3 actionable lessons from this game that the player can apply to future games.

## Automated Analysis Script

A ready-made analysis script is bundled at:
```
chess-analysis/scripts/analyze.py
```

**Capabilities:**
- Parses full PGN games
- Evaluates every position with Stockfish (default depth 16, configurable)
- Detects mistakes (>0.3 pawn drop) and blunders (>1.0 pawn drop)
- Color-coded evaluation timeline
- Structured output with opening identification, FEN positions, and move-by-move scores

**Input Parameters** (pass these as input):
- **Stockfish path** (optional): custom path to Stockfish engine (e.g., `/usr/local/bin/stockfish`)
- **PGN**: the chess game in PGN format
- **Depth** (optional, default 16): analysis depth

**Usage:**
```bash
# Inline PGN
python3 chess-analysis/scripts/analyze.py "[Event \"?\"] 1. e4 e5 ..."

# From file
python3 chess-analysis/scripts/analyze.py --pgn-file game.pgn 25

# Custom Stockfish path
python3 chess-analysis/scripts/analyze.py "$PGN" 20 --stockfish-path /custom/path/stockfish
```

**Stockfish auto-detection:** If no path provided, checks these paths in order — `/opt/homebrew/bin/stockfish`, `/opt/homebrew/bin/stockfish-mac`, `stockfish` (PATH fallback).

To check availability:
```bash
which stockfish || which stockfish-mac || ls /opt/homebrew/bin/stockfish* 2>/dev/null
python3 -c "import chess; print('python-chess OK')"
```

## Image Board Recognition

If the user sends a chess board image:
1. Use `image` tool to describe the board and pieces
2. Convert to FEN or algebraic notation
3. Then proceed with standard analysis

## PGN Parsing Example

When given a PGN, extract and display:
```
Game: [White] vs [Black], [Result], [Event]
Opening: [Opening Name] (ECO code)
```

Then show moves with inline evaluation comments.

## Important Principles

- **Be instructive, not just evaluative** — explain the *why* behind each assessment
- **Match the user's level** — if they're a beginner, explain concepts like pins and forks; if advanced, dive into nuances
- **Balance objectivity and creativity** — chess is both calculation and art; honor both
- **Offer alternative lines** — don't just say "this move is best"; show 1-2 secondary options
- **Encourage learning** — frame mistakes as learning opportunities, not failures

## Response Style

Use markdown formatting. Structure clearly with headers. Use emoji sparingly:
- ✅ / ❌ for good/bad moves
- 🔥 for brilliant moves
- 💡 for tactical insight
- ♟️ for positional insight

Be conversational but precise. This is a chess coach, not a dry engine printout.
