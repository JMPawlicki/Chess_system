# Chess Robot System

This repository contains a robotic chess system that connects a **DGT electronic chessboard**, **Stockfish**, a **MATLAB App Designer GUI**, and a **Universal Robots UR3** manipulator.

The system is intended for a physical chess-robot setup. Python handles chess logic, DGT board communication and Stockfish integration. MATLAB handles the graphical interface, robot motion planning data, URScript generation and communication with the UR3 robot.

---

## Repository structure

```text
ChessRobot/
│
├── ChessRobotGUI.mlapp          # Main/normal GUI application
├── ChessRobotGUI_safe.mlapp     # Safe/test GUI application
├── .gitignore                   # Ignored generated/cache/large temporary files
│
├── python/
│   ├── brain_server.py          # Main/normal Python backend
│   ├── brain_server_safe.py     # Safe/test Python backend
│   └── stockfish/
│       └── stockfish-windows-x86-64-avx2.exe
│
├── matlab/
│   ├── robotRegions.m
│   ├── robotPieceParams.m
│   ├── robotMotionParams.m
│   ├── robotBinParams.m
│   ├── robotQueenParams.m
│   ├── robotCommParams.m
│   ├── executeRobotMove.m
│   ├── generateTransferData.m
│   ├── generatePickToBinData.m
│   ├── generateQueenPickData.m
│   ├── append*.m
│   ├── drawBoardFromFen.m
│   └── other helper functions
│
└── docs/
    ├── python_backend_documentation.md
    ├── matlab_functions_documentation.md
    └── gui_documentation.md
```

---

## Main components

| Component | Role |
| ---------- | ------ |
| DGT USB e-Board | Provides physical chessboard state through a serial COM port. |
| Python backend | Maintains the chess state, reads DGT updates, validates moves, communicates with Stockfish and MATLAB. |
| Stockfish | Generates engine moves. |
| MATLAB GUI | Displays the game, starts the backend, receives symbolic robot moves and sends URScript to UR3. |
| MATLAB helper functions | Convert symbolic chess moves into calibrated robot trajectories. |
| UR3 robot | Executes generated URScript and reports completion through `ROBOT_DONE`. |

---

## Operating modes

### Human vs Robot

The human plays on the DGT board. The Python backend detects the human move, validates it with `python-chess`, asks Stockfish for the robot response and sends a structured `ROBOT_MOVE` message to MATLAB. MATLAB generates and sends the URScript to the UR3. After the physical robot action is complete, the robot reports `ROBOT_DONE`, which allows the backend to commit the move and continue the game.

### Computer vs Computer

Both sides are controlled by Stockfish. The robot physically executes every move. In this mode the GUI automatically requests the next engine move after the previous robot movement is completed. The robot does not need to return to the home position after every move, because no human interaction with the board is required between moves.

### Safe mode

The safe version is kept for testing and recovery. It uses the same core move information, but the workflow is more manual and suitable for calibration, debugging and testing individual movement types.

---

## Hardware and communication settings

Default settings used by the current system:

| Item | Value |
| ------ | ------- |
| Python GUI server | `127.0.0.1:5000` |
| UR3 done listener | `0.0.0.0:5001` |
| UR3 robot IP/port | `192.168.0.10:30002` |
| DGT serial port | `COM5` |
| DGT baud rate | `38400` |
| Stockfish path | `python/stockfish/stockfish-windows-x86-64-avx2.exe` |

The UR3 sends a short TCP message:

```text
ROBOT_DONE
```

to the Python backend after completing a generated URScript sequence. The backend forwards this information to MATLAB over the existing GUI connection.

---

## Python backend

The main backend is:

```bash
python/brain_server.py
```

It is normally started from the MATLAB GUI using the **Start Server** button. The GUI starts `python/brain_server.py` from the `python/` directory so that the relative Stockfish path resolves correctly. It can also be started manually:

```bash
cd python
python brain_server.py
```

The backend listens for a MATLAB client on:

```text
127.0.0.1:5000
```

It also starts a separate listener for robot completion messages on:

```text
0.0.0.0:5001
```

### Python dependencies

The backend requires:

```text
python-chess
pyserial
stockfish
```

A minimal installation command is:

```bash
pip install chess pyserial stockfish
```

Depending on the installed package, the chess library may also be installed as:

```bash
pip install python-chess
```

---

## MATLAB GUI

The main GUI application is:

```text
ChessRobotGUI.mlapp
```

The safe/test GUI application is:

```text
ChessRobotGUI_safe.mlapp
```

The GUI performs the following tasks:

- starts the Python backend,
- connects to the backend over TCP,
- connects to the UR3 robot over TCP,
- displays the current board position from FEN,
- displays the move list,
- handles human-vs-robot and computer-vs-computer operation modes,
- receives `ROBOT_MOVE` messages,
- generates URScript using MATLAB helper functions,
- sends generated URScript to UR3,
- handles `ROBOT_DONE`, `ROBOT_MOVE_FAILED`, illegal moves and recovery.

The GUI expects the helper functions to be available in the `matlab/` folder.

---

## MATLAB robot motion layer

The MATLAB functions in `matlab/` convert symbolic chess moves into physical robot actions. They use:

- calibrated 2x2 board regions,
- bilinear square interpolation,
- piece-specific Z corrections,
- piece-specific insertion scaling,
- physical board rotation mapping,
- calibrated capture bin positions,
- one or two spare queen storage slots,
- URScript command generation.

Supported robot move types include:

| Move type | Description |
| ---------- | ------------- |
| `normal` | Move one piece from source square to target square. |
| `capture` | Remove captured piece to bin, then transfer moving piece. |
| `en_passant` | Remove en passant captured pawn, then move the capturing pawn. |
| `castle_kingside` | Move king and rook for kingside castling. |
| `castle_queenside` | Move king and rook for queenside castling. |
| `promotion` | Remove pawn and place a spare queen on the promotion square. |
| `promotion_capture` | Remove captured piece, remove pawn and place a spare queen. |

---

## Spare queen handling

Robot promotions are forced to queen promotions. The system tracks queen availability separately for white and black.

In computer-vs-computer mode, each side may use one physical spare queen. MATLAB chooses the physical spare queen slot based on the color of the promoting piece and the current board orientation.

The physical queen storage positions are configured in:

```text
matlab/robotQueenParams.m
```

The slot selection logic is implemented in:

```text
matlab/chooseQueenSlot.m
```

---

## Protocol

All messages between MATLAB and Python are newline-delimited UTF-8 strings over TCP.

### MATLAB -> Python

| Command | Description |
| --------- | ------------- |
| `CONFIG depth=<1-20> human=<white/black> mode=<human_vs_robot/computer_vs_computer>` | Configure engine depth, human side and operation mode. |
| `NEW_GAME` | Reset game state to the starting position. |
| `READY` | Confirm that the physical board is prepared and the game may proceed. |
| `GET_BEST_MOVE` | Request the next engine/robot move. Valid only when the backend is in engine-turn state. |
| `ROBOT_MOVE_DONE` | Confirm that MATLAB/UR3 has completed the robot move. |
| `PROMOTE <q/r/b/n>` | Complete a human promotion after `PROMOTION_REQUIRED`. |
| `DEBUG_SET_FEN <fen>` | Load a custom FEN position for testing. |
| `GET_FEN` | Request the current backend FEN. |
| `STATUS` | Request backend and DGT board status. |
| `QUIT` | Close the backend session and shut down the server process. |

### Python -> MATLAB

| Message | Description |
| --------- | ------------- |
| `READY_OK` | Backend accepted `READY`. |
| `BOARD_OK` | DGT board is connected. |
| `BOARD_ERROR <text>` | DGT board is not connected or another board error occurred. |
| `STATUS backend=ok board=<ok/error>` | Backend status response. |
| `FEN <fen>` | Current game position. |
| `HUMAN_MOVE <uci>` | Legal human move detected from the DGT board. |
| `ROBOT_MOVE ...` | Full symbolic description of the robot move to execute. |
| `ROBOT_DONE` | Robot reported that the physical move sequence finished. |
| `ROBOT_MOVE_FAILED ...` | Physical board state does not match the expected board after robot movement. |
| `PROMOTION_REQUIRED <uci_base>` | Human pawn reached last rank and requires a promotion piece. |
| `GAME_OVER <result>` | Game ended. |
| `ERROR <text>` | Protocol, chess logic or hardware error. |
| `BYE` | Backend is shutting down. |

---

## `ROBOT_MOVE` format

Python sends robot moves as key-value messages:

```text
ROBOT_MOVE uci=e7e5 type=normal piece=P piece_color=black from=e7 to=e5 capture=none captured=none captured_color=none promotion=none ep=none rook_from=none rook_to=none queen_available=true
```

Important fields:

| Field | Meaning |
| ------- | --------- |
| `uci` | UCI move string. |
| `type` | Robot action type, such as `normal`, `capture`, `en_passant`, `promotion`, `promotion_capture`, `castle_kingside`, `castle_queenside`. |
| `piece` | Moving piece type. |
| `piece_color` | Color of the moving piece. |
| `from`, `to` | Logical chess source and target squares. |
| `capture` | Captured square, if any. |
| `captured` | Captured piece type, if any. |
| `promotion` | Promotion piece, usually `Q` for robot moves. |
| `ep` | En passant captured square. |
| `rook_from`, `rook_to` | Rook movement squares for castling. |
| `queen_available` | Whether the moving side still has a spare queen available. |

MATLAB maps logical chess squares to physical board squares depending on board rotation.

---

## Typical human-vs-robot flow

```text
MATLAB                          Python                         UR3
  |                               |                             |
  |-- CONFIG ... ----------------> |                             |
  |-- NEW_GAME ------------------> |                             |
  |-- READY ---------------------> |                             |
  |<-- READY_OK ------------------ |                             |
  |                               |                             |
  |   [Human moves on DGT]        |                             |
  |<-- HUMAN_MOVE e2e4 ----------- |                             |
  |-- GET_BEST_MOVE ------------> |                             |
  |<-- ROBOT_MOVE e7e5 ---------- |                             |
  |-- URScript ------------------------------->                 |
  |                               |             [execute move]  |
  |                               |<------------ ROBOT_DONE ----|
  |<-- ROBOT_DONE --------------- |                             |
  |-- ROBOT_MOVE_DONE ----------> |                             |
  |-- GET_FEN -------------------> |                             |
  |<-- FEN ... ------------------- |                             |
```

---

## Typical computer-vs-computer flow

```text
MATLAB                          Python                         UR3
  |                               |                             |
  |-- CONFIG ... mode=computer_vs_computer -------------------> |
  |-- NEW_GAME ------------------> |                             |
  |-- READY ---------------------> |                             |
  |<-- READY_OK ------------------ |                             |
  |-- GET_BEST_MOVE ------------> |                             |
  |<-- ROBOT_MOVE ... ----------- |                             |
  |-- URScript ------------------------------->                 |
  |                               |             [execute move]  |
  |                               |<------------ ROBOT_DONE ----|
  |<-- ROBOT_DONE --------------- |                             |
  |-- ROBOT_MOVE_DONE ----------> |                             |
  |-- GET_FEN -------------------> |                             |
  |-- GET_BEST_MOVE ------------> |                             |
  |<-- ROBOT_MOVE ... ----------- |                             |
```

---

## Physical board verification

The normal backend observes DGT updates while the robot is executing a pending engine move. The engine move is not committed to the `python-chess` board immediately after it is generated. Instead, the backend waits for the UR3 `ROBOT_DONE` notification and for MATLAB to send `ROBOT_MOVE_DONE`.

After completion, the backend compares the observed DGT mirror board with the expected board state after the pending move. If both states match, the move is committed to the validated game state. If the position does not match, the backend sends:

```text
ROBOT_MOVE_FAILED expected=<uci> reason=board_mismatch diff=<summary>
```

The GUI then enters recovery mode and asks the operator to restore the physical position according to the last legal FEN.

---

## Recovery and safety

The system includes several recovery mechanisms:

- illegal human move detection,
- custom FEN setup for testing,
- recovery from last legal FEN,
- robot move completion confirmation through `ROBOT_DONE`,
- physical board mismatch detection through `ROBOT_MOVE_FAILED`,
- safe/test GUI version for calibration and manual testing.

---

## Documentation

Detailed documentation is available in:

```text
docs/python_backend_documentation.md
docs/matlab_functions_documentation.md
docs/gui_documentation.md
```

These files describe the Python backend, MATLAB helper functions and GUI logic in more detail.

---

## Version-control notes

Generated caches, MATLAB autosave files, Python bytecode, local logs and large temporary test files should not be committed. The repository should keep source code, calibration files, documentation and reproducible test scripts. Large runtime artifacts, such as temporary `.mat` files, are excluded through `.gitignore`.

If the Stockfish executable is not committed, place it manually in:

```text
python/stockfish/stockfish-windows-x86-64-avx2.exe
```

or update `STOCKFISH_PATH` in the backend accordingly.

---

## Notes

- The DGT board must not be opened by another application while the Python backend is running.
- If DGT Live Chess or another program is using the COM port, Python will not be able to access the board.
- MATLAB sends URScript directly to the UR3 controller through TCP port `30002`.
- Paths and IP addresses may need to be adjusted in `brain_server.py`, `robotCommParams.m` and GUI startup code before running on another computer.
