# Chess Robot System User Guide

This document describes the basic procedure for configuring, starting and operating the chess robot system. The system consists of a DGT electronic chessboard, a Python backend, a MATLAB GUI, the Stockfish chess engine and a UR3 robot.

---
## DGT e-Board Driver

Before preparing the workstation make sure that the DGT e-Board Driver is installed on the computer

---

## 1. Preparing the workstation

Before starting the software, prepare the physical setup.

1. Place the DGT chessboard in its calibrated position relative to the UR3 robot.
2. Place all chess pieces on the starting squares or according to the selected test position.
3. Make sure that the custom fork gripper is mounted and does not collide with the board or pieces.
4. Make sure that the computer, UR3 robot and DGT board are connected.
5. Check that the UR3 robot is ready to receive TCP/IP commands.
6. Close any application that may block the DGT serial port, such as DGT Live Chess.

---

## 2. Configuring IP addresses, ports and paths

Before the first run, check the communication settings used by the project. The default values may need to be changed after moving the system to another computer or network.

### 2.1. Python backend configuration

In the file:

```text
python/brain_server.py
```

check the main communication parameters:

```text
HOST = 127.0.0.1
PORT = 5000
ROBOT_DONE_HOST = 0.0.0.0
ROBOT_DONE_PORT = 5001
SERIAL_PORT = COM5
SERIAL_BAUD = 38400
```

Parameter meaning:

| Parameter | Meaning |
|---|---|
| `HOST` / `PORT` | Address and port of the TCP server used by MATLAB. |
| `ROBOT_DONE_HOST` / `ROBOT_DONE_PORT` | Address and port used to receive the robot completion signal. |
| `SERIAL_PORT` | COM port used by the DGT board. |
| `SERIAL_BAUD` | Serial communication speed for the DGT board. |

If the DGT board is detected on another COM port, update `SERIAL_PORT`, for example from `COM5` to `COM6`.

The Stockfish path should point to the executable file inside:

```text
python/stockfish/
```

If the Stockfish executable has a different name, update the corresponding variable in the Python backend.

### 2.2. MATLAB application configuration

In the MATLAB application, check the addresses used to connect to the backend and the robot.

The MATLAB → Python connection should point to:

```text
127.0.0.1:5000
```

when the Python backend is running on the same computer as MATLAB.

The MATLAB → UR3 connection should point to the robot IP address and UR controller port:

```text
192.168.0.10:30002
```

If the robot uses another IP address, update it in the GUI function `connectUR3()`.

### 2.3. ROBOT_DONE signal configuration

After finishing a motion sequence, the UR3 robot sends:

```text
ROBOT_DONE
```

to the computer running the Python backend. The parameters for this connection are defined in:

```text
matlab/robotCommParams.m
```

Check the following values:

| Parameter | Meaning |
|---|---|
| `pcIp` | IP address of the PC visible from the UR3 network. |
| `robotDonePort` | Port where Python receives `ROBOT_DONE`, default `5001`. |
| `socketName` | Socket name used in URScript. |

The `pcIp` address must be the address of the computer on the same network as the robot. It should not be `127.0.0.1`, because from the robot perspective that would refer to the robot itself, not the PC.

### 2.4. Network check

Before testing, verify that:

1. The computer and UR3 are in the same subnet.
2. The computer can ping the robot.
3. The robot can connect to the computer on port `5001`.
4. MATLAB can access the robot on port `30002`.
5. Windows Firewall does not block incoming connections on port `5001`.

---

## 3. Starting the MATLAB application

1. Open the project in MATLAB.
2. Start the GUI application:

   ```matlab
   ChessRobotGUI
   ```

3. The GUI window should appear with the chessboard view, control panel, move table and log window.

---

## 4. Starting the Python backend

1. In the MATLAB GUI, press **Start Server**.
2. The application starts:

   ```text
   python/brain_server.py
   ```

3. The backend starts:
   - the MATLAB TCP server on port `5000`,
   - the DGT board serial interface,
   - the `ROBOT_DONE` listener on port `5001`,
   - the Stockfish integration.

4. If the backend starts correctly, the MATLAB log window displays the server start message.

---

## 5. Connecting to the backend and UR3

1. Press **Connect**.
2. MATLAB connects to the Python backend at:

   ```text
   127.0.0.1:5000
   ```

3. MATLAB also attempts to connect to the UR3 robot at:

   ```text
   192.168.0.10:30002
   ```

4. MATLAB sends a `STATUS` command to check backend and DGT board status.
5. If the DGT board is connected correctly, the log displays `BOARD_OK`.
6. If the DGT board is unavailable, the log displays `BOARD_ERROR`.

---

## 6. Game configuration

Before starting a game, configure the operating parameters.

1. Select the operating mode:
   - **Human vs Robot** — the human plays on the DGT board and the robot responds with engine moves.
   - **Computer vs Computer** — Stockfish controls both sides and the robot physically executes all moves.

2. Select the human player color:
   - `white`
   - `black`

3. Select the Stockfish depth.

4. Press **New Game**.

After pressing **New Game**, the GUI:
- clears the log,
- resets the move table,
- sends the configuration to the backend,
- initializes a new game,
- requests the current FEN.

---

## 7. Starting the game

1. Check the physical position of all pieces on the DGT board.
2. Press **READY**.
3. The Python backend enters the active game state.
4. Depending on the selected mode:
   - in **Human vs Robot**, the system waits for a human move or requests a robot move if the robot is to move,
   - in **Computer vs Computer**, the system automatically requests the first engine move.

---

## 8. Player behavior during operation

The following rules describe how the human should interact with the physical system. They do not replace the standard rules of chess; they only define how to operate the DGT board and robot setup.

### 8.1. Making a human move

1. Make the move directly on the DGT board.
2. Lift the piece from the source square and place it on the target square.
3. Do not slide the piece through multiple squares across the board surface.
4. Do not adjust several pieces at the same time while making one move.
5. After making a move, wait briefly until the system reads and accepts the change.
6. Do not make another move until the robot finishes its move and the system returns to the human turn.

### 8.2. Captures and special moves

1. For a capture, remove the captured piece from the destination square and then place the moving piece on that square.
2. For castling, move both the king and rook according to chess rules, treating both piece movements as one action.
3. For en passant, remove the captured pawn from the correct square and move the capturing pawn to its destination square.
4. For promotion, move the pawn to the last rank and select the promotion piece in the GUI if requested.

### 8.3. During robot movement

1. Do not touch the chessboard, pieces or gripper while the robot is moving.
2. Do not adjust pieces during UR3 motion.
3. Wait until the robot completes the move and the GUI updates.
4. If the robot drops a piece or displaces another piece, do not make the next move. Wait for the system message or stop the process and enter recovery.

### 8.4. Correcting the position

1. Pieces should only be corrected when the system is stopped, waiting for `READY`, or showing a recovery message.
2. Correct the physical board according to the position displayed in the GUI.
3. After correcting the position, press **READY**.
4. Do not press **READY** if the physical board does not match the GUI position.

---

## 9. Human vs Robot workflow

1. The human makes a move on the physical DGT board.
2. The Python backend reads the DGT events and reconstructs the move.
3. The move is validated using `python-chess`.
4. If the move is legal, the backend sends MATLAB:

   ```text
   HUMAN_MOVE <uci>
   ```

5. MATLAB updates the move table and board view.
6. MATLAB requests the engine response:

   ```text
   GET_BEST_MOVE
   ```

7. Python asks Stockfish for a move and sends MATLAB a full robot action description:

   ```text
   ROBOT_MOVE ...
   ```

8. MATLAB generates the URScript program.
9. MATLAB sends the URScript to the UR3 robot.
10. The robot executes the physical move on the chessboard.
11. After completing the move, the robot sends:

   ```text
   ROBOT_DONE
   ```

12. MATLAB confirms completion to the backend:

   ```text
   ROBOT_MOVE_DONE
   ```

13. The backend accepts the move, updates the game state and returns the updated FEN.

---

## 10. Computer vs Computer workflow

1. After **READY**, MATLAB sends:

   ```text
   GET_BEST_MOVE
   ```

2. Python selects a Stockfish move.
3. The backend sends a `ROBOT_MOVE` message to MATLAB.
4. MATLAB generates URScript and sends it to UR3.
5. The robot executes the move.
6. After the motion is complete, the robot sends `ROBOT_DONE`.
7. MATLAB sends `ROBOT_MOVE_DONE` and requests the updated FEN.
8. MATLAB automatically requests the next engine move.

In this mode, the robot does not need to return to the home position after every move, because no human interaction with the board is required between robot moves.

---

## 11. Starting from a custom FEN position

1. Press **Set Fen Position**.
2. Enter a valid FEN string.
3. The GUI checks the basic FEN format.
4. Physically arrange the pieces on the DGT board according to the entered FEN.
5. Press **READY** to start from the custom position.

---

## 12. Promotion handling

For a human promotion, the backend sends:

```text
PROMOTION_REQUIRED <uci_base>
```

MATLAB displays a promotion selection dialog:
- Queen,
- Rook,
- Bishop,
- Knight.

After selection, MATLAB sends the `PROMOTE` command.

For robot moves, promotions are forced to queens. The system tracks spare queen availability separately for white and black.

---

## 13. Error handling and recovery

The system may enter recovery mode when:
- the human makes an illegal move,
- the physical board state after a robot move does not match the expected state,
- the DGT sequence is ambiguous,
- the robot movement fails.

When an error occurs:
1. The GUI displays an error message.
2. Automatic move execution is stopped.
3. The GUI displays the last valid position.
4. The user must correct the physical board.
5. After correcting the board, press **READY**.
6. The system resumes from the last valid state.

---

## 14. Game end

The game may end due to:
- checkmate,
- stalemate,
- draw,
- manual application shutdown.

After receiving `GAME_OVER`, the GUI displays a dialog allowing the user to:
- restart the game,
- exit the application.

---

## 15. Safe shutdown

To shut down the system:

1. Wait until the robot finishes the current motion.
2. Close the MATLAB GUI.
3. The GUI sends the backend:

   ```text
   QUIT
   ```

4. The backend replies with `BYE` and closes the process.
5. TCP connections to the backend and UR3 are closed.
6. If necessary, stop the robot from the PolyScope panel.

---

## 16. Common problems

### DGT board is not connected

Possible causes:
- incorrect COM port,
- DGT Live Chess is blocking the port,
- USB cable is disconnected,
- backend cannot access the serial port.

### UR3 connection failed

Possible causes:
- robot is powered off,
- robot has a different IP address,
- computer is not in the same network,
- computer has a different IP address, than the one in files,
- port `30002` is unavailable,
- robot is not ready to receive commands.

### Robot move failed

This means that the physical board state after the robot move does not match the expected state. Correct the pieces according to the GUI and press **READY**.

---

## 17. Safety notes

- Do not place your hands in the robot workspace while the robot is moving.
- Before pressing **READY**, make sure that the physical board is set correctly.
- During tests, use low speeds and supervise the robot.
- If the robot moves incorrectly, use the emergency stop or stop the robot from the teach pendant.
