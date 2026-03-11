#!/usr/bin/env python3
"""
brain_server.py – Headless TCP server bridging DGT board + Stockfish to MATLAB.

Protocol (newline-delimited UTF-8 over TCP 127.0.0.1:5000):

  MATLAB -> Python:
    CONFIG depth=<int> human=<white|black>
    NEW_GAME
    READY
    GET_BEST_MOVE
    ENGINE_MOVE_DONE
    PROMOTE <q|r|b|n>
    SHUTDOWN

  Python -> MATLAB:
    READY_OK
    HUMAN_MOVE <uci>
    BEST_MOVE <uci>
    PROMOTION_REQUIRED <uci_base>   (e.g. e7e8)
    GAME_OVER <result>              (1-0 | 0-1 | 1/2-1/2)
    ERROR <text>
"""

import socket
import threading
import time
import chess
import serial
from stockfish import Stockfish

# ---------------------------------------------------------------------------
# Hardware / engine constants
# ---------------------------------------------------------------------------
HOST = "127.0.0.1"
PORT = 5000
SERIAL_PORT = "COM6"
SERIAL_BAUD = 38400
SERIAL_TIMEOUT = 0.3
STOCKFISH_PATH = "./stockfish/stockfish-windows-x86-64-avx2.exe"

DGT_REQ_UPDATE_BOARD = bytes([0x44])
SEGMENT_TIMEOUT = 2.5   # seconds of silence before treating segments as a move
DEBOUNCE_WINDOW = 1.5   # seconds after ENGINE_MOVE_DONE before re-enabling DGT

# ---------------------------------------------------------------------------
# State constants
# ---------------------------------------------------------------------------
STATE_IDLE = "IDLE"
STATE_HUMAN_TURN = "HUMAN_TURN"
STATE_ENGINE_TURN = "ENGINE_TURN"
STATE_WAITING_ENGINE_DONE = "WAITING_ENGINE_DONE"
STATE_WAITING_PROMOTION = "WAITING_PROMOTION"
STATE_GAME_OVER = "GAME_OVER"


# ---------------------------------------------------------------------------
# Board helpers (mirrored from chess_system_legacy.py)
# ---------------------------------------------------------------------------
def square_id_to_uci(square):
    """Convert a DGT square ID (0-63) to UCI notation (a1-h8)."""
    file = 7 - (square % 8)
    rank = square // 8
    return chr(ord('a') + file) + str(rank + 1)


def initialize_board():
    """Return a fresh 64-element board array (index 0 = a1)."""
    board = [None] * 64
    for i in range(8, 16):
        board[i] = 'P'
    for i in range(48, 56):
        board[i] = 'p'
    board[0], board[7] = 'R', 'R'
    board[1], board[6] = 'N', 'N'
    board[2], board[5] = 'B', 'B'
    board[3], board[4] = 'Q', 'K'
    board[56], board[63] = 'r', 'r'
    board[57], board[62] = 'n', 'n'
    board[58], board[61] = 'b', 'b'
    board[59], board[60] = 'q', 'k'
    return board


# ---------------------------------------------------------------------------
# GameSession
# ---------------------------------------------------------------------------
class GameSession:
    """
    Manages a single client connection's game state.

    All mutable state is protected by _lock.  send() is safe to call from
    any thread (the DGT thread and the command handler thread).
    """

    def __init__(self, send_fn):
        self._send = send_fn
        self._lock = threading.Lock()

        # Configuration (may be updated via CONFIG before READY)
        self._depth = 5
        self._human_is_white = True

        # Game state
        self._state = STATE_IDLE
        self._chess_board = chess.Board()
        self._board = initialize_board()
        self._pending_engine_move = None
        self._pending_promotion_uci_base = None

        self._stockfish = Stockfish(path=STOCKFISH_PATH)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def send(self, msg):
        self._send(msg)

    def handle_command(self, line):
        """
        Parse and dispatch a single command line from MATLAB.
        Returns False if the session should be terminated (SHUTDOWN).
        """
        parts = line.strip().split()
        if not parts:
            return True
        cmd = parts[0].upper()
        with self._lock:
            if cmd == "CONFIG":
                self._handle_config(parts[1:])
            elif cmd == "NEW_GAME":
                self._handle_new_game()
            elif cmd == "READY":
                self._handle_ready()
            elif cmd == "GET_BEST_MOVE":
                self._handle_get_best_move()
            elif cmd == "ENGINE_MOVE_DONE":
                self._handle_engine_move_done()
            elif cmd == "PROMOTE":
                self._handle_promote(parts[1:])
            elif cmd == "SHUTDOWN":
                return False
            else:
                self.send(f"ERROR Unknown command: {cmd}")
        return True

    def handle_dgt_segments(self, segments):
        """
        Process a completed group of DGT segments (called from DGT thread).
        DGT input is ignored unless the state is STATE_HUMAN_TURN.
        """
        with self._lock:
            if self._state != STATE_HUMAN_TURN:
                return
            self._process_dgt_segments(segments)

    # ------------------------------------------------------------------
    # Command handlers (all called with _lock held)
    # ------------------------------------------------------------------

    def _handle_config(self, args):
        for arg in args:
            if arg.startswith("depth="):
                try:
                    d = int(arg[6:])
                    if 1 <= d <= 20:
                        self._depth = d
                    else:
                        self.send("ERROR depth must be between 1 and 20")
                        return
                except ValueError:
                    self.send("ERROR invalid depth value")
                    return
            elif arg.startswith("human="):
                val = arg[6:].lower()
                if val == "white":
                    self._human_is_white = True
                elif val == "black":
                    self._human_is_white = False
                else:
                    self.send("ERROR human must be 'white' or 'black'")
                    return
            else:
                self.send(f"ERROR Unknown CONFIG parameter: {arg}")
                return

    def _handle_new_game(self):
        self._chess_board = chess.Board()
        self._board = initialize_board()
        self._pending_engine_move = None
        self._pending_promotion_uci_base = None
        self._state = STATE_IDLE

    def _handle_ready(self):
        if self._state != STATE_IDLE:
            self.send("ERROR READY requires IDLE state; send NEW_GAME first")
            return
        self._stockfish.set_depth(self._depth)
        self._stockfish.set_fen_position(self._chess_board.fen())
        self.send("READY_OK")
        if self._human_is_white:
            self._state = STATE_HUMAN_TURN
        else:
            self._state = STATE_ENGINE_TURN

    def _handle_get_best_move(self):
        if self._state != STATE_ENGINE_TURN:
            self.send("ERROR GET_BEST_MOVE requires ENGINE_TURN state")
            return
        move = self._stockfish.get_best_move()
        if move is None:
            self.send("ERROR Stockfish returned no move")
            return
        # Engine promotions are always forced to queen
        if len(move) == 5 and move[4] in "rbn":
            move = move[:4] + "q"
        self._pending_engine_move = move
        self._state = STATE_WAITING_ENGINE_DONE
        self.send(f"BEST_MOVE {move}")

    def _handle_engine_move_done(self):
        if self._state != STATE_WAITING_ENGINE_DONE:
            self.send("ERROR ENGINE_MOVE_DONE requires WAITING_ENGINE_DONE state")
            return
        if self._pending_engine_move:
            try:
                self._chess_board.push_uci(self._pending_engine_move)
                self._stockfish.set_fen_position(self._chess_board.fen())
            except Exception as exc:
                self.send(f"ERROR applying engine move: {exc}")
                return
            self._pending_engine_move = None
        if self._check_game_over():
            return
        # Debounce: remain in WAITING_ENGINE_DONE until window expires,
        # then transition to HUMAN_TURN (via background thread).
        threading.Thread(target=self._debounce_to_human_turn, daemon=True).start()

    def _handle_promote(self, args):
        if self._state != STATE_WAITING_PROMOTION:
            self.send("ERROR PROMOTE requires WAITING_PROMOTION state")
            return
        if not args or args[0].lower() not in ("q", "r", "b", "n"):
            self.send("ERROR PROMOTE requires piece: q, r, b, or n")
            return
        piece = args[0].lower()
        uci = self._pending_promotion_uci_base + piece
        try:
            move_obj = chess.Move.from_uci(uci)
            if move_obj not in self._chess_board.legal_moves:
                self.send(f"ERROR Illegal promotion move: {uci}")
                return
            self._chess_board.push_uci(uci)
            self._stockfish.set_fen_position(self._chess_board.fen())
        except Exception as exc:
            self.send(f"ERROR applying promotion: {exc}")
            return
        self._pending_promotion_uci_base = None
        self.send(f"HUMAN_MOVE {uci}")
        if not self._check_game_over():
            self._state = STATE_ENGINE_TURN

    # ------------------------------------------------------------------
    # DGT processing (called with _lock held)
    # ------------------------------------------------------------------

    def _process_dgt_segments(self, current_segments):
        n = len(current_segments)
        if n == 2:
            src_idx = current_segments[0][3]
            dst_idx = current_segments[1][3]
        elif n == 3:
            # Capture: lift captured piece, lift attacker, place attacker
            src_idx = current_segments[1][3]
            dst_idx = current_segments[2][3]
        elif n == 4:
            squares = [seg[3] for seg in current_segments]
            uci_squares = [square_id_to_uci(sq) for sq in squares]
            castling = None
            if "e1" in uci_squares and "g1" in uci_squares:
                castling = "e1g1"
            elif "e1" in uci_squares and "c1" in uci_squares:
                castling = "e1c1"
            elif "e8" in uci_squares and "g8" in uci_squares:
                castling = "e8g8"
            elif "e8" in uci_squares and "c8" in uci_squares:
                castling = "e8c8"
            if castling:
                self._apply_human_move(castling)
                return
            src_idx = squares[0]
            dst_idx = squares[1]
        else:
            return

        if src_idx == dst_idx:
            return

        dst_rank = int(square_id_to_uci(dst_idx)[1])
        piece = self._board[src_idx]

        # Update internal board
        self._board[dst_idx] = self._board[src_idx]
        self._board[src_idx] = None

        src_uci = square_id_to_uci(src_idx)
        dst_uci = square_id_to_uci(dst_idx)
        uci_base = src_uci + dst_uci

        # Promotion detection
        if (piece == 'P' and dst_rank == 8) or (piece == 'p' and dst_rank == 1):
            self._pending_promotion_uci_base = uci_base
            self._state = STATE_WAITING_PROMOTION
            self.send(f"PROMOTION_REQUIRED {uci_base}")
            return

        self._apply_human_move(uci_base)

    def _apply_human_move(self, uci):
        """Validate and push a human move; emit HUMAN_MOVE or ERROR."""
        try:
            move_obj = chess.Move.from_uci(uci)
            if move_obj not in self._chess_board.legal_moves:
                self.send(f"ERROR Illegal move: {uci}")
                return
            self._chess_board.push_uci(uci)
            self._stockfish.set_fen_position(self._chess_board.fen())
        except Exception as exc:
            self.send(f"ERROR applying move {uci}: {exc}")
            return
        self.send(f"HUMAN_MOVE {uci}")
        if not self._check_game_over():
            self._state = STATE_ENGINE_TURN

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _check_game_over(self):
        """If game is over, emit GAME_OVER and transition state. Returns True if over."""
        result = self._game_result()
        if result:
            self._state = STATE_GAME_OVER
            self.send(f"GAME_OVER {result}")
            return True
        return False

    def _game_result(self):
        """Return result string or None."""
        b = self._chess_board
        if b.is_checkmate():
            return "0-1" if b.turn == chess.WHITE else "1-0"
        if (b.is_stalemate() or
                b.is_insufficient_material() or
                b.is_seventyfive_moves() or
                b.is_fivefold_repetition() or
                b.can_claim_threefold_repetition() or
                b.can_claim_fifty_moves()):
            return "1/2-1/2"
        return None

    def _debounce_to_human_turn(self):
        """Sleep for DEBOUNCE_WINDOW then switch state to HUMAN_TURN."""
        time.sleep(DEBOUNCE_WINDOW)
        with self._lock:
            if self._state == STATE_WAITING_ENGINE_DONE:
                self._state = STATE_HUMAN_TURN


# ---------------------------------------------------------------------------
# DGT polling thread
# ---------------------------------------------------------------------------
def dgt_thread(session, stop_event):
    """
    Continuously polls the DGT board over serial.
    Forwards completed segment groups to session.handle_dgt_segments().
    """
    try:
        ser = serial.Serial(SERIAL_PORT, SERIAL_BAUD, timeout=SERIAL_TIMEOUT)
    except serial.SerialException as exc:
        print(f"[DGT] Serial open failed: {exc}")
        return

    print(f"[DGT] Connected on {SERIAL_PORT}")
    current_segments = []
    last_segment_time = None

    while not stop_event.is_set():
        ser.write(DGT_REQ_UPDATE_BOARD)
        data = ser.read(32)
        current_time = time.time()

        for i in range(0, len(data), 5):
            segment = data[i:i + 5]
            if len(segment) < 4 or segment[0] != 0x8e:
                continue
            current_segments.append(segment)
            last_segment_time = current_time

        if (current_segments and last_segment_time and
                (current_time - last_segment_time > SEGMENT_TIMEOUT)):
            session.handle_dgt_segments(list(current_segments))
            current_segments = []
            last_segment_time = None

        time.sleep(0.01)

    ser.close()
    print("[DGT] Disconnected.")


# ---------------------------------------------------------------------------
# Client handler
# ---------------------------------------------------------------------------
def handle_client(conn, addr):
    """Handle a single MATLAB client connection (runs in its own thread)."""
    print(f"[Server] Client connected: {addr}")
    buf = ""

    def send_fn(msg):
        try:
            conn.sendall((msg + "\n").encode("utf-8"))
        except OSError:
            pass

    session = GameSession(send_fn)

    dgt_stop = threading.Event()
    dgt_t = threading.Thread(target=dgt_thread, args=(session, dgt_stop), daemon=True)
    dgt_t.start()

    try:
        conn.settimeout(1.0)
        while True:
            try:
                data = conn.recv(4096)
            except socket.timeout:
                continue
            except OSError:
                break
            if not data:
                break
            buf += data.decode("utf-8")
            while "\n" in buf:
                line, buf = buf.split("\n", 1)
                line = line.strip()
                if line:
                    if not session.handle_command(line):
                        return  # SHUTDOWN received
    finally:
        dgt_stop.set()
        conn.close()
        print(f"[Server] Client disconnected: {addr}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as srv:
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.bind((HOST, PORT))
        srv.listen(1)
        print(f"[Server] Listening on {HOST}:{PORT}")
        try:
            while True:
                conn, addr = srv.accept()
                t = threading.Thread(
                    target=handle_client, args=(conn, addr), daemon=True
                )
                t.start()
                t.join()  # accept one client at a time
        except KeyboardInterrupt:
            print("[Server] Shutting down.")


if __name__ == "__main__":
    main()
