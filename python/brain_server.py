#!/usr/bin/env python3
"""
brain_server.py – TCP server bridging DGT board, Stockfish and MATLAB robot GUI.

Protocol (newline-delimited UTF-8 over TCP 127.0.0.1:5000):

  MATLAB -> Python:
    CONFIG depth=<int> human=<white|black> mode=<human_vs_robot|computer_vs_computer>
    NEW_GAME
    READY
    GET_BEST_MOVE
    ROBOT_MOVE_DONE         (sent by MATLAB automatically after UR3 reports completion)
    PROMOTE <q|r|b|n>
    SHUTDOWN / QUIT

  Python -> MATLAB:
    READY_OK
    HUMAN_MOVE <uci>
    ROBOT_MOVE uci=<uci> type=<normal|capture|castle_kingside|castle_queenside|promotion|promotion_capture|en_passant> ...
    PROMOTION_REQUIRED <uci_base>   (e.g. e7e8)
    GAME_OVER <result>              (1-0 | 0-1 | 1/2-1/2)
    ERROR <text>
"""

import os
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
ROBOT_DONE_HOST = "0.0.0.0"
ROBOT_DONE_PORT = 5001
SERIAL_PORT = "COM5"
SERIAL_BAUD = 38400
SERIAL_TIMEOUT = 0.3
STOCKFISH_PATH = "./stockfish/stockfish-windows-x86-64-avx2.exe"

DGT_REQ_UPDATE_BOARD = bytes([0x44])
SEGMENT_TIMEOUT = 2.5   # seconds of silence before treating segments as a move
DEBOUNCE_WINDOW = 1.5   # seconds after ENGINE_MOVE_DONE before re-enabling DGT

# ---------------------------------------------------------------------------
# State / mode constants
# ---------------------------------------------------------------------------
STATE_IDLE = "IDLE"
STATE_HUMAN_TURN = "HUMAN_TURN"
STATE_ENGINE_TURN = "ENGINE_TURN"
STATE_WAITING_ENGINE_DONE = "WAITING_ENGINE_DONE"
STATE_WAITING_PROMOTION = "WAITING_PROMOTION"
STATE_GAME_OVER = "GAME_OVER"

MODE_HUMAN_VS_ROBOT = "human_vs_robot"
MODE_COMPUTER_VS_COMPUTER = "computer_vs_computer"


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
# AppCloser
# ---------------------------------------------------------------------------
def delayed_process_exit(delay_s=2.0):
    def worker():
        print(f"[SERVER] Closing process in {delay_s:.1f} seconds...")
        time.sleep(delay_s)
        print("[SERVER] Exiting now.")
        os._exit(0)

    t = threading.Thread(target=worker, daemon=True)
    t.start()

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
        self._mode = MODE_HUMAN_VS_ROBOT
        self._board_connected = False
        self._board_error = ""

        # Game state
        self._state = STATE_IDLE
        self._chess_board = chess.Board()
        self._board = initialize_board()
        self._pending_engine_move = None
        self._pending_promotion_uci_base = None

        # Robot inventory constraint: only one extra queen is available
        # for engine/robot promotions in a single game.
        self._engine_queen_promotion_used = {
            "white": False,
            "black": False,
        }

        self._stockfish = Stockfish(path=STOCKFISH_PATH)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def send(self, msg):
        self._send(msg)

    def set_board_connected(self):
        with self._lock:
            self._board_connected = True
            self._board_error = ""
        self.send("BOARD_OK")


    def set_board_error(self, error_msg):
        with self._lock:
            self._board_connected = False
            self._board_error = str(error_msg)
        self.send(f"BOARD_ERROR {self._board_error}")

    def handle_command(self, line):
        """
        Parse and dispatch a single command line from MATLAB.
        Returns False if the session should be terminated (SHUTDOWN / QUIT).
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
            elif cmd in ("ENGINE_MOVE_DONE", "ROBOT_MOVE_DONE"):
                self._handle_engine_move_done()
            elif cmd == "PROMOTE":
                self._handle_promote(parts[1:])
            elif cmd == "SHUTDOWN / QUIT":
                return False
            elif cmd == "DEBUG_SET_FEN":
                fen = " ".join(parts[1:])
                self._handle_debug_set_fen(fen)
            elif cmd == "GET_FEN":
                self._handle_get_fen()
            elif cmd == "STATUS":
                self._handle_status()
            elif cmd == "QUIT":
                self._handle_quit()
                return False
            else:
                self.send(f"ERROR Unknown command: {cmd}")
        return True

    def handle_dgt_segments(self, segments):
        """
        Process a completed group of DGT segments (called from DGT thread).
        DGT input is ignored unless the state is STATE_HUMAN_TURN.
        In computer-vs-computer mode, DGT human input is ignored completely.
        """
        with self._lock:
            if self._mode != MODE_HUMAN_VS_ROBOT:
                return
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

            elif arg.startswith("mode="):
                val = arg[5:].lower()
                if val in (MODE_HUMAN_VS_ROBOT, MODE_COMPUTER_VS_COMPUTER):
                    self._mode = val
                else:
                    self.send("ERROR mode must be 'human_vs_robot' or 'computer_vs_computer'")
                    return

            else:
                self.send(f"ERROR Unknown CONFIG parameter: {arg}")
                return

    def _handle_new_game(self):
        self._chess_board = chess.Board()
        self._board = initialize_board()
        self._pending_engine_move = None
        self._pending_promotion_uci_base = None
        self._engine_queen_promotion_used = {
            "white": False,
            "black": False,
        }

        self._stockfish.set_depth(self._depth)
        self._stockfish.set_fen_position(self._chess_board.fen())

        # Always wait for READY.
        # Even in computer-vs-computer mode, READY means: the physical board is prepared
        # and the operator allows the first robot move.
        self._state = STATE_IDLE

    def _handle_ready(self):
        self._stockfish.set_depth(self._depth)
        self._stockfish.set_fen_position(self._chess_board.fen())
        self.send("READY_OK")
    
        if self._mode == MODE_COMPUTER_VS_COMPUTER:
            self._state = STATE_ENGINE_TURN
            return
    
        side_to_move_is_white = (self._chess_board.turn == chess.WHITE)
        human_to_move = (side_to_move_is_white == self._human_is_white)
    
        self._state = STATE_HUMAN_TURN if human_to_move else STATE_ENGINE_TURN
    
    def _handle_status(self):
        if getattr(self, "_board_connected", False):
            self.send("BOARD_OK")
            self.send("STATUS backend=ok board=ok")
        else:
            self.send("BOARD_ERROR DGT board is not connected")
            self.send("STATUS backend=ok board=error")

    def _handle_quit(self):
        self.send("BYE")
        print("[SERVER] Quit received from GUI. Shutting down.")
        delayed_process_exit(2.0)

    def _handle_get_best_move(self):
        if self._state != STATE_ENGINE_TURN:
            self.send("ERROR GET_BEST_MOVE requires ENGINE_TURN state")
            return

        self._stockfish.set_depth(self._depth)
        self._stockfish.set_fen_position(self._chess_board.fen())

        move = self._choose_engine_move()

        if move is None:
            self.send("ERROR No physically executable engine move found")
            return

        # Validate the final selected move.
        try:
            move_obj = chess.Move.from_uci(move)
            if move_obj not in self._chess_board.legal_moves:
                self.send(f"ERROR Stockfish returned illegal move: {move}")
                return
        except Exception as exc:
            self.send(f"ERROR invalid engine move: {exc}")
            return

        robot_move_msg = self._build_robot_move_message(move)

        self._pending_engine_move = move
        self._state = STATE_WAITING_ENGINE_DONE
        self.send(robot_move_msg)

    def _piece_letter(self, piece) -> str:
        """Return uppercase robot piece letter P/N/B/R/Q/K or 'none'."""
        if piece is None:
            return "none"
        return piece.symbol().upper()

    def _piece_color_name(self, piece) -> str:
        """Return white/black/none for protocol readability."""
        if piece is None:
            return "none"
        return "white" if piece.color == chess.WHITE else "black"

    def _square_name_or_none(self, square) -> str:
        if square is None:
            return "none"
        return chess.square_name(square)

    def _build_robot_move_message(self, move_uci: str) -> str:
        """
        Build a complete robot-action description for MATLAB before the move
        is pushed on the python-chess board.

        The message is deliberately key=value text so MATLAB can parse it
        without JSON dependencies.  All squares are logical chess squares;
        MATLAB maps them to physical squares when boardRotated180 is true.
        """
        move_obj = chess.Move.from_uci(move_uci)

        from_sq = move_obj.from_square
        to_sq = move_obj.to_square
        moving_piece = self._chess_board.piece_at(from_sq)

        move_type = "normal"
        capture_square = None
        captured_piece = None
        ep_square = None
        promotion_piece = "none"
        rook_from = None
        rook_to = None

        is_en_passant = self._chess_board.is_en_passant(move_obj)
        is_castling = self._chess_board.is_castling(move_obj)
        is_capture = self._chess_board.is_capture(move_obj)
        is_promotion = move_obj.promotion is not None

        if is_castling:
            from_file = chess.square_file(from_sq)
            to_file = chess.square_file(to_sq)
            rank = chess.square_rank(from_sq)

            if to_file > from_file:
                move_type = "castle_kingside"
                rook_from = chess.square(7, rank)
                rook_to = chess.square(5, rank)
            else:
                move_type = "castle_queenside"
                rook_from = chess.square(0, rank)
                rook_to = chess.square(3, rank)

        elif is_en_passant:
            move_type = "en_passant"
            capture_square = chess.square(chess.square_file(to_sq), chess.square_rank(from_sq))
            ep_square = capture_square
            captured_piece = self._chess_board.piece_at(capture_square)

        else:
            if is_capture:
                capture_square = to_sq
                captured_piece = self._chess_board.piece_at(capture_square)

            if is_promotion:
                promotion_piece = chess.piece_symbol(move_obj.promotion).upper()
                move_type = "promotion_capture" if is_capture else "promotion"
            elif is_capture:
                move_type = "capture"

        move_color = self._piece_color_name(moving_piece)

        if move_color in ("white", "black"):
            queen_available = not self._engine_queen_promotion_used[move_color]
        else:
            queen_available = False
            
        fields = {
            "uci": move_uci,
            "type": move_type,
            "piece": self._piece_letter(moving_piece),
            "piece_color": self._piece_color_name(moving_piece),
            "from": chess.square_name(from_sq),
            "to": chess.square_name(to_sq),
            "capture": self._square_name_or_none(capture_square),
            "captured": self._piece_letter(captured_piece),
            "captured_color": self._piece_color_name(captured_piece),
            "promotion": promotion_piece,
            "ep": self._square_name_or_none(ep_square),
            "rook_from": self._square_name_or_none(rook_from),
            "rook_to": self._square_name_or_none(rook_to),
            "queen_available": str(queen_available).lower(),
        }

        return "ROBOT_MOVE " + " ".join(f"{key}={value}" for key, value in fields.items())

    def _is_promotion_move(self, move: str) -> bool:
        return len(move) == 5 and move[4] in "qrbn"

    def _is_queen_promotion_move(self, move: str) -> bool:
        return len(move) == 5 and move[4] == "q"

    def _validate_engine_candidate(self, move: str):
        """
        Return a physically executable UCI move, or None.

        Rules for physical robot execution:
        - Engine promotions are forced to queen.
        - The engine/robot may use the extra queen only once per game.
        - If the extra queen was already used, all further engine promotion
          candidates are rejected and Stockfish must choose a non-promotion move.
        """
        if move is None:
            return None

        move = str(move).strip()
        if not move:
            return None

        # Normal non-promotion move.
        if not self._is_promotion_move(move):
            try:
                move_obj = chess.Move.from_uci(move)
                return move if move_obj in self._chess_board.legal_moves else None
            except Exception:
                return None

        # Engine promotion color is the current side to move.
        promotion_color = "white" if self._chess_board.turn == chess.WHITE else "black"

        # This side has already used its physical spare queen.
        if self._engine_queen_promotion_used[promotion_color]:
            return None

        # Force all engine promotions to queen.
        queen_move = move[:4] + "q"

        try:
            queen_move_obj = chess.Move.from_uci(queen_move)
            if queen_move_obj in self._chess_board.legal_moves:
                return queen_move
        except Exception:
            return None

        return None

    def _choose_engine_move(self):
        """
        Pick the best Stockfish move that is also physically executable.

        Prefer get_top_moves() when available, because it lets us skip a
        forbidden second queen promotion and choose the next best move.
        Fall back to get_best_move() if top moves are unavailable.
        """
        candidate_moves = []

        try:
            top_moves = self._stockfish.get_top_moves(20)
            for item in top_moves or []:
                move = item.get("Move") if isinstance(item, dict) else None
                if move and move not in candidate_moves:
                    candidate_moves.append(move)
        except Exception:
            # Some stockfish package versions/configurations may not expose
            # get_top_moves reliably. In that case use get_best_move below.
            pass

        try:
            best_move = self._stockfish.get_best_move()
            if best_move and best_move not in candidate_moves:
                candidate_moves.append(best_move)
        except Exception:
            pass

        if not candidate_moves:
            return None

        for candidate in candidate_moves:
            move = self._validate_engine_candidate(candidate)
            if move is not None:
                return move

        return None

    def _handle_engine_move_done(self):
        if self._state != STATE_WAITING_ENGINE_DONE:
            self.send("ERROR ENGINE_MOVE_DONE requires WAITING_ENGINE_DONE state")
            return
        if self._pending_engine_move:
            try:
                executed_engine_move = self._pending_engine_move
            
                promotion_color = None
                if self._is_queen_promotion_move(executed_engine_move):
                    promotion_color = "white" if self._chess_board.turn == chess.WHITE else "black"
            
                self._chess_board.push_uci(executed_engine_move)
            
                if promotion_color is not None:
                    self._engine_queen_promotion_used[promotion_color] = True
            
                self._stockfish.set_fen_position(self._chess_board.fen())
            
            except Exception as exc:
                self.send(f"ERROR applying engine move: {exc}")
                return
            self._pending_engine_move = None
        if self._check_game_over():
            return

        if self._mode == MODE_COMPUTER_VS_COMPUTER:
            # The robot/engine plays both sides.  After the operator confirms the
            # robot move, the GUI may request the next BEST_MOVE immediately.
            self._state = STATE_ENGINE_TURN
        else:
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

    def _handle_debug_set_fen(self, fen: str):
        try:
            # Reset all pending state so we don't carry old engine moves/promotions
            self._pending_engine_move = None
            self._pending_promotion_uci_base = None

            self._chess_board.set_fen(fen)
            self._stockfish.set_fen_position(fen)
            self._sync_dgt_board_from_chess()

            # Decide whose turn it should be next based on the selected mode.
            if self._mode == MODE_COMPUTER_VS_COMPUTER:
                self._state = STATE_ENGINE_TURN
            else:
                side_to_move_is_white = (self._chess_board.turn == chess.WHITE)
                human_to_move = (side_to_move_is_white == self._human_is_white)
                self._state = STATE_HUMAN_TURN if human_to_move else STATE_ENGINE_TURN

            self.send("DEBUG_FEN_OK")
        except Exception as e:
            self.send(f"ERROR Invalid FEN: {e}")

    def _sync_dgt_board_from_chess(self):
        """Sync the internal 64-element DGT mirror board from python-chess board."""
        arr = [None] * 64
        for sq in chess.SQUARES:
            p = self._chess_board.piece_at(sq)
            if p is None:
                continue
            # python-chess uses a1=0..h8=63 already
            arr[sq] = p.symbol()  # 'P','p','N','n', etc.
        self._board = arr

    def _maybe_handle_human_promotion(self, uci: str) -> bool:
        """
        Returns True if promotion flow was started and the caller should stop.
        Returns False if move can be applied normally.
        """
        if len(uci) != 4:
            return False

        try:
            mv = chess.Move.from_uci(uci)
        except Exception:
            return False

        piece = self._chess_board.piece_at(mv.from_square)
        if piece is None or piece.piece_type != chess.PAWN:
            return False

        to_rank = chess.square_rank(mv.to_square)  # 0..7
        if piece.color == chess.WHITE and to_rank != 7:
            return False
        if piece.color == chess.BLACK and to_rank != 0:
            return False

        # It's a pawn reaching last rank => promotion required
        self._pending_promotion_uci_base = uci
        self._state = STATE_WAITING_PROMOTION
        self.send(f"PROMOTION_REQUIRED {uci}")
        return True
    def _handle_get_fen(self):
        # Send current python-chess FEN (single line)
        fen = self._chess_board.fen()
        self.send(f"FEN {fen}")

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
        
        # If a human pawn reaches the last rank, DGT reports only the base move (e.g. e7e8).
        # Promotions must be completed via PROMOTION_REQUIRED -> PROMOTE <q|r|b|n>.
        if self._maybe_handle_human_promotion(uci_base):
            return
        self._apply_human_move(uci_base)

    def _apply_human_move(self, uci):
        """Validate and push a human move; emit HUMAN_MOVE or ERROR."""
        try:
            # --- DEBUG (start) ---
            #print(f"[DEBUG] _apply_human_move called with uci={uci}")
            #print(f"[DEBUG] turn={'white' if self._chess_board.turn == chess.WHITE else 'black'}")
            #print(f"[DEBUG] FEN={self._chess_board.fen()}")
            # --- DEBUG (end) ---

            move_obj = chess.Move.from_uci(uci)

            if move_obj not in self._chess_board.legal_moves:
                # --- DEBUG (illegal) ---
                promo_candidates = []
                if len(uci) == 4:
                    # If this is a 4-char move like e7e8, show what promotion moves exist
                    base = uci
                    for p in ["q", "r", "b", "n"]:
                        try:
                            m = chess.Move.from_uci(base + p)
                            if m in self._chess_board.legal_moves:
                                promo_candidates.append(base + p)
                        except Exception:
                            pass
                legal_sample = [m.uci() for m in list(self._chess_board.legal_moves)[:30]]
                #print(f"[DEBUG] illegal uci={uci}")
                #print(f"[DEBUG] promotion candidates for base={uci}: {promo_candidates}")
                #print(f"[DEBUG] first legal moves: {legal_sample}")
                # --- DEBUG end ---

                self.send(f"ERROR Illegal move: {uci}")
                return

            self._chess_board.push_uci(uci)
            self._stockfish.set_fen_position(self._chess_board.fen())

        except Exception as exc:
            #print(f"[DEBUG] exception applying uci={uci}: {exc}")
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
        session.set_board_error(f"Serial open failed on {SERIAL_PORT}: {exc}")
        return
    except Exception as exc:
        print(f"[DGT] Unexpected open failed: {exc}")
        session.set_board_error(f"Unexpected DGT open error on {SERIAL_PORT}: {exc}")
        return

    print(f"[DGT] Connected on {SERIAL_PORT}")
    session.set_board_connected()

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
    session.set_board_error("DGT disconnected")
    print("[DGT] Disconnected.")

def robot_done_thread(session, stop_event):
    """
    Listen for ROBOT_DONE messages from UR3.

    UR3 connects to ROBOT_DONE_PORT and sends:
        ROBOT_DONE\n

    This thread forwards ROBOT_DONE to MATLAB over the existing GUI socket.
    """
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        srv.bind((ROBOT_DONE_HOST, ROBOT_DONE_PORT))
        srv.listen(1)
        srv.settimeout(1.0)
        print(f"[UR3_DONE] Listening on {ROBOT_DONE_HOST}:{ROBOT_DONE_PORT}")
    except Exception as exc:
        print(f"[UR3_DONE] Failed to start listener: {exc}")
        try:
            srv.close()
        except Exception:
            pass
        session.send(f"ERROR UR3_DONE listener failed: {exc}")
        return

    try:
        while not stop_event.is_set():
            try:
                conn, addr = srv.accept()
            except socket.timeout:
                continue
            except OSError:
                break

            print(f"[UR3_DONE] Connection from {addr}")

            try:
                conn.settimeout(2.0)
                data = conn.recv(1024)
                msg_raw = data.decode("utf-8", errors="ignore").strip()
                msg = msg_raw.replace("\\n", "").strip()
                
                print(f"[UR3_DONE] Received: {msg_raw}")
                
                if msg == "ROBOT_DONE":
                    session.send("ROBOT_DONE")
                else:
                    session.send(f"ERROR Unknown UR3_DONE message: {msg_raw}")

            except Exception as exc:
                print(f"[UR3_DONE] Receive error: {exc}")
                session.send(f"ERROR UR3_DONE receive error: {exc}")

            finally:
                try:
                    conn.close()
                except Exception:
                    pass

    finally:
        try:
            srv.close()
        except Exception:
            pass
        print("[UR3_DONE] Listener stopped.")

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
    robot_done_stop = threading.Event()
    robot_done_t = threading.Thread(
        target=robot_done_thread,
        args=(session, robot_done_stop),
        daemon=True
    )
    robot_done_t.start()
    close_requested = False
    
    try:
        conn.settimeout(1.0)
    
        while not close_requested:
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
    
                if not line:
                    continue
                
                keep_running = session.handle_command(line)
    
                if keep_running is False:
                    print("[SERVER] QUIT command received. Closing connection.")
                    close_requested = True
                    dgt_stop.set()
                    break
                
    finally:
        dgt_stop.set()
        robot_done_stop.set()
    
        try:
            dgt_t.join(timeout=1.0)
        except Exception:
            pass

        try:
            robot_done_t.join(timeout=1.0)
        except Exception:
            pass

        
        try:
            conn.close()
        except Exception:
            pass
        
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
