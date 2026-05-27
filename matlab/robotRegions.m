function [regions, squareCenter, boardCalib] = robotRegions()
%ROBOTREGIONS Return calibrated 2x2 chessboard robot regions.
%
% Output:
%   regions      - 1x16 struct array with calibrated region data.
%                  Q_deg is in degrees.
%                  P_* points are [X Y Z rx ry rz], XYZ in mm, rotation in rad.
%   squareCenter - function handle: squareCenter(fileIdx, rankIdx), where
%                  fileIdx: A=0 ... H=7, rankIdx: 1=0 ... 8=7.
%                  Returns [X Y Z] in mm.
%   boardCalib   - struct with four calibrated board corner centers in mm.
%
% Region numbering:
%   R1  = A1-B2, R2  = C1-D2, R3  = E1-F2, R4  = G1-H2
%   R5  = A3-B4, R6  = C3-D4, R7  = E3-F4, R8  = G3-H4
%   R9  = A5-B6, R10 = C5-D6, R11 = E5-F6, R12 = G5-H6
%   R13 = A7-B8, R14 = C7-D8, R15 = E7-F8, R16 = G7-H8

%% Board calibration [mm]
% Calibration based on the outer corners of the playable 8x8 grid.
% fileIdx: A=0 ... H=7
% rankIdx: 1=0 ... 8=7

boardCalib.P_BOARD_A1_CORNER = [-204, -737, 25];
boardCalib.P_BOARD_H1_CORNER = [ 236, -737, 24];
boardCalib.P_BOARD_A8_CORNER = [-204, -297, 19];
boardCalib.P_BOARD_H8_CORNER = [ 236, -297, 18];

P_BOARD_A1_CORNER = boardCalib.P_BOARD_A1_CORNER;
P_BOARD_H1_CORNER = boardCalib.P_BOARD_H1_CORNER;
P_BOARD_A8_CORNER = boardCalib.P_BOARD_A8_CORNER;
P_BOARD_H8_CORNER = boardCalib.P_BOARD_H8_CORNER;

squareCenter = @(fileIdx, rankIdx) ...
    (1-(fileIdx+0.5)/8) * (1-(rankIdx+0.5)/8) * P_BOARD_A1_CORNER + ...
    ((fileIdx+0.5)/8)   * (1-(rankIdx+0.5)/8) * P_BOARD_H1_CORNER + ...
    (1-(fileIdx+0.5)/8) * ((rankIdx+0.5)/8)   * P_BOARD_A8_CORNER + ...
    ((fileIdx+0.5)/8)   * ((rankIdx+0.5)/8)   * P_BOARD_H8_CORNER;
%% Region database

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
regions(3).P_APPROACH_HIGH = [70, -731, 133.00, 0.852, -3.035, 0.180];
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
regions(4).P_APPROACH_HIGH = [232, -723, 140.00, 0.852, -3.035, 0.180];
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


%% Defaults for optional approach mid point

for k = 1:numel(regions)
    if ~isfield(regions, "hasApproachMid") || isempty(regions(k).hasApproachMid)
        regions(k).hasApproachMid = false;
    end

    if ~isfield(regions, "P_APPROACH_MID") || isempty(regions(k).P_APPROACH_MID)
        regions(k).P_APPROACH_MID = [];
    end
end

end
