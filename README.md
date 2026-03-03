# Chess System – Brain Server

This repository contains a Python-based chess brain that bridges a **DGT electronic board** and **Stockfish** to an external **MATLAB** controller over a local TCP connection.

---

## Files

| File | Description |
|------|-------------|
| `brain_server.py` | New headless TCP server (main entry point) |
| `chess_system_legacy.py` | Original interactive script (preserved for reference) |
| `matlab_client_example.m` | MATLAB example showing the full command/event flow |
| `stockfish/` | Stockfish engine binary |

---

## Running the server

```
python brain_server.py
```

The server listens on **127.0.0.1:5000** and accepts one MATLAB client at a time. It requires:

- DGT board on **COM6** at **38400 baud**
- Stockfish at `./stockfish/stockfish-windows-x86-64-avx2.exe`

If the serial port is unavailable the server still starts; DGT input is simply ignored.

---

## Protocol

All messages are **newline-delimited UTF-8** strings over TCP.

### MATLAB → Python (commands)

| Command | Description |
|---------|-------------|
| `CONFIG depth=<1-20> human=<white\|black>` | Set engine depth and human colour. May be sent before `READY`. |
| `NEW_GAME` | Reset board to starting position. |
| `READY` | Start the session. Server replies `READY_OK`. |
| `GET_BEST_MOVE` | Ask for Stockfish's move (engine turn only). |
| `ENGINE_MOVE_DONE` | Notify server that the robot has finished executing the engine move. |
| `PROMOTE <q\|r\|b\|n>` | Reply to a `PROMOTION_REQUIRED` event with the chosen piece. |
| `SHUTDOWN` | Close the session. |

### Python → MATLAB (events)

| Event | Description |
|-------|-------------|
| `READY_OK` | Session started successfully. |
| `HUMAN_MOVE <uci>` | Human move detected on the DGT board (e.g. `e2e4`). |
| `BEST_MOVE <uci>` | Engine move computed (e.g. `e7e5`). Robot should execute it. |
| `PROMOTION_REQUIRED <uci_base>` | Human pawn reached the last rank (e.g. `e7e8`). Send `PROMOTE` with chosen piece. |
| `GAME_OVER <result>` | Game ended; result is `1-0`, `0-1`, or `1/2-1/2`. |
| `ERROR <text>` | Protocol or logic error. |

---

## Turn gating

- DGT input is only processed when it is the **human's turn** (`HUMAN_TURN` state).
- While waiting for `GET_BEST_MOVE` or `ENGINE_MOVE_DONE`, DGT events are ignored.
- After `ENGINE_MOVE_DONE` a **0.5 s debounce** window elapses before DGT is re-enabled.

---

## Promotion handling

**Human promotion** flow:
1. DGT detects pawn on last rank → server sends `PROMOTION_REQUIRED e7e8`.
2. MATLAB sends `PROMOTE q` (or `r`, `b`, `n`).
3. Server applies the move and sends `HUMAN_MOVE e7e8q`.

**Engine promotion**: Stockfish's chosen piece is always overridden to **queen** (`q`).

---

## Typical session flow

```
MATLAB                          Python
  |                               |
  |-- CONFIG depth=5 human=white ->|
  |-- NEW_GAME -------------------->|
  |-- READY ------------------------>|
  |<-------------- READY_OK --------|
  |                               |
  |    [Human moves on DGT board] |
  |<---------- HUMAN_MOVE e2e4 ----|
  |-- GET_BEST_MOVE --------------->|
  |<----------- BEST_MOVE e7e5 ----|
  |    [Robot executes e7e5]      |
  |-- ENGINE_MOVE_DONE ------------>|
  |                   [0.5s debounce]
  |    [Human moves on DGT board] |
  |<---------- HUMAN_MOVE ... -----|
  ...
  |<---------- GAME_OVER 1-0 ------|
  |-- SHUTDOWN -------------------->|
```

---

## MATLAB example

See [`matlab_client_example.m`](matlab_client_example.m) for a complete example.

Run with:
```matlab
run('matlab_client_example.m')
```
