#!/usr/bin/env python3
"""
chess-analysis/scripts/analyze.py
批量分析 PGN：一次启动 Stockfish，逐局面评估，输出 Markdown 报告

用法：
  python3 analyze.py "PGN..." [depth]
  python3 analyze.py --pgn-file game.pgn [depth]
"""

import re
import sys
import chess
import chess.engine
import chess.pgn
import io
from pathlib import Path

DEFAULT_DEPTH = 16
DEFAULT_STOCKFISH_PATH = "/opt/homebrew/bin/stockfish"


def find_stockfish(stockfish_path=None):
    if stockfish_path and Path(stockfish_path).exists():
        return stockfish_path
    linux_paths = [
        "/usr/games/stockfish",
        "/usr/local/bin/stockfish",
        "/opt/homebrew/bin/stockfish",
        "/opt/homebrew/bin/stockfish-mac",
    ]
    for p in linux_paths:
        if Path(p).exists():
            return p
    return "stockfish"


def clean_pgn(pgn_text: str) -> str:
    """预处理 PGN，移除时钟注释等非标准内容。"""
    # 移除时钟注释 {[%clk 0:09:59.5]}
    text = re.sub(r'\{[^{}]*\}', '', pgn_text)
    # 移除评估注释 {[%eval ...]}
    text = re.sub(r'\[%eval[^{}]*\]', '', text)
    # 移除其他 [% ...] 格式的注释
    text = re.sub(r'\[%[^\]]*\]', '', text)
    # 规范化换行：保留 header 之间和 header 与 moves 之间的单换行
    # 先把 3+ 换行压缩为 2 换行
    text = re.sub(r'\n{3,}', '\n\n', text)
    # 把 header 行内的多余空格去掉（同一行内压缩空格）
    lines = text.split('\n')
    cleaned_lines = []
    for line in lines:
        if line.startswith('[') or line.strip() == '':
            # Header 行或空行，保持原样（去掉尾部空格）
            cleaned_lines.append(line.rstrip())
        else:
            # Move 行，压缩多余空格但保留换行
            cleaned_lines.append(re.sub(r'\s+', ' ', line).strip())
    # 最后去掉首尾空白
    return '\n'.join(cleaned_lines).strip()


def parse_pgn(pgn_text: str) -> chess.pgn.Game:
    cleaned = clean_pgn(pgn_text)
    game = chess.pgn.read_game(io.StringIO(cleaned))
    if game is None:
        raise ValueError("无法解析 PGN，请检查格式")
    return game


def get_opening_name(eco_url: str) -> str:
    if not eco_url:
        return "未知开局"
    return eco_url.split("/")[-1].replace("-", " ")


def fmt_score(pov_score: chess.engine.PovScore, board: chess.Board) -> str:
    """Format a PovScore as a display string."""
    rs = pov_score.relative
    if rs.is_mate():
        mate = rs.mate()
        return f"Mate {'+' if mate > 0 else ''}{mate}"
    cp = rs.score() / 100
    return f"{'+' if cp >= 0 else ''}{cp:.2f}"


def eval_icon(pov_score: chess.engine.PovScore) -> str:
    rs = pov_score.relative
    if rs.is_mate():
        return "👑"
    cp = rs.score() / 100
    if cp >= 2.0:
        return "🟢"
    elif cp >= 0.5:
        return "🟡"
    elif cp >= -0.5:
        return "⚖️"
    elif cp >= -2.0:
        return "🔴"
    else:
        return "💀"


def cp_score(pov_score: chess.engine.PovScore) -> float:
    """Get centipawn score as float, treating mate as large number."""
    rs = pov_score.relative
    if rs.is_mate():
        return 1000.0 if rs.mate() > 0 else -1000.0
    return rs.score() / 100.0


def analyze_game(pgn_text: str, depth: int = DEFAULT_DEPTH, stockfish_path: str = None):
    engine_path = find_stockfish(stockfish_path)
    engine = chess.engine.SimpleEngine.popen_uci(engine_path)

    try:
        game = parse_pgn(pgn_text)
    except Exception as e:
        engine.quit()
        raise e

    headers = dict(game.headers)
    white = headers.get("White", "?")
    black = headers.get("Black", "?")
    result = headers.get("Result", "?")
    eco_url = headers.get("ECOUrl", "")
    opening = get_opening_name(eco_url)
    tc = headers.get("TimeControl", "?")
    term = headers.get("Termination", "")

    nodes = list(game.mainline())
    total = len(nodes)

    print("=" * 58)
    print(f"  🏁 {white} (⚪) vs {black} (⚫)  —  {result}")
    print(f"  📁 {opening}")
    print(f"  ⏱️  {tc}  |  共 {total//2} 步")
    print("=" * 58)
    print(f"\n📈 局面评估走势（depth={depth}）：")
    print(f"{'步':>5} {'着法':>10}  {'评估':>12}  {'趋势'}")
    print("-" * 55)

    prev_pov = None
    mistakes = []
    blunders = []

    for i, node in enumerate(nodes):
        board = node.board()
        move_no = (i // 2) + 1
        side = "白" if i % 2 == 0 else "黑"
        san = node.san()

        try:
            info = engine.analyse(board, chess.engine.Limit(depth=depth))
            pov_score = info["score"]
        except Exception:
            pov_score = chess.engine.PovScore(
                chess.engine.Score(chess.engine.Cp(0), None), board.turn
            )

        ev_str = fmt_score(pov_score, board)
        icon = eval_icon(pov_score)

        marker = ""
        if prev_pov is not None:
            prev_cp = cp_score(prev_pov)
            curr_cp = cp_score(pov_score)
            drop = prev_cp - curr_cp
            if drop > 1.0:
                marker = "💥 BLUNDER"
                blunders.append((move_no, side, san, drop))
            elif drop > 0.3:
                marker = "⚠️ MISTAKE"
                mistakes.append((move_no, side, san, drop))

        print(f"{move_no:>4}.{side:<3} {san:>10}  {icon}{ev_str:>12}  {marker}")

        # Store score from opponent's perspective at this position (before the move)
        prev_pov = pov_score

    engine.quit()

    print("\n" + "=" * 55)
    if blunders:
        print(f"💥 昏着（评估下跌 > 1.0 兵）：")
        for mno, side, san, drop in blunders:
            print(f"   第 {mno} 步（{side}）：{san}  跌 {drop:.2f}")
    else:
        print("💥 昏着：无")

    if mistakes:
        print(f"\n⚠️ 失误（评估下跌 0.3~1.0 兵）：")
        for mno, side, san, drop in mistakes:
            print(f"   第 {mno} 步（{side}）：{san}  跌 {drop:.2f}")
    else:
        print("⚠️ 失误：无")

    print(f"\n🎯 开局：{opening}")
    print("\n💡 关键局面 FEN：")

    key_indices = set()
    for mno, *_ in (blunders[:3] + mistakes[:3]):
        idx = (mno - 1) * 2
        if idx < total:
            key_indices.add(idx)
    if total > 0:
        key_indices.add(total - 1)

    for idx in sorted(key_indices):
        node = nodes[idx]
        mno = (idx // 2) + 1
        side = "白" if idx % 2 == 0 else "黑"
        fen = node.board().fen()
        print(f"  {mno}.{side}: {fen}")


if __name__ == "__main__":
    pgn_input = None
    depth = DEFAULT_DEPTH
    stockfish_path = None

    args = sys.argv[1:]
    if not args:
        print("用法：python3 analyze.py \"PGN...\" [depth] [--stockfish-path PATH]", file=sys.stderr)
        print("      python3 analyze.py --pgn-file game.pgn [depth] [--stockfish-path PATH]", file=sys.stderr)
        sys.exit(1)

    i = 0
    pgn_file_used = False
    while i < len(args):
        if args[i] == "--pgn-file":
            with open(args[i + 1]) as f:
                pgn_input = f.read()
            pgn_file_used = True
            i += 2
        elif args[i] == "--stockfish-path":
            stockfish_path = args[i + 1]
            i += 2
        else:
            # Everything else is PGN or depth
            if args[i].startswith("-"):
                try:
                    depth = int(args[i])
                except ValueError:
                    pass
            else:
                # Only treat as PGN if we haven't already loaded a file
                if not pgn_file_used and pgn_input is None:
                    pgn_input = args[i]
            i += 1

    if not pgn_input:
        print("错误：未提供 PGN 内容", file=sys.stderr)
        sys.exit(1)

    try:
        analyze_game(pgn_input, depth, stockfish_path)
    except Exception as ex:
        print(f"错误：{ex}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
