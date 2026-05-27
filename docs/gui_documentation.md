# MATLAB GUI documentation

This document describes the App Designer GUI class `ChessRobotGUI`, stored as `ChessRobotGUI.mlapp` in the main project folder.

The GUI is the operator interface for the robotic chess system. It connects to the Python backend, displays the current chessboard, lists moves, generates URScript for robot moves, sends the script to UR3 and handles completion/recovery messages.

A separate `ChessRobotGUI_safe.mlapp` variant may exist for manual testing. The documentation below focuses on the normal automatic GUI, with notes where safe behavior differs.

---

---

## Current implementation status

The normal GUI is the automatic operating version. Manual confirmation controls used during early safe-mode testing are removed or automated. Robot motion is started after a `ROBOT_MOVE` message is parsed, and completion is handled through the `ROBOT_DONE` / `ROBOT_MOVE_DONE` loop.

The safe GUI remains useful for calibration and debugging because it allows additional operator confirmation between stages.

## High-level responsibilities

The GUI is responsible for:

- starting the Python backend,
- connecting to the backend TCP server,
- connecting to UR3 over port `30002`,
- sending configuration commands,
- displaying the board from FEN,
- displaying move history,
- parsing `ROBOT_MOVE` messages,
- generating URScript through MATLAB helper functions,
- sending generated URScript to UR3,
- responding to `ROBOT_DONE`,
- handling recovery after illegal or failed robot moves,
- supporting human-vs-robot and computer-vs-computer modes,
- optionally starting from custom FEN positions.

---

## Main GUI workflow

### Human vs Robot

```text
New Game
READY
human move on DGT
Python sends HUMAN_MOVE
GUI refreshes FEN and requests GET_BEST_MOVE
Python sends ROBOT_MOVE
GUI generates URScript
GUI sends URScript to UR3
UR3 sends ROBOT_DONE to Python
Python forwards ROBOT_DONE to GUI
GUI sends ROBOT_MOVE_DONE and GET_FEN
Python commits robot move and returns updated FEN
```

### Computer vs Computer

```text
New Game
READY
GUI requests GET_BEST_MOVE
Python sends ROBOT_MOVE
GUI sends URScript to UR3
UR3/Python/GUI complete ROBOT_DONE loop
GUI sends ROBOT_MOVE_DONE and GET_FEN
GUI requests next GET_BEST_MOVE
```

In computer-vs-computer mode, the generated robot script can skip returning to `Q_HOME` between moves by passing `useHome=false` to `executeRobotMove()`.

---

## Public UI components

These are declared in `properties (Access = public)` and are created by `createComponents()`.

| Component | Type | Purpose |
|---|---|---|
| `UIFigure` | `matlab.ui.Figure` | Main application window. |
| `GridLayout` | `matlab.ui.container.GridLayout` | Main layout dividing board and control panel. |
| `Panel` | `matlab.ui.container.Panel` | Right-hand control panel. |
| `GridLayout2` | `matlab.ui.container.GridLayout` | Layout inside control panel. |
| `BoardAxes` | `matlab.ui.control.UIAxes` | Chessboard visualization. |
| `StartServerButton` | `matlab.ui.control.Button` | Starts Python backend. |
| `ConnectButton` | `matlab.ui.control.Button` | Connects GUI to backend and UR3. |
| `NewGameButton` | `matlab.ui.control.Button` | Starts a new game. |
| `ReadyButton` | `matlab.ui.control.Button` | Starts/resumes after setup or recovery. |
| `SetFenPositionButton` | `matlab.ui.control.Button` | Opens FEN input dialog. |
| `DepthDropDown` | `matlab.ui.control.DropDown` | Selects Stockfish depth. |
| `HumanColorDropDown` | `matlab.ui.control.DropDown` | Selects human side/perspective. |
| `OperationModeDropDown` | `matlab.ui.control.DropDown` | Selects `Human vs Robot` or `Computer vs Computer`. |
| `ConnLamp` | `matlab.ui.control.Lamp` | Shows backend/DGT status. |
| `TurnLabel` | `matlab.ui.control.Label` | Displays side to move. |
| `MovesTable` | `matlab.ui.control.Table` | Displays move list with move number, White and Black columns. |
| `LogTextArea` | `matlab.ui.control.TextArea` | Displays protocol and diagnostic log. |
| `Label`, `Label_2` | `matlab.ui.control.Label` | Layout labels / spacing elements. |

---

## Private state properties

These are declared in `properties (Access = private)`.

| Property | Purpose |
|---|---|
| `Tcp` | `tcpclient` connection to Python backend on `127.0.0.1:5000`. |
| `RxTimer` | Timer that periodically reads incoming backend data. |
| `RxBuffer` | Partial-line buffer for backend TCP stream. |
| `Perspective` | Board display perspective: `white` or `black`. |
| `GameOver` | Prevents additional game actions after game end. |
| `MustPressReady` | Indicates setup/recovery is waiting for `READY`. |
| `PendingFen` | Custom FEN stored after Set FEN before READY. |
| `InRecovery` | Indicates illegal/failed-move recovery mode. |
| `MoveNo` | Current move number for the move table. |
| `PendingWhiteMove` | Temporary storage for white move table row management. |
| `LastFen` | Most recently received FEN. |
| `LastLegalFen` | Last known legal FEN used for recovery display. |
| `OperationMode` | Internal mode string: `human_vs_robot` or `computer_vs_computer`. |
| `PendingRobotMoveInfo` | Parsed struct from last `ROBOT_MOVE` message. |
| `PendingRobotUci` | Pending robot move UCI string. |
| `PendingRobotMoveType` | Pending robot move type. |
| `PendingRobotScript` | Generated URScript waiting to be sent or already sent. |
| `AutoSendRobotScript` | If true, generated robot script is immediately sent to UR3. |
| `AutoConfirmRobotDone` | Reserved/legacy flag for automatic completion confirmation. |
| `UR3client` | `tcpclient` connection to UR3 port `30002`. |
| `UR3Connected` | Boolean UR3 connection status. |
| `RobotBusy` | Prevents accepting a new robot move while previous movement is active. |
| `ResizeTimer` | Timer used to redraw board when axes size changes. |
| `LastBoardAxesSize` | Last observed board axes pixel size. |

---

# Private methods

## `connectUR3(app)`

**Purpose:** Opens TCP connection to UR3.

**Arguments:** none besides `app`.

**Returns:**

- `ok` — `true` if connection succeeded, `false` otherwise.

**Behavior:**

- Connects to `192.168.0.10:30002`.
- Clears old client object if one exists.
- Sets `UR3Connected`.
- Logs success or error.

**Used by:**

- `ConnectButtonPushed()` to connect early.
- `sendPendingRobotScript()` if not already connected.

---

## `generateRobotScript(app)`

**Purpose:** Converts the pending `ROBOT_MOVE` info into a complete URScript string.

**Arguments:** none.

**Returns:** none.

**Uses:**

- `robotRegions()`
- `robotPieceParams()`
- `robotMotionParams()`
- `robotBinParams()`
- `robotQueenParams()`
- `executeRobotMove()`

**Behavior:**

- Reads `app.PendingRobotMoveInfo`.
- Determines `boardRotated180` from `HumanColorDropDown`.
- Determines `useHome` from operation mode.
- Calls `executeRobotMove()`.
- Stores generated script in `app.PendingRobotScript`.
- Prints script to MATLAB Command Window for debugging.
- Logs script length.

---

## `sendPendingRobotScript(app)`

**Purpose:** Sends `app.PendingRobotScript` to UR3.

**Arguments:** none.

**Returns:** none.

**Behavior:**

- Verifies a script exists.
- Connects to UR3 if needed.
- Writes the script as `uint8` to the UR3 socket.
- Logs success or failure.
- Sets `UR3Connected=false` on send failure.

---

## `log(app, s)`

**Purpose:** Appends timestamped text to the GUI log.

**Arguments:**

- `s` — text/string message to log.

**Returns:** none.

**Side effects:**

- Adds line `[HH:mm:ss] message` to `LogTextArea`.
- Calls `drawnow limitrate`.

---

## `sendCmd(app, cmd)`

**Purpose:** Sends one newline-terminated command to the Python backend.

**Arguments:**

- `cmd` — command string without trailing newline.

**Returns:** none.

**Behavior:**

- If not connected, logs failed TX.
- Otherwise writes command to `app.Tcp` and logs `TX <cmd>`.

---

## `startRxTimer(app)`

**Purpose:** Starts or restarts the backend receive timer.

**Arguments:** none.

**Returns:** none.

**Behavior:**

- Stops/deletes existing `RxTimer` if valid.
- Creates a fixed-spacing timer with period `0.05` seconds.
- Timer callback calls `app.onRxTick()`.

---

## `onRxTick(app)`

**Purpose:** Reads incoming backend data from TCP and processes complete lines.

**Arguments:** none.

**Returns:** none.

**Behavior:**

- Checks `app.Tcp.NumBytesAvailable`.
- Reads available bytes.
- Appends to `RxBuffer`.
- Splits data by newline.
- Sends each complete line to `handleMessage()`.
- Logs stack trace and stops receive timer on exception.

---

## `onTimerError(app, e)`

**Purpose:** Handles errors raised by the receive timer.

**Arguments:**

- `e` — timer error event.

**Returns:** none.

**Behavior:**

- Logs error information in a MATLAB-version-tolerant way.

---

## `restartGame(app)`

**Purpose:** Restarts logical game after game-over dialog.

**Arguments:** none.

**Returns:** none.

**Behavior:**

- Clears game-over flag.
- Resets turn label.
- Sends `NEW_GAME` and `GET_FEN`.

---

## `shutdownAndClose(app)`

**Purpose:** Closes timers, backend connection and UI.

**Arguments:** none.

**Returns:** none.

**Behavior:**

- Stops/deletes `RxTimer`.
- Clears `Tcp` connection.
- Deletes UI figure.

---

## `isValidFenBasic(app, fen)`

**Purpose:** Performs basic validation of a FEN string before sending it to Python.

**Arguments:**

- `fen` — FEN string.

**Returns:**

- `ok` — boolean.

**Checks:**

- FEN has six fields.
- Side-to-move is `w` or `b`.
- Castling rights are valid.
- En passant field has valid square or `-`.
- Halfmove/fullmove fields are numeric.
- Board placement has eight ranks and exactly eight files per rank.
- Piece characters are valid.

**Limitations:**

- Does not fully validate chess legality; it prevents malformed input.

---

## `appendMoveToTable(app, side, uciMove)`

**Purpose:** Adds one move to the GUI move table.

**Arguments:**

- `side` — `"w"` or `"b"`.
- `uciMove` — move string such as `e2e4`.

**Returns:** none.

**Behavior:**

- White move starts a new row with current `MoveNo`.
- Black move fills the last row and increments `MoveNo`.
- Updates `MovesTable.Data`.

---

## `parseRobotMoveMessage(app, msg)`

**Purpose:** Parses key-value protocol messages such as `ROBOT_MOVE ...` or `ROBOT_MOVE_FAILED ...` into a MATLAB struct.

**Arguments:**

- `msg` — full message line.

**Returns:**

- `info` — struct with parsed fields.

**Behavior:**

- Splits message by spaces.
- Parses tokens of the form `key=value`.
- Converts keys with `matlab.lang.makeValidName()`.
- Adds defaults for standard robot-move fields such as `uci`, `type`, `piece`, `from`, `to`, `capture`, `promotion`, `ep`, `rook_from`, `rook_to`, `queen_available`.

---

## `isRobotToMove(app)`

**Purpose:** Determines whether the robot side is currently to move based on `LastFen` and human color selection.

**Arguments:** none.

**Returns:**

- `tf` — true if the side to move belongs to robot.

**Uses:**

- `fenSideToMove()`
- `HumanColorDropDown.Value`

---

## `handleMessage(app, msg)`

**Purpose:** Central dispatcher for all messages received from Python.

**Arguments:**

- `msg` — one complete newline-delimited backend message.

**Returns:** none.

**Handled messages:**

| Message | GUI behavior |
|---|---|
| `READY_OK` | Requests `GET_FEN`. |
| `FEN ...` | Updates board drawing, `LastFen`, `LastLegalFen`, and turn label. |
| `STATUS ...` | Logs backend status. |
| `BOARD_ERROR ...` | Logs board error and sets lamp orange. |
| `BOARD_OK` | Logs board connected and sets lamp green. |
| `HUMAN_MOVE ...` | Appends human move, refreshes FEN, requests robot response. |
| `ROBOT_MOVE ...` | Guards with `RobotBusy`, parses move, appends move table, generates and sends URScript. |
| `ROBOT_DONE` | Clears busy state, sends `ROBOT_MOVE_DONE`, refreshes FEN, and requests next move in computer-vs-computer mode. |
| `ROBOT_MOVE_FAILED ...` | Enters recovery mode and shows alert. |
| `PROMOTION_REQUIRED ...` | Shows promotion selection dialog and sends `PROMOTE`. |
| `GAME_OVER ...` | Shows game-over dialog and allows restart/exit. |
| `ERROR Illegal move...` / `ILLEGAL_MOVE` | Opens illegal move recovery dialog. |
| `ERROR ...` | Logs server error. |

**Important state changes:**

- Sets `RobotBusy=true` when a robot move is received.
- Sets `RobotBusy=false` on `ROBOT_DONE` or failure.
- Sets `InRecovery=true` and `MustPressReady=true` on illegal/failed physical move.

---

## `startResizeTimer(app)`

**Purpose:** Starts a timer that monitors the board axes size.

**Arguments:** none.

**Returns:** none.

**Behavior:**

- Stops/deletes previous resize timer if one exists.
- Creates a fixed-spacing timer with period `0.25` seconds.
- Timer callback calls `onResizeTimerTick()`.

**Reason:**

- Some MATLAB versions do not support `SizeChangedFcn` on `GridLayout` and do not execute `UIFigure.SizeChangedFcn` while `AutoResizeChildren` is on.

---

## `onResizeTimerTick(app)`

**Purpose:** Redraws the board when the axes size changes.

**Arguments:** none.

**Returns:** none.

**Behavior:**

- Reads `BoardAxes.Position` in pixels.
- Compares width/height to `LastBoardAxesSize`.
- If size changed significantly and `LastFen` exists, redraws board with `drawBoardFromFen()`.

---

# Callback methods

## `startupFcn(app)`

**Purpose:** Initializes app state after component creation.

**Arguments:** none.

**Returns:** none.

**Behavior:**

- Adds `matlab/` helper folder to MATLAB path.
- Initializes lamp, turn label, operation mode and default perspective.
- Starts resize timer.
- Maximizes the window where supported.

---

## `StartServerButtonPushed(app, event)`

**Purpose:** Starts the Python backend from the GUI.

**Arguments:**

- `event` — button event data.

**Returns:** none.

**Behavior:**

- Finds project folder with `fileparts(mfilename('fullpath'))`.
- Builds path to `python/brain_server.py`.
- Runs backend with Windows `start` and `cmd /c`.
- Logs full command.

**Current path logic after moving Python files:**

```matlab
here = fileparts(mfilename('fullpath'));
pyFolder = fullfile(here, "python");
pyFile = fullfile(pyFolder, "brain_server.py");
cmd = sprintf('start "" /min cmd /c "cd /d "%s" && python "%s""', pyFolder, pyFile);
```

This ensures `./stockfish/...exe` is resolved relative to the `python/` folder.

---

## `ConnectButtonPushed(app, event)`

**Purpose:** Connects GUI to backend and UR3.

**Arguments:**

- `event` — button event data.

**Returns:** none.

**Behavior:**

- Creates `tcpclient("127.0.0.1", 5000)`.
- Sets connection lamp.
- Starts receive timer.
- Sends `STATUS`.
- Calls `connectUR3()` early so first robot move is not delayed.

---

## `NewGameButtonPushed(app, event)`

**Purpose:** Starts a new game with current UI settings.

**Arguments:**

- `event` — button event data.

**Returns:** none.

**Behavior:**

- Clears log.
- Reads operation mode dropdown.
- Reads Stockfish depth and human color.
- Sets board perspective.
- Sends `CONFIG`, `NEW_GAME`, `GET_FEN`.
- Clears move table and pending robot fields.
- Resets `RobotBusy=false`.

---

## `ReadyButtonPushed(app, event)`

**Purpose:** Starts/resumes game operation after setup or recovery.

**Arguments:**

- `event` — button event data.

**Returns:** none.

**Modes of operation:**

1. **Recovery mode:** Clears recovery flags, sends `READY` and `GET_FEN`, then requests the next robot move if appropriate.
2. **Custom FEN mode:** Sends `NEW_GAME`, reapplies `DEBUG_SET_FEN`, sends `READY`, refreshes FEN, then requests first robot move if needed.
3. **Normal ready:** Sends `READY` and `GET_FEN`; in computer-vs-computer mode, requests first move.

---

## `UIFigureCloseRequest(app, event)`

**Purpose:** Cleans up resources when the user closes the GUI.

**Arguments:**

- `event` — close event data.

**Returns:** none.

**Behavior:**

- Logs closing message.
- Stops/deletes `RxTimer`.
- Stops/deletes `ResizeTimer`.
- Sends `QUIT` to Python backend.
- Clears backend TCP connection.
- Clears UR3 TCP connection.
- Deletes the app.

---

## `SetFenPositionButtonPushed(app, event)`

**Purpose:** Allows user to set a custom position by FEN.

**Arguments:**

- `event` — button event data.

**Returns:** none.

**Behavior:**

- Opens input dialog with default starting FEN.
- Validates using `isValidFenBasic()`.
- Sends `DEBUG_SET_FEN` and `GET_FEN`.
- Stores FEN in `PendingFen`.
- Sets `MustPressReady=true` so game starts only after operator confirms physical board is prepared.
- Clears move table and move counters.

---

## `createComponents(app)`

**Purpose:** Auto-generated App Designer component creation method.

**Arguments:** none.

**Returns:** none.

**Behavior:**

- Creates `UIFigure`, layouts, axes, buttons, dropdowns, labels, lamp, table and log text area.
- Assigns callbacks to buttons and close request.
- Shows the figure after setup.

**Note:**

- Usually edited through App Designer rather than manually.

---

## Constructor: `ChessRobotGUI`

**Purpose:** Creates and initializes the app.

**Arguments:** none.

**Returns:**

- `app` object if output requested.

**Behavior:**

- Calls `createComponents()`.
- Registers app.
- Runs `startupFcn()`.
- Clears local app variable if no output is requested.

---

## `delete(app)`

**Purpose:** Deletes the UI figure when the app object is deleted.

**Arguments:** none.

**Returns:** none.

---

# Recovery behavior

## Illegal human move

When Python sends `ERROR Illegal move` or `ILLEGAL_MOVE`, the GUI:

1. shows recovery dialog,
2. sets `InRecovery=true`,
3. sets `MustPressReady=true`,
4. redraws `LastLegalFen`,
5. waits for user to fix physical pieces and press `READY`.

## Failed robot move

When Python sends `ROBOT_MOVE_FAILED`, the GUI:

1. logs expected move, reason and optional board diff,
2. sets `RobotBusy=false`,
3. sets `InRecovery=true`,
4. sets `MustPressReady=true`,
5. clears pending robot script/info,
6. redraws the last legal FEN,
7. shows alert instructing user to fix pieces and press `READY`.

---

# Board display and resizing

The board is drawn by `drawBoardFromFen()` in `BoardAxes`.

Because the MATLAB version used in the project does not reliably support `SizeChangedFcn` for the figure/layout, the GUI uses:

- `ResizeTimer`,
- `LastBoardAxesSize`,
- `startResizeTimer()`,
- `onResizeTimerTick()`.

The resize timer checks the axes size and redraws the board when size changes. Piece glyph size is computed dynamically in `drawBoardFromFen()`.

---

# Safe GUI variant

`ChessRobotGUI_safe.mlapp` is intended for manual testing. It is useful when calibrating regions or validating new motion functions. Typical differences may include manual confirmation buttons such as:

- robot move done,
- human move done,
- send script to UR3.

The normal GUI removes/automates these actions through:

- automatic script sending,
- UR3 `ROBOT_DONE` notification,
- automatic `ROBOT_MOVE_DONE` command.

---

# Important implementation notes

## `RobotBusy`

`RobotBusy` prevents a second `ROBOT_MOVE` from being accepted while the previous robot action is still in progress.

It is set to `true` when a `ROBOT_MOVE` is accepted and reset to `false` on `ROBOT_DONE`, `ROBOT_MOVE_FAILED`, or recovery.

## `useHome`

The GUI passes `useHome` to `executeRobotMove()`:

- `true` for human-vs-robot, where returning home gives the human safer access to the board,
- `false` for computer-vs-computer, where the robot can continue from high points without returning home after every move.

## `LastLegalFen`

`LastLegalFen` is used as the visual recovery target. It stores the last backend FEN accepted by the GUI and is redrawn when the operator must restore the physical board after an illegal or failed move.

