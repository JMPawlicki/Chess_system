%% UNIVERSAL TEST - all 2x2 chessboard regions
clear; clc;

ip = '192.168.0.10';
port = 30002;

UR3client = tcpclient(ip, port, "Timeout", 3);
disp("Połączono z UR3.");

%% -------------------------
%  Select test
% --------------------------

% regionName = "R6";
% targetSquare = "D3";

%% -------------------------
%  Motion parameters
% --------------------------

a_joint = 0.20;
v_joint = 0.40;

a_lin = 0.10;
v_lin = 0.20;

%% -------------------------
%  Board calibration [mm]
% --------------------------
% Kalibracja z czterech zewnętrznych narożników SIATKI GRY 8x8,
% a nie z narożników ramki planszy.
%
% Indeksy pól:
% fileIdx: A=0 ... H=7
% rankIdx: 1=0 ... 8=7
%
% Ponieważ mierzone są narożniki siatki, środek pola jest w położeniu:
% u = (fileIdx + 0.5) / 8
% v = (rankIdx + 0.5) / 8

P_BOARD_A1_CORNER = [-204, -737, 25];
P_BOARD_H1_CORNER = [ 236, -737, 24];
P_BOARD_A8_CORNER = [-204, -297, 19];
P_BOARD_H8_CORNER = [ 236, -297, 18];

squareCenter = @(fileIdx, rankIdx) ...
    (1-(fileIdx+0.5)/8) * (1-(rankIdx+0.5)/8) * P_BOARD_A1_CORNER + ...
    ((fileIdx+0.5)/8)   * (1-(rankIdx+0.5)/8) * P_BOARD_H1_CORNER + ...
    (1-(fileIdx+0.5)/8) * ((rankIdx+0.5)/8)   * P_BOARD_A8_CORNER + ...
    ((fileIdx+0.5)/8)   * ((rankIdx+0.5)/8)   * P_BOARD_H8_CORNER;

% Podgląd wyliczonych środków narożnych pól
disp("Calculated square centers from board corners [mm]:");
disp("A1 center = "); disp(squareCenter(0,0));
disp("H1 center = "); disp(squareCenter(7,0));
disp("A8 center = "); disp(squareCenter(0,7));
disp("H8 center = "); disp(squareCenter(7,7));

%% -------------------------
%  Region database
%  Q in degrees, P in [mm, rad]
% --------------------------

regions = struct([]);

% R1
regions(1).name = "R1"; % _A1_B2
regions(1).baseSquare = "A1";
regions(1).approachDir = "[-1 -1 0]";
regions(1).Q_deg = [-82.8, -121.7, -15.70, -126.6, 90.75, 25.29];
regions(1).P_APPROACH_HIGH = [-213, -749, 124.44, 0.929, 2.978, -0.227];
regions(1).P_APPROACH_LOW  = [-213, -749, 40.00,  1.137, 2.987, -0.413];
regions(1).P_INSERT_FLAT   = [-196, -725, 40.00,  1.137, 2.987, -0.413];
regions(1).P_ROTATE_LOCK   = [-196, -725, 40.00,  0.929, 2.978, -0.227];
regions(1).P_LIFT_LOCKED   = [-196, -725, 60.00,  0.929, 2.978, -0.227];

% R2
regions(2).name = "R2"; % _C1_D2
regions(2).baseSquare = "D1";
regions(2).approachDir = "[-1 -1 0]";
regions(2).Q_deg = [-79, -127, -2.5, -136.5, 90, 8];
regions(2).P_APPROACH_HIGH = [-50.00, -716, 150.00, 0.929, 2.975, -0.227];
regions(2).hasApproachMid = true;
regions(2).P_APPROACH_MID = [-49, -739, 114, 0.929, 2.975, -0.227];
regions(2).P_APPROACH_LOW  = [-48, -745, 39.50,  1.137, 2.987, -0.413];
regions(2).P_INSERT_FLAT   = [-31, -726, 39.50,  1.137, 2.987, -0.413];
regions(2).P_ROTATE_LOCK   = [-31, -726, 39.50,  0.929, 2.975, -0.227];
regions(2).P_LIFT_LOCKED   = [-31, -726, 60.00,  0.929, 2.975, -0.227];

% R3
regions(3).name = "R3"; %_E1_F2
regions(3).baseSquare = "E1";
regions(3).approachDir = "[1 -1 0]";
regions(3).Q_deg = [-62, -116, -25.7, -123, 88.6, 27.8];
regions(3).P_APPROACH_HIGH = [77, -731, 133.00, 0.852, -3.035, 0.180];
regions(3).hasApproachMid = true;
regions(3).P_APPROACH_MID = [86, -740, 115, 0.852, -3.035, 0.180];
regions(3).P_APPROACH_LOW  = [86, -751, 39.50, 1.125, -3.020, 0.408];
regions(3).P_INSERT_FLAT   = [65, -730, 39.50, 1.125, -3.020, 0.408];
regions(3).P_ROTATE_LOCK   = [65, -730, 39.50, 0.852, -3.035, 0.180];
regions(3).P_LIFT_LOCKED   = [65, -730, 60.50, 0.852, -3.035, 0.180];

% R4
regions(4).name = "R4"; % _G1_H2
regions(4).baseSquare = "H1";
regions(4).approachDir = "[1 -1 0]";
regions(4).Q_deg = [-52, -118.8, -24, -120.7, 87.7, 29.14];
regions(4).P_APPROACH_HIGH = [252, -723, 140.00, 0.852, -3.035, 0.180];
regions(4).hasApproachMid  = true;
regions(4).P_APPROACH_MID  = [246 -746 123.3 1.015 -2.964 0.248];
regions(4).P_APPROACH_LOW  = [250, -749, 39.50,  1.125, -3.020, 0.408];
regions(4).P_INSERT_FLAT   = [231, -730, 39.50,  1.125, -3.020, 0.408];
regions(4).P_ROTATE_LOCK   = [231, -730, 39.50,  0.852, -3.035, 0.180];
regions(4).P_LIFT_LOCKED   = [231, -730, 60.00,  0.852, -3.035, 0.180];

% R5
regions(5).name = "R5"; % _A3_B4
regions(5).baseSquare = "A3";
regions(5).approachDir = "[-1 -1 0]";
regions(5).Q_deg = [-80, -94, -51.5, -121, 90, 27];
regions(5).P_APPROACH_HIGH = [-216, -636, 124.44, 0.929, 2.978, -0.227];
regions(5).P_APPROACH_LOW  = [-216, -636, 38.00,  1.137, 2.987, -0.413];
regions(5).P_INSERT_FLAT   = [-196, -615, 38.00,  1.137, 2.987, -0.413];
regions(5).P_ROTATE_LOCK   = [-196, -615, 38.00,  0.929, 2.978, -0.227];
regions(5).P_LIFT_LOCKED   = [-196, -615, 60.00,  0.929, 2.978, -0.227];

% R6
regions(6).name = "R6"; % _C3_D4
regions(6).baseSquare = "D3";
regions(6).approachDir = "[1 -1 0]";
regions(6).Q_deg = [-74.3, -96, -45.5, -126.8, 90, 17];
regions(6).P_APPROACH_HIGH = [28, -639, 124.44, 0.852, -3.035, 0.180];
regions(6).P_APPROACH_LOW  = [28, -639, 38.00,   1.125, -3.020, 0.408];
regions(6).P_INSERT_FLAT   = [11, -619, 38.00,   1.125, -3.020, 0.408];
regions(6).P_ROTATE_LOCK   = [11, -619, 38.00,   0.852, -3.035, 0.180];
regions(6).P_LIFT_LOCKED   = [11, -619, 60.00,   0.852, -3.035, 0.180];

% R7
regions(7).name = "R7"; % _E3_F4
regions(7).baseSquare = "F3";
regions(7).approachDir = "[1 -1 0]";
regions(7).Q_deg = [-53.2, -91, -54, -121.6, 90, 36];
regions(7).P_APPROACH_HIGH = [140, -639, 126.00, 0.852, -3.035, 0.180];
regions(7).P_APPROACH_LOW  = [140, -639, 38.00,  1.125, -3.020, 0.408];
regions(7).P_INSERT_FLAT   = [121, -620, 38.00,  1.125, -3.020, 0.408];
regions(7).P_ROTATE_LOCK   = [121, -620, 38.00,  0.852, -3.035, 0.180];
regions(7).P_LIFT_LOCKED   = [121, -620, 60.00,  0.852, -3.035, 0.180];

% R8
regions(8).name = "R8"; % _G3_H4
regions(8).baseSquare = "H3";
regions(8).approachDir = "[1 -1 0]";
regions(8).Q_deg = [-42.5, -98, -49, -120, 87, 36.5];
regions(8).P_APPROACH_HIGH = [253, -641, 140.00, 0.852, -3.035, 0.180];
regions(8).P_APPROACH_LOW  = [263, -641, 37.50,  1.125, -3.020, 0.408];
regions(8).P_INSERT_FLAT   = [232, -621, 37.50,  1.125, -3.020, 0.408];
regions(8).P_ROTATE_LOCK   = [232, -621, 37.50,  0.852, -3.035, 0.180];
regions(8).P_LIFT_LOCKED   = [232, -621, 60.00,  0.852, -3.035, 0.180];

% R9
regions(9).name = "R9"; % _A5_B6
regions(9).baseSquare = "B5";
regions(9).approachDir = "[1 -1 0]";
regions(9).Q_deg = [-118.8, -96.5, -46.6, -124.5, 90, -48.7];
regions(9).P_APPROACH_HIGH = [-80, -530, 140.00, 0.852, -3.035, 0.180];
regions(9).P_APPROACH_LOW  = [-80, -530, 37.00,  1.125, -3.020, 0.408];
regions(9).P_INSERT_FLAT   = [-97, -509, 37.00,  1.125, -3.020, 0.408];
regions(9).P_ROTATE_LOCK   = [-97, -509, 37.00,  0.852, -3.035, 0.180];
regions(9).P_LIFT_LOCKED   = [-97, -509, 60.00,  0.852, -3.035, 0.180];

% R10
regions(10).name = "R10"; % _C5_D6
regions(10).baseSquare = "D5";
regions(10).approachDir = "[1 -1 0]";
regions(10).Q_deg = [-92.2, -78.50, -62, -127.7, 90, -22];
regions(10).P_APPROACH_HIGH = [33, -530, 140.00, 0.852, -3.035, 0.180];
regions(10).P_APPROACH_LOW  = [33, -530, 37.00,  1.125, -3.020, 0.408];
regions(10).P_INSERT_FLAT   = [14, -510, 37.00,  1.125, -3.020, 0.408];
regions(10).P_ROTATE_LOCK   = [14, -510, 37.00,  0.852, -3.035, 0.180];
regions(10).P_LIFT_LOCKED   = [14, -510, 60.00,  0.852, -3.035, 0.180];

% R11
regions(11).name = "R11"; % _E5_F6
regions(11).baseSquare = "F5";
regions(11).approachDir = "[1 -1 0]";
regions(11).Q_deg = [-57.5, -71, -66.77, -130.8, 90, 12.6];
regions(11).P_APPROACH_HIGH = [141, -532, 140.00, 0.852, -3.035, 0.180];
regions(11).P_APPROACH_LOW  = [141, -532, 36.00,  1.125, -3.020, 0.408];
regions(11).P_INSERT_FLAT   = [123, -511, 36.00,  1.125, -3.020, 0.408];
regions(11).P_ROTATE_LOCK   = [123, -511, 36.00,  0.852, -3.035, 0.180];
regions(11).P_LIFT_LOCKED   = [123, -511, 60.00,  0.852, -3.035, 0.180];

% R12
regions(12).name = "R12"; % _G5_H6
regions(12).baseSquare = "H6";
regions(12).approachDir = "[-1 -1 0]";
regions(12).Q_deg = [-14, -112.5, -23.2, -134.2, 87.5, 99.5];
regions(12).P_APPROACH_HIGH = [171, -472, 140.00, 0.929, 2.978, -0.227];
regions(12).P_APPROACH_LOW  = [171, -472, 35.00,  1.137, 2.987, -0.413];
regions(12).P_INSERT_FLAT   = [188, -450, 35.00,  1.137, 2.987, -0.413];
regions(12).P_ROTATE_LOCK   = [188, -450, 35.00,  0.929, 2.978, -0.227];
regions(12).P_LIFT_LOCKED   = [188, -450, 60.00,  0.929, 2.978, -0.227];

% R13
regions(13).name = "R13"; % _A7_B8
regions(13).baseSquare = "B7";
regions(13).approachDir = "[1 -1 0]";
regions(13).Q_deg = [-131.7, -86.2, -53, -130, 90, -63];
regions(13).P_APPROACH_HIGH = [-78, -420, 140.00, 0.852, -3.035, 0.180];
regions(13).P_APPROACH_LOW  = [-78, -420, 35.50,  1.125, -3.020, 0.408];
regions(13).P_INSERT_FLAT   = [-98, -400, 35.50,  1.125, -3.020, 0.408];
regions(13).P_ROTATE_LOCK   = [-98, -400, 35.50,  0.852, -3.035, 0.180];
regions(13).P_LIFT_LOCKED   = [-98, -400, 60.00,  0.852, -3.035, 0.180];

% R14
regions(14).name = "R14"; % _C7_D8
regions(14).baseSquare = "D7";
regions(14).approachDir = "[1 -1 0]";
regions(14).Q_deg = [-99.5, -64, -66, -139, 90, -31];
regions(14).P_APPROACH_HIGH = [30, -420, 140.00, 0.852, -3.035, 0.180];
regions(14).P_APPROACH_LOW  = [30, -420, 35.00,  1.125, -3.020, 0.408];
regions(14).P_INSERT_FLAT   = [10, -400, 35.00,  1.125, -3.020, 0.408];
regions(14).P_ROTATE_LOCK   = [10, -400, 35.00,  0.852, -3.035, 0.180];
regions(14).P_LIFT_LOCKED   = [10, -400, 60.00,  0.852, -3.035, 0.180];

% R15
regions(15).name = "R15"; % _E7_F8
regions(15).baseSquare = "F8";
regions(15).approachDir = "[-1 -1 0]";
regions(15).Q_deg = [-3, -90, -52, -127.5, 87.5, 127.5];
regions(15).P_APPROACH_HIGH = [61, -362, 140.00, 0.929, 2.978, -0.227];
regions(15).P_APPROACH_LOW  = [61, -362, 34.00,  1.137, 2.987, -0.413];
regions(15).P_INSERT_FLAT   = [80, -341, 34.00,  1.137, 2.987, -0.413];
regions(15).P_ROTATE_LOCK   = [80, -341, 34.00,  0.929, 2.978, -0.227];
regions(15).P_LIFT_LOCKED   = [80, -341, 60.00,  0.929, 2.978, -0.227];

% R16
regions(16).name = "R16"; % _G7_H8
regions(16).baseSquare = "H8";
regions(16).approachDir = "[-1 -1 0]";
regions(16).Q_deg = [0, -117.7, -12.9, -138, 87.5, 126];
regions(16).P_APPROACH_HIGH = [173, -361, 102.00, 0.929, 2.978, -0.227];
regions(16).P_APPROACH_LOW  = [173, -361, 33.00,  1.137, 2.987, -0.413];
regions(16).P_INSERT_FLAT   = [194, -339, 33.00,  1.137, 2.987, -0.413];
regions(16).P_ROTATE_LOCK   = [194, -339, 33.00,  0.929, 2.978, -0.227];
regions(16).P_LIFT_LOCKED   = [194, -339, 53.00,  0.929, 2.978, -0.227];

%% -------------------------
%  Default optional approach mid point
% --------------------------

for k = 1:numel(regions)
    if ~isfield(regions, "hasApproachMid") || isempty(regions(k).hasApproachMid)
        regions(k).hasApproachMid = false;
    end

    if ~isfield(regions, "P_APPROACH_MID")
        regions(k).P_APPROACH_MID = [];
    end
end

%% ============================================================
%  UNIVERSAL TRANSFER TEST: fromSquare -> toSquare
%  TEST 1: piece-specific Z correction
%  TEST 2: piece-specific insert scaling
% ============================================================

fromSquare = "E7";
toSquare   = "B1";

movingPiece = "P";   % "P", "N", "B", "R", "Q", "K"

% TEST 1:
% true  = koryguje wysokości Z pod typ figury
% false = działa jak wcześniej, baza pod konia
usePieceZCorrection = true;

% TEST 2:
% false = najpierw testujemy tylko Z
% true  = dodatkowo skaluje długość wsunięcia pod typ figury
usePieceInsertScale = true;

Q_HOME_deg = [-90, -45, -90, -90, 90, 0];
Q_HOME = deg2rad(Q_HOME_deg);
Q_HOME_lin = [-112 -486 498 0.002 -2.899 1.199];
%% -------------------------
%  Piece parameters
%  Base data measured on A1
% --------------------------

basePiece = "N";   % obecne punkty regionów są bazowo skalibrowane pod konia

pieceZ.P    = 56.0;
pieceZ.N    = 41.0;
pieceZ.B    = 63.5;
pieceZ.R    = 66;
pieceZ.Q    = 75;
pieceZ.K    = 78;

% Insert offsets measured on A1, in mm
pieceInsertXY.P    = [20, 22];
pieceInsertXY.N    = [14, 14];
pieceInsertXY.B    = [19, 27];
pieceInsertXY.R    = [16, 20];
pieceInsertXY.Q    = [17, 25];
pieceInsertXY.K    = [15, 25];

pieceInsertLen.P    = norm(pieceInsertXY.P);
pieceInsertLen.N    = norm(pieceInsertXY.N);
pieceInsertLen.B    = norm(pieceInsertXY.B);
pieceInsertLen.R    = norm(pieceInsertXY.R);
pieceInsertLen.Q    = norm(pieceInsertXY.Q);
pieceInsertLen.K    = norm(pieceInsertXY.K);

if ~isfield(pieceZ, char(movingPiece))
    error("Unknown movingPiece: %s", movingPiece);
end
%% -------------------------
%  Convert from/to square names to indices
% --------------------------

from = char(upper(fromSquare));
to   = char(upper(toSquare));

fromFileIdx = double(from(1) - 'A');
fromRankIdx = str2double(from(2)) - 1;

toFileIdx = double(to(1) - 'A');
toRankIdx = str2double(to(2)) - 1;

if fromFileIdx < 0 || fromFileIdx > 7 || fromRankIdx < 0 || fromRankIdx > 7
    error("Niepoprawne pole startowe: %s", fromSquare);
end

if toFileIdx < 0 || toFileIdx > 7 || toRankIdx < 0 || toRankIdx > 7
    error("Niepoprawne pole docelowe: %s", toSquare);
end

%% -------------------------
%  Determine region numbers
%  Numeracja:
%  R1  = A1-B2
%  R2  = C1-D2
%  R3  = E1-F2
%  R4  = G1-H2
%  ...
%  R16 = G7-H8
% --------------------------

fromFileGroup = floor(fromFileIdx / 2);
fromRankGroup = floor(fromRankIdx / 2);

toFileGroup = floor(toFileIdx / 2);
toRankGroup = floor(toRankIdx / 2);

fromRegionIdx = fromRankGroup * 4 + fromFileGroup + 1;
toRegionIdx   = toRankGroup   * 4 + toFileGroup   + 1;

R_from = regions(fromRegionIdx);
R_to   = regions(toRegionIdx);

fprintf("fromSquare = %s -> region %s\n", fromSquare, R_from.name);
fprintf("toSquare   = %s -> region %s\n", toSquare, R_to.name);

%% -------------------------
%  Compute delta for FROM relative to its base square
% --------------------------

baseFrom = char(upper(R_from.baseSquare));

baseFromFileIdx = double(baseFrom(1) - 'A');
baseFromRankIdx = str2double(baseFrom(2)) - 1;

C_from_base = squareCenter(baseFromFileIdx, baseFromRankIdx);
C_from      = squareCenter(fromFileIdx, fromRankIdx);

delta_from_mm = C_from - C_from_base;

disp("Delta FROM względem pola bazowego [mm]:");
disp(delta_from_mm);

%% -------------------------
%  Compute delta for TO relative to its base square
% --------------------------

baseTo = char(upper(R_to.baseSquare));

baseToFileIdx = double(baseTo(1) - 'A');
baseToRankIdx = str2double(baseTo(2)) - 1;

C_to_base = squareCenter(baseToFileIdx, baseToRankIdx);
C_to      = squareCenter(toFileIdx, toRankIdx);

delta_to_mm = C_to - C_to_base;

disp("Delta TO względem pola bazowego [mm]:");
disp(delta_to_mm);

%% -------------------------
%  Generate FROM points
% --------------------------

Q_FROM_HIGH = deg2rad(R_from.Q_deg);

P_FROM_APPROACH_HIGH = R_from.P_APPROACH_HIGH;
P_FROM_APPROACH_LOW  = R_from.P_APPROACH_LOW;
P_FROM_INSERT_FLAT   = R_from.P_INSERT_FLAT;
P_FROM_ROTATE_LOCK   = R_from.P_ROTATE_LOCK;
P_FROM_LIFT_LOCKED   = R_from.P_LIFT_LOCKED;

hasMidFrom = isfield(R_from, 'hasApproachMid') && ...
             ~isempty(R_from.hasApproachMid) && ...
             R_from.hasApproachMid;

if hasMidFrom
    P_FROM_APPROACH_MID = R_from.P_APPROACH_MID;
else
    P_FROM_APPROACH_MID = [];
end

P_FROM_APPROACH_HIGH(1:3) = P_FROM_APPROACH_HIGH(1:3) + delta_from_mm;
P_FROM_APPROACH_LOW(1:3)  = P_FROM_APPROACH_LOW(1:3)  + delta_from_mm;
P_FROM_INSERT_FLAT(1:3)   = P_FROM_INSERT_FLAT(1:3)   + delta_from_mm;
P_FROM_ROTATE_LOCK(1:3)   = P_FROM_ROTATE_LOCK(1:3)   + delta_from_mm;
P_FROM_LIFT_LOCKED(1:3)   = P_FROM_LIFT_LOCKED(1:3)   + delta_from_mm;

if ~isempty(P_FROM_APPROACH_MID)
    P_FROM_APPROACH_MID(1:3) = P_FROM_APPROACH_MID(1:3) + delta_from_mm;
end

P_FROM_EXIT_HIGH = P_FROM_APPROACH_HIGH;

%% -------------------------
%  Generate TO points
% --------------------------

Q_TO_HIGH = deg2rad(R_to.Q_deg);

P_TO_APPROACH_HIGH = R_to.P_APPROACH_HIGH;
P_TO_APPROACH_LOW  = R_to.P_APPROACH_LOW;
P_TO_INSERT_FLAT   = R_to.P_INSERT_FLAT;
P_TO_ROTATE_LOCK   = R_to.P_ROTATE_LOCK;
P_TO_LIFT_LOCKED   = R_to.P_LIFT_LOCKED;

hasMidFrom = isfield(R_to, 'hasApproachMid') && ...
             ~isempty(R_to.hasApproachMid) && ...
             R_to.hasApproachMid;

if hasMidFrom
    P_TO_APPROACH_MID = R_to.P_APPROACH_MID;
else
    P_TO_APPROACH_MID = [];
end

P_TO_APPROACH_HIGH(1:3) = P_TO_APPROACH_HIGH(1:3) + delta_to_mm;
P_TO_APPROACH_LOW(1:3)  = P_TO_APPROACH_LOW(1:3)  + delta_to_mm;
P_TO_INSERT_FLAT(1:3)   = P_TO_INSERT_FLAT(1:3)   + delta_to_mm;
P_TO_ROTATE_LOCK(1:3)   = P_TO_ROTATE_LOCK(1:3)   + delta_to_mm;
P_TO_LIFT_LOCKED(1:3)   = P_TO_LIFT_LOCKED(1:3)   + delta_to_mm;

if ~isempty(P_TO_APPROACH_MID)
    P_TO_APPROACH_MID(1:3) = P_TO_APPROACH_MID(1:3) + delta_to_mm;
end

P_TO_EXIT_HIGH = P_TO_APPROACH_HIGH;

%% -------------------------
%  Apply piece-specific correction
%  TEST 1: Z correction
%  TEST 2: insert length scaling
% --------------------------

if usePieceZCorrection
    pieceDeltaZ = pieceZ.(char(movingPiece)) - pieceZ.(char(basePiece));

    % FROM - picking moving piece
    P_FROM_APPROACH_LOW(3) = P_FROM_APPROACH_LOW(3) + pieceDeltaZ;
    P_FROM_INSERT_FLAT(3)  = P_FROM_INSERT_FLAT(3)  + pieceDeltaZ;
    P_FROM_ROTATE_LOCK(3)  = P_FROM_ROTATE_LOCK(3)  + pieceDeltaZ;
    P_FROM_LIFT_LOCKED(3)  = P_FROM_LIFT_LOCKED(3)  + pieceDeltaZ;

    % TO - placing moving piece
    P_TO_APPROACH_LOW(3) = P_TO_APPROACH_LOW(3) + pieceDeltaZ;
    P_TO_INSERT_FLAT(3)  = P_TO_INSERT_FLAT(3)  + pieceDeltaZ;
    P_TO_ROTATE_LOCK(3)  = P_TO_ROTATE_LOCK(3)  + pieceDeltaZ;
    P_TO_LIFT_LOCKED(3)  = P_TO_LIFT_LOCKED(3)  + pieceDeltaZ;
end

if usePieceInsertScale
    scale = pieceInsertLen.(char(movingPiece)) / pieceInsertLen.(char(basePiece));

    % FROM insert vector
    fromInsertVec = P_FROM_INSERT_FLAT(1:2) - P_FROM_APPROACH_LOW(1:2);
    fromInsertVecScaled = fromInsertVec * scale;

    P_FROM_INSERT_FLAT(1:2) = P_FROM_APPROACH_LOW(1:2) + fromInsertVecScaled;
    P_FROM_ROTATE_LOCK(1:2) = P_FROM_INSERT_FLAT(1:2);
    P_FROM_LIFT_LOCKED(1:2) = P_FROM_INSERT_FLAT(1:2);

    % TO insert vector
    toInsertVec = P_TO_INSERT_FLAT(1:2) - P_TO_APPROACH_LOW(1:2);
    toInsertVecScaled = toInsertVec * scale;

    P_TO_INSERT_FLAT(1:2) = P_TO_APPROACH_LOW(1:2) + toInsertVecScaled;
    P_TO_ROTATE_LOCK(1:2) = P_TO_INSERT_FLAT(1:2);
    P_TO_LIFT_LOCKED(1:2) = P_TO_INSERT_FLAT(1:2);
end

fprintf("movingPiece = %s\n", movingPiece);
fprintf("usePieceZCorrection = %d\n", usePieceZCorrection);
fprintf("usePieceInsertScale = %d\n", usePieceInsertScale);

if usePieceZCorrection
    fprintf("pieceDeltaZ = %.2f mm\n", pieceZ.(char(movingPiece)) - pieceZ.(char(basePiece)));
end

if usePieceInsertScale
    fprintf("insert scale = %.3f\n", pieceInsertLen.(char(movingPiece)) / pieceInsertLen.(char(basePiece)));
end

%% -------------------------
%  Convert XYZ mm -> m
% --------------------------

P_FROM_APPROACH_HIGH(1:3) = P_FROM_APPROACH_HIGH(1:3) / 1000;
P_FROM_APPROACH_LOW(1:3)  = P_FROM_APPROACH_LOW(1:3)  / 1000;
P_FROM_INSERT_FLAT(1:3)   = P_FROM_INSERT_FLAT(1:3)   / 1000;
P_FROM_ROTATE_LOCK(1:3)   = P_FROM_ROTATE_LOCK(1:3)   / 1000;
P_FROM_LIFT_LOCKED(1:3)   = P_FROM_LIFT_LOCKED(1:3)   / 1000;
P_FROM_EXIT_HIGH(1:3)     = P_FROM_EXIT_HIGH(1:3)     / 1000;

Q_HOME_lin(1:3)           = Q_HOME_lin(1:3)           / 1000; 
if ~isempty(P_FROM_APPROACH_MID)
    P_FROM_APPROACH_MID(1:3) = P_FROM_APPROACH_MID(1:3) / 1000;
end

P_TO_APPROACH_HIGH(1:3) = P_TO_APPROACH_HIGH(1:3) / 1000;
P_TO_APPROACH_LOW(1:3)  = P_TO_APPROACH_LOW(1:3)  / 1000;
P_TO_INSERT_FLAT(1:3)   = P_TO_INSERT_FLAT(1:3)   / 1000;
P_TO_ROTATE_LOCK(1:3)   = P_TO_ROTATE_LOCK(1:3)   / 1000;
P_TO_LIFT_LOCKED(1:3)   = P_TO_LIFT_LOCKED(1:3)   / 1000;
P_TO_EXIT_HIGH(1:3)     = P_TO_EXIT_HIGH(1:3)     / 1000;

if ~isempty(P_TO_APPROACH_MID)
    P_TO_APPROACH_MID(1:3) = P_TO_APPROACH_MID(1:3) / 1000;
end

disp("FROM generated:");
disp("P_FROM_APPROACH_HIGH = "); disp(P_FROM_APPROACH_HIGH);
if ~isempty(P_FROM_APPROACH_MID)
    disp("P_FROM_APPROACH_MID = "); disp(P_FROM_APPROACH_MID);
end
disp("P_FROM_APPROACH_LOW = "); disp(P_FROM_APPROACH_LOW);
disp("P_FROM_INSERT_FLAT = "); disp(P_FROM_INSERT_FLAT);
disp("P_FROM_ROTATE_LOCK = "); disp(P_FROM_ROTATE_LOCK);
disp("P_FROM_LIFT_LOCKED = "); disp(P_FROM_LIFT_LOCKED);

disp("TO generated:");
disp("P_TO_APPROACH_HIGH = "); disp(P_TO_APPROACH_HIGH);
if ~isempty(P_TO_APPROACH_MID)
    disp("P_TO_APPROACH_MID = "); disp(P_TO_APPROACH_MID);
end
disp("P_TO_LIFT_LOCKED = "); disp(P_TO_LIFT_LOCKED);
disp("P_TO_ROTATE_LOCK = "); disp(P_TO_ROTATE_LOCK);
disp("P_TO_INSERT_FLAT = "); disp(P_TO_INSERT_FLAT);
disp("P_TO_APPROACH_LOW = "); disp(P_TO_APPROACH_LOW);

%% ============================================================
%  FULL TRANSFER URSCRIPT
% ============================================================

script = "";

script = script + "def transfer_square_to_square():" + newline;
script = script + "  set_tcp(p[0.000000, -0.290000, 0.260000, 0.000000, 0.000000, 0.000000])" + newline;
script = script + "  sleep(0.1)" + newline;

%% HOME

script = script + sprintf( ...
    "  movej([%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    Q_HOME(1), Q_HOME(2), Q_HOME(3), Q_HOME(4), Q_HOME(5), Q_HOME(6), ...
    a_joint, v_joint);

script = script + "  sleep(0.1)" + newline;

%% Move to FROM region high

script = script + sprintf( ...
    "  movej([%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    Q_FROM_HIGH(1), Q_FROM_HIGH(2), Q_FROM_HIGH(3), ...
    Q_FROM_HIGH(4), Q_FROM_HIGH(5), Q_FROM_HIGH(6), ...
    a_joint, v_joint);

script = script + "  sleep(0.1)" + newline;

%% PICK - approach high

p = P_FROM_APPROACH_HIGH;
script = script + sprintf( ...
    "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    p(1), p(2), p(3), p(4), p(5), p(6), ...
    a_lin, v_lin);

script = script + "  sleep(0.1)" + newline;

%% PICK - optional approach mid

if ~isempty(P_FROM_APPROACH_MID)

    p = P_FROM_APPROACH_MID;
    script = script + sprintf( ...
        "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
        p(1), p(2), p(3), p(4), p(5), p(6), ...
        a_lin, v_lin);

    script = script + "  sleep(0.1)" + newline;
end

%% PICK - approach low

p = P_FROM_APPROACH_LOW;
script = script + sprintf( ...
    "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    p(1), p(2), p(3), p(4), p(5), p(6), ...
    a_lin, v_lin);

script = script + "  sleep(0.1)" + newline;

% Za tym komentarzem section break, odkomentować / test na sprawdzanie
% wysokosci figur

% script = script + "end" + newline;
% script = script + "transfer_square_to_square()" + newline;
% 
% disp(script);
% 
% write(UR3client, uint8(char(script)), 'uint8');
% 
% disp("Wysłano uniwersalny test transferu fromSquare -> toSquare.");

%% PICK - insert flat

p = P_FROM_INSERT_FLAT;
script = script + sprintf( ...
    "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    p(1), p(2), p(3), p(4), p(5), p(6), ...
    a_lin, v_lin);

script = script + "  sleep(0.1)" + newline;

%%PICK - rotate lock

p = P_FROM_ROTATE_LOCK;
script = script + sprintf( ...
    "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    p(1), p(2), p(3), p(4), p(5), p(6), ...
    a_lin, v_lin);

script = script + "  sleep(0.1)" + newline;

% Za tym komentarzem section break, odkomentować / test na sprawdzanie
% podnoszenia figur

script = script + "end" + newline;
script = script + "transfer_square_to_square()" + newline;

disp(script);

write(UR3client, uint8(char(script)), 'uint8');

disp("Wysłano uniwersalny test transferu fromSquare -> toSquare.");


%% PICK - lift locked

p = P_FROM_LIFT_LOCKED;
script = script + sprintf( ...
    "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    p(1), p(2), p(3), p(4), p(5), p(6), ...
    a_lin, v_lin);

script = script + "  sleep(0.1)" + newline;

%% PICK - exit high while holding piece

p = P_FROM_EXIT_HIGH;
script = script + sprintf( ...
    "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    p(1), p(2), p(3), p(4), p(5), p(6), ...
    a_lin, v_lin);

script = script + "  sleep(0.1)" + newline;

%% Return to FROM region high

script = script + sprintf( ...
    "  movej([%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    Q_FROM_HIGH(1), Q_FROM_HIGH(2), Q_FROM_HIGH(3), ...
    Q_FROM_HIGH(4), Q_FROM_HIGH(5), Q_FROM_HIGH(6), ...
    a_joint, v_joint);

script = script + "  sleep(0.1)" + newline;



%% Transfer to TO region high

script = script + sprintf( ...
    "  movej([%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    Q_TO_HIGH(1), Q_TO_HIGH(2), Q_TO_HIGH(3), ...
    Q_TO_HIGH(4), Q_TO_HIGH(5), Q_TO_HIGH(6), ...
    a_joint, v_joint);

script = script + "  sleep(0.1)" + newline;


%% PLACE - approach high

p = P_TO_APPROACH_HIGH;
script = script + sprintf( ...
    "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    p(1), p(2), p(3), p(4), p(5), p(6), ...
    a_lin, v_lin);

script = script + "  sleep(0.1)" + newline;

%% PLACE - lift locked over target

p = P_TO_LIFT_LOCKED;
script = script + sprintf( ...
    "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    p(1), p(2), p(3), p(4), p(5), p(6), ...
    a_lin, v_lin);

script = script + "  sleep(0.1)" + newline;

%% PLACE - lower locked

p = P_TO_ROTATE_LOCK;
script = script + sprintf( ...
    "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    p(1), p(2), p(3), p(4), p(5), p(6), ...
    a_lin, v_lin);

script = script + "  sleep(0.1)" + newline;

%% PLACE - unrotate flat

p = P_TO_INSERT_FLAT;
script = script + sprintf( ...
    "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    p(1), p(2), p(3), p(4), p(5), p(6), ...
    a_lin, v_lin);

script = script + "  sleep(0.1)" + newline;

%% PLACE - exit flat / approach low

p = P_TO_APPROACH_LOW;
script = script + sprintf( ...
    "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    p(1), p(2), p(3), p(4), p(5), p(6), ...
    a_lin, v_lin);

script = script + "  sleep(0.1)" + newline;

if ~isempty(P_TO_APPROACH_MID)

    p = P_TO_APPROACH_MID;
    script = script + sprintf( ...
        "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
        p(1), p(2), p(3), p(4), p(5), p(6), ...
        a_lin, v_lin);

    script = script + "  sleep(0.1)" + newline;
end

%% PLACE - exit high

p = P_TO_EXIT_HIGH;
script = script + sprintf( ...
    "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    p(1), p(2), p(3), p(4), p(5), p(6), ...
    a_lin, v_lin);

script = script + "  sleep(0.1)" + newline;

%% Return to TO region high

script = script + sprintf( ...
    "  movej([%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    Q_TO_HIGH(1), Q_TO_HIGH(2), Q_TO_HIGH(3), ...
    Q_TO_HIGH(4), Q_TO_HIGH(5), Q_TO_HIGH(6), ...
    a_joint, v_joint);

script = script + "  sleep(0.1)" + newline;

%% HOME

script = script + sprintf( ...
    "  movej([%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
    Q_HOME(1), Q_HOME(2), Q_HOME(3), Q_HOME(4), Q_HOME(5), Q_HOME(6), ...
    a_joint, v_joint);

script = script + "end" + newline;
script = script + "transfer_square_to_square()" + newline;

disp(script);

write(UR3client, uint8(char(script)), 'uint8');

disp("Wysłano uniwersalny test transferu fromSquare -> toSquare.");

%% ============================================================
%  TESTS for local regions
% ============================================================

% % %% 1. REGION_HIGH
% % 
% % strCmd = sprintf( ...
% %     'movej([%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)\n', ...
% %     Q_REGION_HIGH(1), Q_REGION_HIGH(2), Q_REGION_HIGH(3), ...
% %     Q_REGION_HIGH(4), Q_REGION_HIGH(5), Q_REGION_HIGH(6), ...
% %     a_joint, v_joint);
% % 
% % disp(strCmd);
% % write(UR3client, uint8(strCmd), 'uint8');

% % %% 2. APPROACH_HIGH
% % 
% % p = P_APPROACH_HIGH;
% % 
% % strCmd = sprintf( ...
% %     'movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)\n', ...
% %     p(1), p(2), p(3), p(4), p(5), p(6), ...
% %     a_lin, v_lin);
% % 
% % disp(strCmd);
% % write(UR3client, uint8(strCmd), 'uint8');

% % %% 2b. APPROACH_MID - optional
% % 
% % if ~isempty(P_APPROACH_MID)
% % 
% %     p = P_APPROACH_MID;
% % 
% %     strCmd = sprintf( ...
% %         'movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)\n', ...
% %         p(1), p(2), p(3), p(4), p(5), p(6), ...
% %         a_lin, v_lin);
% % 
% %     disp(strCmd);
% %     write(UR3client, uint8(strCmd), 'uint8');
% % 
% % else
% %     disp("Ten region nie ma P_APPROACH_MID - pomijam.");
% % end

% % %% 3. APPROACH_LOW
% % 
% % p = P_APPROACH_LOW;
% % 
% % strCmd = sprintf( ...
% %     'movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)\n', ...
% %     p(1), p(2), p(3), p(4), p(5), p(6), ...
% %     a_lin, v_lin);
% % 
% % disp(strCmd);
% % write(UR3client, uint8(strCmd), 'uint8');

% % %% 4. INSERT_FLAT
% % 
% % p = P_INSERT_FLAT;
% % 
% % strCmd = sprintf( ...
% %     'movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)\n', ...
% %     p(1), p(2), p(3), p(4), p(5), p(6), ...
% %     a_lin, v_lin);
% % 
% % disp(strCmd);
% % write(UR3client, uint8(strCmd), 'uint8');

% % %% 5. ROTATE_LOCK
% % 
% % p = P_ROTATE_LOCK;
% % 
% % strCmd = sprintf( ...
% %     'movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)\n', ...
% %     p(1), p(2), p(3), p(4), p(5), p(6), ...
% %     a_lin, v_lin);
% % 
% % disp(strCmd);
% % write(UR3client, uint8(strCmd), 'uint8');

% % %% 6. LIFT_LOCKED
% % 
% % p = P_LIFT_LOCKED;
% % 
% % strCmd = sprintf( ...
% %     'movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)\n', ...
% %     p(1), p(2), p(3), p(4), p(5), p(6), ...
% %     a_lin, v_lin);
% % 
% % disp(strCmd);
% % write(UR3client, uint8(strCmd), 'uint8');

% % %% 7. LOWER_LOCKED
% % 
% % p = P_LOWER_LOCKED;
% % 
% % strCmd = sprintf( ...
% %     'movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)\n', ...
% %     p(1), p(2), p(3), p(4), p(5), p(6), ...
% %     a_lin, v_lin);
% % 
% % disp(strCmd);
% % write(UR3client, uint8(strCmd), 'uint8');

% % %% 8. UNROTATE_FLAT
% % 
% % p = P_UNROTATE_FLAT;
% % 
% % strCmd = sprintf( ...
% %     'movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)\n', ...
% %     p(1), p(2), p(3), p(4), p(5), p(6), ...
% %     a_lin, v_lin);
% % 
% % disp(strCmd);
% % write(UR3client, uint8(strCmd), 'uint8');

% % %% 9. EXIT_FLAT
% % 
% % p = P_EXIT_FLAT;
% % 
% % strCmd = sprintf( ...
% %     'movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)\n', ...
% %     p(1), p(2), p(3), p(4), p(5), p(6), ...
% %     a_lin, v_lin);
% % 
% % disp(strCmd);
% % write(UR3client, uint8(strCmd), 'uint8');

% % %% 10. EXIT_HIGH
% % 
% % p = P_EXIT_HIGH;
% % 
% % strCmd = sprintf( ...
% %     'movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)\n', ...
% %     p(1), p(2), p(3), p(4), p(5), p(6), ...
% %     a_lin, v_lin);
% % 
% % disp(strCmd);
% % write(UR3client, uint8(strCmd), 'uint8');

% % %% 11. REGION_HIGH_BACK
% % 
% % strCmd = sprintf( ...
% %     'movej([%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)\n', ...
% %     Q_REGION_HIGH(1), Q_REGION_HIGH(2), Q_REGION_HIGH(3), ...
% %     Q_REGION_HIGH(4), Q_REGION_HIGH(5), Q_REGION_HIGH(6), ...
% %     a_joint, v_joint);
% % 
% % disp(strCmd);
% % write(UR3client, uint8(strCmd), 'uint8');
