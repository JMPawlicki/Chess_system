# MATLAB functions documentation

This document describes the MATLAB helper functions used by the chess robot GUI to convert symbolic chess actions into URScript commands for the UR3 robot.

The files are expected to be located in the `matlab/` folder. The GUI adds this folder to the MATLAB path during startup.

---

## Data flow overview

The MATLAB motion layer receives a parsed `ROBOT_MOVE` message from the Python backend. The message contains logical chess information such as:

- move type,
- source square,
- target square,
- moving piece,
- captured piece,
- en passant square,
- rook move for castling,
- promotion piece and piece color.

MATLAB then performs:

1. logical-to-physical square mapping if the physical board is rotated,
2. lookup of calibrated 2x2 board regions,
3. generation of pick/place poses,
4. optional capture/promotion/castling/en-passant decomposition,
5. URScript string generation,
6. addition of `ROBOT_DONE` socket notification.

---

## File groups

### Calibration and parameter files

| File | Purpose |
|---|---|
| `robotRegions.m` | Board calibration and 16 calibrated 2x2 regions. |
| `robotPieceParams.m` | Piece-specific Z levels and insertion scaling. |
| `robotMotionParams.m` | URScript motion speeds and home pose. |
| `robotBinParams.m` | Captured-piece bin location. |
| `robotQueenParams.m` | Spare queen storage slots. |
| `robotCommParams.m` | PC IP, port and socket name used by UR3 completion notification. |

### Data generation functions

| File | Purpose |
|---|---|
| `generateTransferData.m` | Generate pick-and-place data for moving a piece from one square to another. |
| `generatePickToBinData.m` | Generate pick data for removing a piece and dropping it into the bin. |
| `generateQueenPickData.m` | Generate pick data for spare queen storage. |
| `mapLogicalToPhysicalSquare.m` | Rotate logical chess square by 180 degrees when the physical board is reversed. |
| `chooseQueenSlot.m` | Select original or secondary spare queen slot based on piece color and board rotation. |

### URScript append functions

| File | Purpose |
|---|---|
| `appendMoveJ.m` | Append one `movej` command. |
| `appendMoveL.m` | Append one `movel` command. |
| `appendTransferToScript.m` | Append full pick-and-place sequence. |
| `appendPlaceFromMoveDataToScript.m` | Append only the place part of a transfer. |
| `appendPickToBinToScript.m` | Append pick-and-bin-drop sequence. |
| `appendQueenPickToScript.m` | Append spare queen pickup sequence. |
| `appendPromotionToScript.m` | Append promotion sequence without capture. |
| `appendPromotionCaptureToScript.m` | Append promotion sequence with capture. |
| `appendCastlingToScript.m` | Append castling sequence. |
| `appendEnPassantToScript.m` | Append en passant sequence. |
| `appendRobotDoneSignalToScript.m` | Append UR3 socket notification to Python backend. |
| `executeRobotMove.m` | Main dispatcher that builds a complete URScript program for one robot move. |

### GUI drawing helpers

| File | Purpose |
|---|---|
| `drawBoardFromFen.m` | Draw chessboard and pieces in GUI axes. |
| `fenToBoard.m` | Convert FEN placement field into an 8x8 board array. |
| `fenSideToMove.m` | Extract side-to-move from FEN. |
| `pieceGlyph.m` | Convert piece symbols to Unicode chess glyphs. |

---

# Parameter and calibration functions

## `robotRegions()`

**Signature:**

```matlab
[regions, squareCenter, boardCalib] = robotRegions()
```

**Purpose:** Returns the calibrated chessboard geometry and 16 robot motion regions.

**Arguments:** none.

**Returns:**

- `regions` — `1x16` struct array. Each element describes one 2x2 region of the board.
- `squareCenter` — function handle `squareCenter(fileIdx, rankIdx)` returning `[X Y Z]` in millimetres.
- `boardCalib` — struct containing corner-square calibration points.

**Important fields in each `regions(k)`:**

| Field | Meaning |
|---|---|
| `name` | Region name, e.g. `R1`. |
| `baseSquare` | Reference square for region offsets. |
| `approachDir` | Human-readable approach direction metadata. |
| `Q_deg` | Joint-space high configuration in degrees. |
| `Q_HIGH` | Usually derived from `Q_deg` in radians. |
| `P_APPROACH_HIGH` | Safe Cartesian pose above region, XYZ in mm. |
| `P_APPROACH_MID` | Optional intermediate approach pose. |
| `P_APPROACH_LOW` | Low approach pose near the piece. |
| `P_INSERT_FLAT` | Inserted pose before locking under the piece. |
| `P_ROTATE_LOCK` | Rotated/locked pose for lifting. |
| `P_LIFT_LOCKED` | Lifted pose while holding piece. |

**Notes:**

- The board is divided into 16 regions, each covering a 2x2 area.
- Cartesian points store XYZ in millimetres and orientation as axis-angle radians.
- The helper `squareCenter` uses bilinear interpolation from calibrated board corners.
- Some regions contain `hasApproachMid = true`; append functions use the mid point when it exists.

---

## `robotPieceParams()`

**Signature:**

```matlab
params = robotPieceParams()
```

**Purpose:** Defines piece-specific grasping parameters.

**Arguments:** none.

**Returns:**

- `params` — struct containing piece height and insertion data.

**Main fields:**

| Field | Meaning |
|---|---|
| `basePiece` | Reference piece for calibration, currently `"N"`. |
| `pieceZ` | Z height levels in millimetres for each piece type. |
| `pieceInsertXY` | Reference insertion offsets measured on a reference square. |
| `pieceInsertLen` | Euclidean lengths of insertion vectors. |
| `usePieceZCorrection` | Enables Z correction relative to `basePiece`. |
| `usePieceInsertScale` | Enables insert-vector length scaling. |
| `allowedPieces` | Allowed piece identifiers: `P,N,B,R,Q,K`. |

**Practical meaning:**

- Region trajectories are calibrated around the reference piece.
- For another piece type, Z poses are shifted by `pieceZ.(piece) - pieceZ.(basePiece)`.
- Insertion distance is scaled by the ratio of reference insertion lengths.

---

## `robotMotionParams()`

**Signature:**

```matlab
motionParams = robotMotionParams()
```

**Purpose:** Returns robot motion speed parameters and home pose.

**Arguments:** none.

**Returns:**

- `motionParams` — struct used by all URScript append functions.

**Fields:**

| Field | Meaning |
|---|---|
| `a_joint` | `movej` acceleration in URScript joint units. |
| `v_joint` | `movej` velocity in URScript joint units. |
| `a_lin` | `movel` Cartesian acceleration. |
| `v_lin` | `movel` Cartesian velocity. |
| `Q_HOME_deg` | Home joint pose in degrees. |
| `Q_HOME` | Home joint pose in radians. |

**Notes:**

- `movej` velocity is in rad/s and acceleration is in rad/s².
- `movel` velocity is in m/s and acceleration is in m/s².

---

## `robotBinParams()`

**Signature:**

```matlab
binParams = robotBinParams()
```

**Purpose:** Returns the disposal bin joint and Cartesian poses used for captured pieces.

**Arguments:** none.

**Returns:**

- `binParams` — struct with bin high pose and drop pose.

**Fields:**

| Field | Meaning |
|---|---|
| `Q_BIN_HIGH_deg` | Joint-space safe pose above/near the bin in degrees. |
| `Q_BIN_HIGH` | Same pose in radians. |
| `P_BIN_DROP` | Cartesian drop pose, XYZ in mm, orientation in radians. |
| `Q_HIGH`, `P_DROP` | Aliases for compatibility with older scripts. |

---

## `robotQueenParams()`

**Signature:**

```matlab
queenParams = robotQueenParams()
```

**Purpose:** Returns calibrated spare queen storage poses.

**Arguments:** none.

**Returns:**

- `queenParams` — struct containing two spare queen slots.

**Fields:**

| Field | Meaning |
|---|---|
| `defaultSlot` | Fallback slot name, normally `"original"`. |
| `slots.original` | Original spare queen storage point. |
| `slots.secondary` | Second spare queen storage point. |

Each slot contains:

- `Q_QUEEN_HIGH_deg`,
- `Q_QUEEN_HIGH`,
- `P_QUEEN_APPROACH_HIGH`,
- `P_QUEEN_APPROACH_LOW`,
- `P_QUEEN_INSERT_FLAT`,
- `P_QUEEN_LOCK`,
- `P_QUEEN_LIFT_LOCKED`,
- `P_QUEEN_EXIT_HIGH`.

**Notes:**

- `chooseQueenSlot()` decides which physical slot to use.
- The slot names are physical (`original`, `secondary`), not chess colors.

---

## `robotCommParams()`

**Signature:**

```matlab
commParams = robotCommParams()
```

**Purpose:** Returns communication parameters used by UR3 to notify the Python backend that robot motion is complete.

**Arguments:** none.

**Returns:**

- `commParams` — struct.

**Fields:**

| Field | Meaning |
|---|---|
| `pcIp` | IP address of the PC on the UR3 network. This must match the address reachable from the robot controller. |
| `robotDonePort` | Port listened to by Python for UR3 `ROBOT_DONE`. |
| `socketName` | URScript socket name. |

---

# Data generation functions

## `generateTransferData(fromSquare, toSquare, movingPiece, regions, squareCenter, pieceParams)`

**Purpose:** Generates all poses and joint targets required for moving one piece from one square to another.

**Arguments:**

| Argument | Meaning |
|---|---|
| `fromSquare` | Source square string such as `"E2"`. |
| `toSquare` | Destination square string such as `"E4"`. |
| `movingPiece` | Piece type: `P`, `N`, `B`, `R`, `Q`, or `K`. |
| `regions` | Region database returned by `robotRegions()`. |
| `squareCenter` | Interpolation function returned by `robotRegions()`. |
| `pieceParams` | Piece-specific parameters from `robotPieceParams()`. |

**Returns:**

- `moveData` — struct containing generated FROM and TO poses.

**Main output fields:**

- `Q_FROM_HIGH`, `Q_TO_HIGH`,
- `P_FROM_APPROACH_HIGH`, `P_FROM_APPROACH_MID`, `P_FROM_APPROACH_LOW`,
- `P_FROM_INSERT_FLAT`, `P_FROM_ROTATE_LOCK`, `P_FROM_LIFT_LOCKED`, `P_FROM_EXIT_HIGH`,
- `P_TO_APPROACH_HIGH`, `P_TO_APPROACH_MID`, `P_TO_APPROACH_LOW`,
- `P_TO_INSERT_FLAT`, `P_TO_ROTATE_LOCK`, `P_TO_LIFT_LOCKED`, `P_TO_EXIT_HIGH`,
- debug metadata such as region names, deltas, Z corrections and insert scale.

**Behavior:**

- Determines FROM and TO 2x2 regions from square names.
- Computes square offset relative to each region's base square.
- Applies piece Z correction if enabled.
- Applies insert vector scaling if enabled.
- Converts XYZ from millimetres to metres for URScript.

### Local helper: `squareToIndex(squareName)`

Converts square name to zero-based file/rank indices.

### Local helper: `regionIdx = squareToRegionIndex(fileIdx, rankIdx)`

Maps file/rank index to one of the 16 board regions.

### Local helper: `xyzMmToM(p)`

Converts only `p(1:3)` from millimetres to metres.

### Local helper: `validatePiece(piece, pieceParams)`

Checks that a piece code is allowed and present in `pieceParams`.

---

## `generatePickToBinData(squareName, pieceType, regions, squareCenter, pieceParams)`

**Purpose:** Generates pick data for removing a piece from a board square before dropping it into the captured-piece bin.

**Arguments:**

| Argument | Meaning |
|---|---|
| `squareName` | Square to remove a piece from. |
| `pieceType` | Piece type to pick. |
| `regions` | Region database. |
| `squareCenter` | Board interpolation function. |
| `pieceParams` | Piece-specific parameters. |

**Returns:**

- `pickData` — struct with all poses required for picking the piece.

**Main fields:**

- `Q_HIGH`,
- `P_APPROACH_HIGH`, `P_APPROACH_MID`, `P_APPROACH_LOW`,
- `P_INSERT_FLAT`, `P_ROTATE_LOCK`, `P_LIFT_LOCKED`, `P_EXIT_HIGH`,
- metadata such as region name, square name, piece type, Z delta and insert scale.

**Used by:**

- captures,
- en passant captured pawn removal,
- promotion pawn removal,
- promotion-capture captured piece removal.

### Local helpers

Same style as `generateTransferData`: square parsing, region selection, unit conversion and piece validation.

---

## `generateQueenPickData(queenParams, queenSlot)`

**Purpose:** Converts one spare queen storage slot into the standard pick-data format expected by `appendQueenPickToScript()`.

**Arguments:**

| Argument | Meaning |
|---|---|
| `queenParams` | Struct from `robotQueenParams()`. |
| `queenSlot` | Slot name: `"original"` or `"secondary"`. Optional/fallback to `queenParams.defaultSlot`. |

**Returns:**

- `queenPickData` — struct in standard pick format.

**Main fields:**

- `type = "queen_pick"`,
- `slot`,
- `Q_HIGH`,
- `P_APPROACH_HIGH`, `P_APPROACH_LOW`, `P_INSERT_FLAT`, `P_LOCK`, `P_LIFT_LOCKED`, `P_EXIT_HIGH`.

**Notes:**

- This function is an adapter between storage-specific field names such as `P_QUEEN_LOCK` and generic motion field names such as `P_LOCK`.

### Local helper: `xyzMmToM(p)`

Converts XYZ coordinates from millimetres to metres.

---

## `mapLogicalToPhysicalSquare(sqIn, boardRotated180)`

**Purpose:** Maps a logical chess square to the corresponding physical square when the board is rotated by 180 degrees.

**Arguments:**

| Argument | Meaning |
|---|---|
| `sqIn` | Logical square string such as `"E2"`. |
| `boardRotated180` | Boolean flag indicating physical board rotation. |

**Returns:**

- `sqOut` — physical square string.

**Behavior:**

- If `boardRotated180 == false`, returns input square unchanged.
- If true, maps file and rank through a 180° rotation, e.g. `A1 -> H8`.

---

## `chooseQueenSlot(pieceColor, boardRotated180)`

**Purpose:** Chooses which physical spare queen slot should be used for promotion.

**Arguments:**

| Argument | Meaning |
|---|---|
| `pieceColor` | Color of the promoting pawn from Python: `white` or `black`. |
| `boardRotated180` | Whether the physical board is rotated. |

**Returns:**

- `queenSlot` — `"original"` or `"secondary"`.

**Logic:**

- In normal setup, original slot belongs to the robot-side black queen.
- In rotated setup, original slot belongs to the robot-side white queen.
- Secondary slot is used by the opposite color.

---

# URScript primitive append functions

## `appendMoveJ(script, q, a_joint, v_joint)`

**Purpose:** Appends one URScript `movej` command.

**Arguments:**

| Argument | Meaning |
|---|---|
| `script` | Existing URScript string. |
| `q` | 6-element joint vector in radians. |
| `a_joint` | Joint acceleration. |
| `v_joint` | Joint velocity. |

**Returns:**

- Updated `script`.

**Validation:**

- Throws an error if `q` does not have six elements.

---

## `appendMoveL(script, p, a_lin, v_lin)`

**Purpose:** Appends one URScript `movel` command and a short settling sleep.

**Arguments:**

| Argument | Meaning |
|---|---|
| `script` | Existing URScript string. |
| `p` | 6-element pose `[x y z rx ry rz]`, XYZ in metres. |
| `a_lin` | Cartesian acceleration. |
| `v_lin` | Cartesian velocity. |

**Returns:**

- Updated `script`.

**Validation:**

- Throws an error if `p` does not have six elements.

---

# Motion sequence append functions

## `appendTransferToScript(script, moveData, motionParams)`

**Purpose:** Appends a full pick-and-place sequence for moving a piece from one square to another.

**Arguments:**

| Argument | Meaning |
|---|---|
| `script` | Existing URScript string. |
| `moveData` | Struct from `generateTransferData()`. |
| `motionParams` | Struct from `robotMotionParams()`. |

**Returns:**

- Updated `script`.

**Sequence:**

1. Move to FROM region high.
2. Approach high / optional mid / low.
3. Insert forks.
4. Rotate to lock piece.
5. Lift locked piece.
6. Exit high.
7. Move to TO region high.
8. Place by reversing lock/insert motion.
9. Exit via optional mid and high.
10. Return to TO region high.

---

## `appendPlaceFromMoveDataToScript(script, moveData, motionParams)`

**Purpose:** Appends only the placement part of a transfer.

**Arguments:**

| Argument | Meaning |
|---|---|
| `script` | Existing URScript string. |
| `moveData` | Struct containing TO-side fields. |
| `motionParams` | Motion parameters. |

**Returns:**

- Updated `script`.

**Used by:**

- promotion after the spare queen has already been picked from storage.

---

## `appendPickToBinToScript(script, pickData, binParams, motionParams)`

**Purpose:** Appends a sequence that picks a piece from the board and drops it into the captured-piece bin.

**Arguments:**

| Argument | Meaning |
|---|---|
| `script` | Existing URScript string. |
| `pickData` | Struct from `generatePickToBinData()`. |
| `binParams` | Struct from `robotBinParams()`. |
| `motionParams` | Motion parameters. |

**Returns:**

- Updated `script`.

**Sequence:**

1. Go to piece region high.
2. Pick piece using approach/insert/lock/lift sequence.
3. Return to piece region high.
4. Move to bin high.
5. Move to bin drop pose and release/drop piece.
6. Return to bin high.

---

## `appendQueenPickToScript(script, queenPickData, motionParams)`

**Purpose:** Appends a sequence that picks a spare queen from a selected storage slot.

**Arguments:**

| Argument | Meaning |
|---|---|
| `script` | Existing URScript string. |
| `queenPickData` | Struct from `generateQueenPickData()`. |
| `motionParams` | Motion parameters. |

**Returns:**

- Updated `script`.

**Sequence:**

1. Move to queen slot high configuration.
2. Approach queen storage.
3. Insert forks.
4. Lock under queen.
5. Lift queen.
6. Exit high.

---

## `appendPromotionToScript(script, fromSquare, toSquare, regions, squareCenter, pieceParams, queenParams, binParams, motionParams, queenSlot)`

**Purpose:** Appends a full promotion sequence without capture.

**Arguments:**

| Argument | Meaning |
|---|---|
| `fromSquare` | Pawn source square. |
| `toSquare` | Promotion destination square. |
| `regions`, `squareCenter`, `pieceParams` | Board/piece calibration data. |
| `queenParams` | Spare queen storage data. |
| `binParams` | Disposal bin data. |
| `motionParams` | Motion parameters. |
| `queenSlot` | `original` or `secondary`. Optional fallback to default slot. |

**Returns:**

- Updated `script`.

**Sequence:**

1. Pick pawn from `fromSquare`.
2. Drop pawn into bin.
3. Pick spare queen from `queenSlot`.
4. Place queen on `toSquare`.

---

## `appendPromotionCaptureToScript(script, fromSquare, toSquare, capturedPiece, regions, squareCenter, pieceParams, queenParams, binParams, motionParams, queenSlot)`

**Purpose:** Appends a promotion-with-capture sequence.

**Arguments:**

| Argument | Meaning |
|---|---|
| `fromSquare` | Promoting pawn source square. |
| `toSquare` | Destination square containing captured piece. |
| `capturedPiece` | Captured piece type. |
| `regions`, `squareCenter`, `pieceParams` | Board/piece calibration data. |
| `queenParams` | Spare queen storage data. |
| `binParams` | Disposal bin data. |
| `motionParams` | Motion parameters. |
| `queenSlot` | `original` or `secondary`. |

**Returns:**

- Updated `script`.

**Sequence:**

1. Remove captured piece from `toSquare` to bin.
2. Remove promoting pawn from `fromSquare` to bin.
3. Pick spare queen from selected slot.
4. Place queen on `toSquare`.

---

## `appendCastlingToScript(script, kingFromSquare, kingToSquare, rookFromSquare, rookToSquare, regions, squareCenter, pieceParams, motionParams)`

**Purpose:** Appends a castling sequence.

**Arguments:**

| Argument | Meaning |
|---|---|
| `kingFromSquare`, `kingToSquare` | King source and destination. |
| `rookFromSquare`, `rookToSquare` | Rook source and destination. |
| `regions`, `squareCenter`, `pieceParams` | Board/piece calibration data. |
| `motionParams` | Motion parameters. |

**Returns:**

- Updated `script`.

**Behavior:**

- Executes castling as two standard transfers: king first, rook second.

---

## `appendEnPassantToScript(script, fromSquare, toSquare, capturedSquare, regions, squareCenter, pieceParams, binParams, motionParams)`

**Purpose:** Appends en passant sequence.

**Arguments:**

| Argument | Meaning |
|---|---|
| `fromSquare` | Moving pawn source. |
| `toSquare` | Moving pawn destination. |
| `capturedSquare` | Square of pawn captured en passant. |
| `regions`, `squareCenter`, `pieceParams` | Board/piece calibration data. |
| `binParams` | Disposal bin data. |
| `motionParams` | Motion parameters. |

**Returns:**

- Updated `script`.

**Sequence:**

1. Remove captured pawn from `capturedSquare` to bin.
2. Transfer moving pawn from `fromSquare` to `toSquare`.

---

## `appendRobotDoneSignalToScript(script, commParams)`

**Purpose:** Appends URScript socket commands that notify the Python backend after a robot move.

**Arguments:**

| Argument | Meaning |
|---|---|
| `script` | Existing URScript string. |
| `commParams` | Struct from `robotCommParams()`. |

**Returns:**

- Updated `script`.

**Generated URScript:**

- `socket_open(pcIp, robotDonePort, socketName)`
- `socket_send_string("ROBOT_DONE", socketName)`
- `socket_close(socketName)`

**Notes:**

- The current implementation sends `ROBOT_DONE` without literal `\n` because the Python listener expects this normalized message.

---

# Main dispatcher

## `executeRobotMove(info, boardRotated180, regions, squareCenter, pieceParams, motionParams, binParams, queenParams, useHome)`

**Purpose:** Generates a complete executable URScript program for one robot chess move.

**Arguments:**

| Argument | Meaning |
|---|---|
| `info` | Parsed `ROBOT_MOVE` struct from GUI/Python. |
| `boardRotated180` | Whether to rotate logical squares to physical squares. |
| `regions` | Region calibration database. |
| `squareCenter` | Square interpolation function. |
| `pieceParams` | Piece parameters. |
| `motionParams` | Motion parameters. |
| `binParams` | Disposal bin parameters. |
| `queenParams` | Spare queen slot parameters. |
| `useHome` | If true, script includes home pose at start/end. If false, useful for computer-vs-computer continuous play. |

**Returns:**

- `script` — full URScript program string.

**Behavior:**

- Reads `info.type` and dispatches to the correct motion sequence.
- Maps all logical squares to physical squares when the board is rotated.
- Handles move types:
  - `normal`,
  - `capture`,
  - `en_passant`,
  - `castle_kingside`,
  - `castle_queenside`,
  - `promotion`,
  - `promotion_capture`.
- Selects correct spare queen slot using `chooseQueenSlot()`.
- Appends `ROBOT_DONE` signal near the end of the proper physical action.

### Local helper: `getInfoString(info, fieldName, defaultValue)`

Safely extracts a string field from the parsed robot-move info struct.

### Local helper: `normalizePieceName(piece)`

Normalizes piece identifiers to `P`, `N`, `B`, `R`, `Q`, or `K`.

---

---

## Motion blending note

URScript blending with the `r` parameter was considered as a possible way to smooth transitions. In testing, however, blending caused the TCP/tool orientation to change before the calibrated high pose was reached. Because the passive fork gripper depends on a stable orientation while carrying a chess piece, blending was not included in the final motion sequence. The final helper functions therefore generate explicit `movej` and `movel` commands without blended corner cutting.

# GUI board drawing helpers

## `drawBoardFromFen(ax, fen, perspective)`

**Purpose:** Draws the chessboard and Unicode chess pieces on a MATLAB UI axes.

**Arguments:**

| Argument | Meaning |
|---|---|
| `ax` | Target UI axes. |
| `fen` | Full FEN string. |
| `perspective` | `white` or `black`, selecting which side appears at bottom. |

**Returns:** none.

**Behavior:**

- Clears axes.
- Draws 8x8 board rectangles.
- Uses `fenToBoard()` and `pieceGlyph()`.
- Draws pieces at square centers.
- Uses dynamic `boardPieceFontSize()` to scale piece glyphs with window size.

### Local helper: `boardPieceFontSize(ax)`

Computes piece text font size based on axes dimensions in pixels.

---

## `fenToBoard(fen)`

**Purpose:** Converts FEN board placement into an 8x8 character array.

**Arguments:**

- `fen` — full FEN or at least placement field.

**Returns:**

- `board` — 8x8 matrix with piece symbols or `.`.

---

## `fenSideToMove(fen)`

**Purpose:** Extracts whose turn it is from FEN.

**Arguments:**

- `fen` — full FEN string.

**Returns:**

- `"w"`, `"b"`, or fallback/unknown depending on invalid input handling.

---

## `pieceGlyph(p)`

**Purpose:** Converts piece symbols to Unicode chess glyphs.

**Arguments:**

- `p` — one-character piece symbol, e.g. `P`, `n`, `k`.

**Returns:**

- Unicode chess glyph string, or empty string for unknown input.

---

## Typical dependency graph

```text
ChessRobotGUI
  -> executeRobotMove
      -> mapLogicalToPhysicalSquare
      -> generateTransferData
      -> generatePickToBinData
      -> generateQueenPickData
      -> chooseQueenSlot
      -> appendTransferToScript
      -> appendPickToBinToScript
      -> appendQueenPickToScript
      -> appendPromotionToScript
      -> appendPromotionCaptureToScript
      -> appendCastlingToScript
      -> appendEnPassantToScript
      -> appendRobotDoneSignalToScript
          -> robotCommParams
  -> drawBoardFromFen
      -> fenToBoard
      -> pieceGlyph
```

