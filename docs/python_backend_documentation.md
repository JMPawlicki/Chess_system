# Python backend documentation

This document describes the Python backend files used by the chess robot project.

Covered files:

- `python/brain_server.py` — normal/backend version used by the automatic robot workflow.
- `python/brain_server_safe.py` — safe/manual-confirmation variant. It shares most of the same code, but does not perform the full physical-board verification workflow used by the normal backend.

The backend is a TCP server that connects the MATLAB GUI, the DGT electronic chessboard, the Stockfish engine and the UR3 completion signal.

---

## Runtime responsibilities

The backend is responsible for:

- accepting commands from the MATLAB GUI on `127.0.0.1:5000`,
- polling the DGT board over the configured COM port,
- maintaining the logical chess position with `python-chess`,
- maintaining a separate 64-square mirror of the physical DGT board,
- selecting engine moves with Stockfish,
- sending structured `ROBOT_MOVE` descriptions to MATLAB,
- waiting for `ROBOT_DONE` / `ROBOT_MOVE_DONE` before committing engine moves,
- handling promotions, castling, captures and en passant,
- limiting robot queen promotions to one spare queen per color,
- reporting illegal moves, hardware status and game-over conditions.

---

---

## Current normal-mode execution principle

In the normal backend, an engine move is first sent to MATLAB as `ROBOT_MOVE` and stored as `_pending_engine_move`. The move is not pushed to the logical chess board at this point. During robot execution, DGT updates are used to update the physical board mirror. After `ROBOT_DONE` and `ROBOT_MOVE_DONE`, the backend compares the physical mirror with the expected state after the pending move. Only a matching board state allows the move to be committed.

This is the main difference between the normal backend and the safe/manual backend, where the pending engine move is accepted after operator/robot confirmation without full physical-board comparison.

## Main constants

### Network constants

| Constant | Meaning |
|---|---|
| `HOST` | TCP host for MATLAB GUI connection, normally `127.0.0.1`. |
| `PORT` | TCP port for MATLAB GUI commands, normally `5000`. |
| `ROBOT_DONE_HOST` | Host/interface used for UR3 completion listener, usually `0.0.0.0`. |
| `ROBOT_DONE_PORT` | Port where UR3 sends `ROBOT_DONE`, normally `5001`. |

### DGT constants

| Constant | Meaning |
|---|---|
| `SERIAL_PORT` | Serial port used by the DGT board, for example `COM5`. |
| `SERIAL_BAUD` | DGT serial baud rate, currently `38400`. |
| `SERIAL_TIMEOUT` | Serial read timeout in seconds. |
| `DGT_REQ_UPDATE_BOARD` | DGT board update request byte sequence. |
| `SEGMENT_TIMEOUT` | Silence time after which accumulated DGT segments are interpreted as a human move. |
| `ROBOT_SEGMENT_TIMEOUT` | Legacy/experimental robot-observation timeout. In the current normal backend, robot DGT observation is closed by `ROBOT_DONE` rather than by this timeout. |
| `DEBOUNCE_WINDOW` | Delay before re-enabling human DGT input after a robot move. |
| `ROBOT_DONE_DGT_SETTLE` | Delay after UR3 reports completion before forwarding completion to the GUI, giving DGT time to settle. |

### Engine constants

| Constant | Meaning |
|---|---|
| `STOCKFISH_PATH` | Path to the Stockfish executable. In your current structure Stockfish is inside the `python/stockfish/` folder, so relative path `./stockfish/...exe` is expected when the server is started from `python/`. |

---

## Game states

| State | Meaning |
|---|---|
| `STATE_IDLE` | Game exists but is waiting for `READY` or recovery. |
| `STATE_HUMAN_TURN` | Backend accepts DGT segments as a human move. |
| `STATE_ENGINE_TURN` | Backend may answer `GET_BEST_MOVE`. |
| `STATE_WAITING_ENGINE_DONE` | A robot move was sent to MATLAB and is pending physical execution. |
| `STATE_WAITING_PROMOTION` | Human pawn reached the last rank and GUI must choose promotion piece. |
| `STATE_GAME_OVER` | Game has ended and no further moves should be processed. |

---

## Operating modes

| Mode | Meaning |
|---|---|
| `human_vs_robot` | Human moves are read from DGT; robot replies with Stockfish moves. |
| `computer_vs_computer` | Stockfish controls both sides; robot physically executes every move. |

---

## TCP command protocol

### MATLAB → Python

| Command | Arguments | Purpose |
|---|---|---|
| `CONFIG` | `depth=<1..20> human=<white|black> mode=<...>` | Sets Stockfish depth, human color and operating mode. |
| `NEW_GAME` | none | Resets board, internal state and queen-usage flags. |
| `READY` | none | Starts or resumes game logic after setup/recovery. |
| `GET_BEST_MOVE` | none | Requests an engine/robot move when state is `ENGINE_TURN`. |
| `ROBOT_MOVE_DONE` | none | Confirms MATLAB/UR3 physical robot movement. Alias of `ENGINE_MOVE_DONE`. |
| `PROMOTE` | `q`, `r`, `b` or `n` | Completes a human promotion. |
| `DEBUG_SET_FEN` | full FEN | Replaces the current board state for testing. |
| `GET_FEN` | none | Requests the current logical FEN. |
| `STATUS` | none | Requests backend/DGT status. |
| `QUIT` / `SHUTDOWN` | none | Sends `BYE` and schedules process shutdown. |

### Python → MATLAB

| Message | Purpose |
|---|---|
| `READY_OK` | Acknowledges `READY`. |
| `BOARD_OK` | DGT board connection is active. |
| `BOARD_ERROR <text>` | DGT board is not connected or failed. |
| `STATUS backend=ok board=<ok|error>` | Backend/DGT status summary. |
| `FEN <fen>` | Current logical `python-chess` FEN. |
| `HUMAN_MOVE <uci>` | A validated human move was applied. |
| `ROBOT_MOVE ...` | Structured robot action description for MATLAB. |
| `ROBOT_DONE` | Forwarded UR3 completion notification. |
| `ROBOT_MOVE_FAILED ...` | Normal mode physical-board verification failed. |
| `PROMOTION_REQUIRED <uci_base>` | GUI must ask human for promotion piece. |
| `GAME_OVER <result>` | Game ended. |
| `ERROR <text>` | Error or invalid command/state. |
| `BYE` | Backend acknowledged `QUIT`. |

---

## Top-level functions

### `square_id_to_uci(square)`

**Purpose:** Converts a DGT square ID in the range `0..63` to algebraic/UCI square notation such as `a1` or `h8`.

**Arguments:**

- `square` — integer DGT square ID.

**Returns:**

- Two-character square name string.

**Notes:**

- The file index is inverted with `file = 7 - (square % 8)` to match the physical DGT board orientation used in the project.

---

### `initialize_board()`

**Purpose:** Creates the internal 64-element physical-board mirror in the standard starting position.

**Arguments:** none.

**Returns:**

- List of length 64. Empty squares are `None`; pieces are stored as symbols such as `P`, `p`, `N`, `k`.

**Used by:**

- `GameSession.__init__()`
- `_handle_new_game()`

---

### `delayed_process_exit(delay_s=2.0)`

**Purpose:** Starts a daemon thread that waits for `delay_s` seconds and terminates the Python process.

**Arguments:**

- `delay_s` — delay in seconds before calling `os._exit(0)`.

**Returns:** none.

**Side effects:**

- Terminates the whole backend process, usually so the `cmd /c` window closes automatically after GUI shutdown.

---

### `dgt_thread(session, stop_event)`

**Purpose:** Polls the DGT USB board continuously and forwards completed segment groups to `session.handle_dgt_segments()`.

**Arguments:**

- `session` — active `GameSession` object.
- `stop_event` — `threading.Event` used to stop the thread.

**Returns:** none.

**Side effects:**

- Opens serial connection to `SERIAL_PORT`.
- Sends `BOARD_OK` or `BOARD_ERROR` to GUI.
- Accumulates 5-byte DGT segments starting with `0x8e`.
- Uses `SEGMENT_TIMEOUT` to close ordinary human-move segment groups. In the normal backend, robot-move observation is accumulated while `STATE_WAITING_ENGINE_DONE` is active and is finalized when `ROBOT_DONE` is processed.

**Normal vs safe behavior:**

- In `brain_server.py`, DGT segments are also used during `STATE_WAITING_ENGINE_DONE` to update the physical board mirror.
- In `brain_server_safe.py`, DGT input is ignored unless it is the human's turn.

---

### `robot_done_thread(session, stop_event)`

**Purpose:** Listens for `ROBOT_DONE` messages sent by UR3 and forwards them to MATLAB through the existing GUI socket.

**Arguments:**

- `session` — active `GameSession` object.
- `stop_event` — event used to stop the listener.

**Returns:** none.

**Side effects:**

- Opens TCP listener on `ROBOT_DONE_HOST:ROBOT_DONE_PORT`.
- Accepts short-lived UR3 connections.
- Normalizes messages such as literal `ROBOT_DONE\n` into `ROBOT_DONE`.
- Sends `ROBOT_DONE` to MATLAB.
- In normal mode, waits `ROBOT_DONE_DGT_SETTLE` before forwarding, allowing DGT updates to settle before MATLAB sends `ROBOT_MOVE_DONE`.

---

### `handle_client(conn, addr)`

**Purpose:** Handles one MATLAB GUI TCP client connection.

**Arguments:**

- `conn` — accepted socket object.
- `addr` — client address tuple.

**Returns:** none.

**Side effects:**

- Creates a `GameSession`.
- Starts `dgt_thread` and `robot_done_thread`.
- Reads newline-delimited commands from MATLAB.
- Dispatches commands to `session.handle_command()`.
- Stops threads and closes socket on disconnect or `QUIT`.

---

### `main()`

**Purpose:** Entry point for the backend server.

**Arguments:** none.

**Returns:** none.

**Side effects:**

- Creates TCP server on `HOST:PORT`.
- Accepts MATLAB clients.
- Starts `handle_client()` for each client.

---

## Class: `GameSession`

`GameSession` owns the game state for one GUI connection. It is protected by a `threading.Lock` because commands, DGT polling and UR3 completion messages are handled from separate threads.

### Important attributes

| Attribute | Meaning |
|---|---|
| `_depth` | Current Stockfish depth. |
| `_human_is_white` | Human color selection. |
| `_mode` | `human_vs_robot` or `computer_vs_computer`. |
| `_board_connected` | DGT connection status. |
| `_state` | Current state machine state. |
| `_chess_board` | Logical `python-chess.Board`. |
| `_board` | 64-element DGT physical board mirror. |
| `_pending_engine_move` | Engine move sent to MATLAB but not yet committed. |
| `_pending_promotion_uci_base` | Human promotion base move such as `e7e8`. |
| `_engine_queen_promotion_used` | Dict tracking whether each color has used its spare queen. |
| `_robot_observed_segments` | Normal-mode flag that some DGT robot segments were observed. |
| `_robot_physical_mismatch` | Normal-mode flag set if physical-board observation failed. |
| `_stockfish` | Stockfish Python package instance. |

---

### `__init__(self, send_fn)`

**Purpose:** Initializes one game session.

**Arguments:**

- `send_fn` — function that sends one message string to MATLAB.

**Returns:** none.

**Side effects:**

- Creates a standard chess board.
- Initializes DGT mirror board.
- Creates Stockfish instance using `STOCKFISH_PATH`.
- Sets default depth, mode, human color and queen availability flags.

---

### `send(self, msg)`

**Purpose:** Sends one protocol message to MATLAB.

**Arguments:**

- `msg` — message string without trailing newline.

**Returns:** none.

---

### `is_waiting_engine_done(self)`

**Purpose:** Thread-safe check used by `dgt_thread()` to determine whether the robot is currently expected to be moving.

**Arguments:** none.

**Returns:**

- `True` if state is `STATE_WAITING_ENGINE_DONE`; otherwise `False`.

**Only in:**

- Normal backend `brain_server.py`.

---

### `set_board_connected(self)`

**Purpose:** Marks DGT board as connected and notifies MATLAB.

**Arguments:** none.

**Returns:** none.

**Sends:**

- `BOARD_OK`

---

### `set_board_error(self, error_msg)`

**Purpose:** Marks DGT board as disconnected or failed and sends an error message.

**Arguments:**

- `error_msg` — error text.

**Returns:** none.

**Sends:**

- `BOARD_ERROR <error_msg>`

---

### `handle_command(self, line)`

**Purpose:** Parses and dispatches one command received from MATLAB.

**Arguments:**

- `line` — raw command line string.

**Returns:**

- `True` to keep the client session alive.
- `False` when the session should close, typically after `QUIT`.

**Dispatches to:**

- `_handle_config()`
- `_handle_new_game()`
- `_handle_ready()`
- `_handle_get_best_move()`
- `_handle_engine_move_done()`
- `_handle_promote()`
- `_handle_debug_set_fen()`
- `_handle_get_fen()`
- `_handle_status()`
- `_handle_quit()`

---

### `handle_dgt_segments(self, segments)`

**Purpose:** Receives one complete group of DGT low-level segments and decides how to interpret it based on current state.

**Arguments:**

- `segments` — list of DGT 5-byte segment objects.

**Returns:** none.

**Behavior:**

- During `STATE_HUMAN_TURN`, interprets segments as a human move.
- During `STATE_WAITING_ENGINE_DONE` in normal mode, observes the robot's physical move and updates `_board` without committing a chess move.
- Ignores DGT input in states where it is not relevant.

---

### `_handle_config(self, args)`

**Purpose:** Applies configuration parameters from the GUI.

**Arguments:**

- `args` — command tokens after `CONFIG`, e.g. `depth=10`, `human=white`, `mode=computer_vs_computer`.

**Returns:** none.

**Side effects:**

- Updates `_depth`, `_human_is_white`, and `_mode`.
- Sends `ERROR` if parameter values are invalid.

---

### `_handle_new_game(self)`

**Purpose:** Resets session state for a new game.

**Arguments:** none.

**Returns:** none.

**Side effects:**

- Resets `_chess_board` and `_board` to starting position.
- Clears pending moves and pending promotions.
- Resets per-color queen promotion availability.
- Sets Stockfish depth and FEN.
- Sets state to `STATE_IDLE` until `READY`.

---

### `_handle_ready(self)`

**Purpose:** Starts or resumes play after the physical board is prepared.

**Arguments:** none.

**Returns:** none.

**Sends:**

- `READY_OK`

**Side effects:**

- Updates Stockfish FEN/depth.
- Sets state to `STATE_ENGINE_TURN` in computer-vs-computer mode.
- In human-vs-robot mode, sets state according to whose turn it is.

---

### `_handle_status(self)`

**Purpose:** Reports backend and DGT connection status.

**Arguments:** none.

**Returns:** none.

**Sends:**

- `BOARD_OK` and `STATUS backend=ok board=ok`, or
- `BOARD_ERROR ...` and `STATUS backend=ok board=error`.

---

### `_handle_quit(self)`

**Purpose:** Handles GUI shutdown request.

**Arguments:** none.

**Returns:** none.

**Side effects:**

- Sends `BYE`.
- Schedules delayed process exit.

---

### `_handle_get_best_move(self)`

**Purpose:** Selects the next engine move and sends it to MATLAB as a structured robot action.

**Arguments:** none.

**Returns:** none.

**Precondition:**

- State must be `STATE_ENGINE_TURN`.

**Side effects:**

- Updates Stockfish depth and position.
- Calls `_choose_engine_move()`.
- Validates selected move.
- Builds `ROBOT_MOVE` message.
- Stores `_pending_engine_move`.
- Sets state to `STATE_WAITING_ENGINE_DONE`.
- In normal mode, clears physical observation flags before the robot starts.

---

### `_piece_letter(self, piece)`

**Purpose:** Converts a `python-chess` piece object to the uppercase robot piece code.

**Arguments:**

- `piece` — `chess.Piece` or `None`.

**Returns:**

- `P`, `N`, `B`, `R`, `Q`, `K`, or `none`.

---

### `_piece_color_name(self, piece)`

**Purpose:** Converts a `python-chess` piece object to a protocol color string.

**Arguments:**

- `piece` — `chess.Piece` or `None`.

**Returns:**

- `white`, `black`, or `none`.

---

### `_square_name_or_none(self, square)`

**Purpose:** Converts a square index to a square name or `none`.

**Arguments:**

- `square` — python-chess square index or `None`.

**Returns:**

- Square name such as `e4`, or `none`.

---

### `_build_robot_move_message(self, move_uci)`

**Purpose:** Builds a complete `ROBOT_MOVE` protocol message before the move is pushed on the logical board.

**Arguments:**

- `move_uci` — selected engine move in UCI notation, e.g. `e7e5`, `e7e8q`.

**Returns:**

- A string beginning with `ROBOT_MOVE` followed by key-value fields.

**Determines:**

- move type: normal, capture, castling, en passant, promotion, promotion-capture,
- moving piece and color,
- source/destination squares,
- captured piece and captured square,
- rook source/destination for castling,
- promotion piece,
- queen availability for the moving color.

---

### `_is_promotion_move(self, move)`

**Purpose:** Checks whether a UCI move string includes a promotion suffix.

**Arguments:**

- `move` — UCI move string.

**Returns:**

- `True` for strings such as `e7e8q`, `False` otherwise.

---

### `_is_queen_promotion_move(self, move)`

**Purpose:** Checks whether a UCI move is specifically a queen promotion.

**Arguments:**

- `move` — UCI move string.

**Returns:**

- `True` only if the fifth character is `q`.

---

### `_validate_engine_candidate(self, move)`

**Purpose:** Validates whether a Stockfish candidate move is legal and physically executable.

**Arguments:**

- `move` — candidate UCI string or `None`.

**Returns:**

- Valid UCI move string, possibly forced to queen promotion.
- `None` if the move cannot be physically executed.

**Rules:**

- Non-promotion moves must be legal in `python-chess`.
- Engine promotions are forced to queen.
- Each color may use its spare queen only once.
- If that color's queen is already used, promotion candidates are rejected.

---

### `_choose_engine_move(self)`

**Purpose:** Chooses the best Stockfish move that passes physical validation.

**Arguments:** none.

**Returns:**

- UCI move string or `None`.

**Algorithm:**

- Tries `get_top_moves(20)` to collect several candidate moves.
- Adds `get_best_move()` as a fallback.
- Returns first candidate accepted by `_validate_engine_candidate()`.

---

### `_handle_engine_move_done(self)`

**Purpose:** Commits the pending engine move after MATLAB/UR3 confirms physical execution.

**Arguments:** none.

**Returns:** none.

**Precondition:**

- State must be `STATE_WAITING_ENGINE_DONE`.

**Normal backend behavior:**

- Computes expected physical board after `_pending_engine_move`.
- Compares expected board with observed DGT mirror `_board`.
- If mismatch is detected, sends `ROBOT_MOVE_FAILED` and does not push the move.
- If board matches, pushes the move on `_chess_board` and updates Stockfish.
- Marks queen promotion usage for the moving color.
- Switches to `STATE_ENGINE_TURN` in computer-vs-computer mode or starts human-turn debounce.

**Safe backend behavior:**

- Does not compare full physical board state.
- Pushes `_pending_engine_move` when `ROBOT_MOVE_DONE` is received.

---

### `_handle_promote(self, args)`

**Purpose:** Completes a human promotion after GUI chooses the promoted piece.

**Arguments:**

- `args` — list containing one promotion letter: `q`, `r`, `b`, or `n`.

**Returns:** none.

**Precondition:**

- State must be `STATE_WAITING_PROMOTION`.

**Side effects:**

- Forms full UCI promotion move from `_pending_promotion_uci_base`.
- Validates and pushes the move.
- Sends `HUMAN_MOVE <uci>`.
- Sets state to `STATE_ENGINE_TURN` unless game is over.

---

### `_handle_debug_set_fen(self, fen)`

**Purpose:** Sets the board to a custom FEN for testing.

**Arguments:**

- `fen` — complete FEN string.

**Returns:** none.

**Side effects:**

- Clears pending state.
- Sets `_chess_board` and Stockfish position.
- Synchronizes `_board` from the logical board.
- Sets state according to mode and side-to-move.
- Sends `DEBUG_FEN_OK` or `ERROR Invalid FEN`.

---

### `_sync_dgt_board_from_chess(self)`

**Purpose:** Copies the current logical `python-chess` board into the 64-square physical mirror `_board`.

**Arguments:** none.

**Returns:** none.

**Used by:**

- `_handle_debug_set_fen()`

---

### `_maybe_handle_human_promotion(self, uci)`

**Purpose:** Detects whether a four-character human move is actually a pawn promotion requiring GUI selection.

**Arguments:**

- `uci` — base UCI move such as `e7e8`.

**Returns:**

- `True` if promotion flow started.
- `False` if the move can be processed normally.

**Side effects:**

- Sets `_pending_promotion_uci_base`.
- Sets state to `STATE_WAITING_PROMOTION`.
- Sends `PROMOTION_REQUIRED <uci_base>`.

---

### `_handle_get_fen(self)`

**Purpose:** Sends current logical FEN to MATLAB.

**Arguments:** none.

**Returns:** none.

**Sends:**

- `FEN <fen>`

---

### `_observe_robot_dgt_segments(self, current_segments)`

**Purpose:** Updates the DGT mirror while the robot is moving.

**Arguments:**

- `current_segments` — DGT segment group collected during robot execution.

**Returns:** none.

**Only in:**

- Normal backend.

**Side effects:**

- Calls `_apply_robot_segments_to_mirror()`.
- Sets `_robot_observed_segments`.
- Sets `_robot_physical_mismatch` if segment processing fails.

---

### `_apply_robot_segments_to_mirror(self, current_segments)`

**Purpose:** Interprets DGT segment groups from robot movement and applies them to the physical board mirror only.

**Arguments:**

- `current_segments` — list of DGT segments.

**Returns:** none.

**Handles:**

- two-segment normal moves,
- three-segment captures and en passant removal,
- four-segment castling,
- fallback movement for unexpected four-segment groups.

**Important:**

- Does not call `_apply_human_move()`.
- Does not change `_chess_board`.

---

### `_move_piece_on_mirror(self, src_idx, dst_idx)`

**Purpose:** Moves one piece inside `_board`, including promotion conversion if the pending engine move is a promotion.

**Arguments:**

- `src_idx` — source square index.
- `dst_idx` — destination square index.

**Returns:** none.

---

### `_process_dgt_segments(self, current_segments)`

**Purpose:** Interprets DGT segment groups as a human move.

**Arguments:**

- `current_segments` — list of DGT segments.

**Returns:** none.

**Handles:**

- normal move groups,
- capture groups,
- castling groups,
- promotion detection,
- mirror-board update.

**Calls:**

- `_apply_human_move()` or sends `PROMOTION_REQUIRED`.

---

### `_apply_human_move(self, uci)`

**Purpose:** Validates and applies a human move.

**Arguments:**

- `uci` — UCI move string.

**Returns:** none.

**Side effects:**

- Checks legality with `python-chess`.
- Sends `ERROR Illegal move` if invalid.
- Pushes valid move.
- Updates Stockfish FEN.
- Sends `HUMAN_MOVE <uci>`.
- Switches to `STATE_ENGINE_TURN` unless game is over.

---

### `_check_game_over(self)`

**Purpose:** Checks whether the current game is over and notifies MATLAB.

**Arguments:** none.

**Returns:**

- `True` if the game is over.
- `False` otherwise.

**Sends:**

- `GAME_OVER <result>` when applicable.

---

### `_game_result(self)`

**Purpose:** Computes game result from `python-chess` termination conditions.

**Arguments:** none.

**Returns:**

- `1-0`, `0-1`, `1/2-1/2`, or `None`.

**Checks:**

- checkmate,
- stalemate,
- insufficient material,
- seventy-five move rule,
- fivefold repetition,
- claimable threefold repetition,
- claimable fifty-move rule.

---

### `_debounce_to_human_turn(self)`

**Purpose:** Delays transition from robot completion to accepting human DGT input.

**Arguments:** none.

**Returns:** none.

**Side effects:**

- Sleeps for `DEBOUNCE_WINDOW`.
- If state is still `STATE_WAITING_ENGINE_DONE`, sets state to `STATE_HUMAN_TURN`.

---

### `_board_array_from_chess_board(self, board_obj)`

**Purpose:** Converts a `python-chess.Board` into the same 64-element array representation as the DGT mirror.

**Arguments:**

- `board_obj` — `chess.Board` instance.

**Returns:**

- List of 64 elements with piece symbols or `None`.

**Only in:** normal backend.

---

### `_expected_board_after_pending_engine_move(self)`

**Purpose:** Builds the expected physical board after the current pending engine move.

**Arguments:** none.

**Returns:**

- 64-element expected board array, or `None` if no pending move exists.

**Only in:** normal backend.

---

### `_board_diff_summary(self, expected_board, physical_board, max_items=8)`

**Purpose:** Produces a compact text summary of mismatches between expected and physical board arrays.

**Arguments:**

- `expected_board` — expected 64-element board.
- `physical_board` — observed 64-element board.
- `max_items` — maximum mismatch entries to include before truncation.

**Returns:**

- `none` if there are no differences, otherwise semicolon-separated differences such as `e5:expected=p,physical=empty`.

**Only in:** normal backend.

---

## Normal vs safe backend summary

| Feature | `brain_server.py` | `brain_server_safe.py` |
|---|---:|---:|
| MATLAB TCP protocol | yes | yes |
| DGT polling | yes | yes |
| Stockfish integration | yes | yes |
| `ROBOT_MOVE` messages | yes | yes |
| UR3 `ROBOT_DONE` listener | yes | yes |
| Per-color queen promotion limit | yes | yes |
| Observe DGT during robot movement | yes | no |
| Compare full physical board after robot move | yes | no |
| Send `ROBOT_MOVE_FAILED` on mismatch | yes | no |
| Manual confirmation workflow | no, automatic | yes/manual-oriented |

