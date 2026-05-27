function [regions, squareCenter, boardCalib] = robotRegions_old()
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

boardCalib.P_A1_center = [-165, -715, 25];
boardCalib.P_H1_center = [ 225, -708, 25];
boardCalib.P_A8_center = [-165, -330, 21];
boardCalib.P_H8_center = [ 211, -317, 19];

P_A1_center = boardCalib.P_A1_center;
P_H1_center = boardCalib.P_H1_center;
P_A8_center = boardCalib.P_A8_center;
P_H8_center = boardCalib.P_H8_center;

squareCenter = @(fileIdx, rankIdx) ...
    (1-fileIdx/7)*(1-rankIdx/7)*P_A1_center + ...
    (fileIdx/7)*(1-rankIdx/7)*P_H1_center + ...
    (1-fileIdx/7)*(rankIdx/7)*P_A8_center + ...
    (fileIdx/7)*(rankIdx/7)*P_H8_center;

%% Region database

regions = struct([]);

% R1
regions(1).name = "R1"; % _A1_B2
regions(1).baseSquare = "A1";
regions(1).approachDir = "[-1 -1 0]";
regions(1).Q_deg = [-82.8, -121.7, -15.70, -126.6, 90.75, 25.29];
regions(1).P_APPROACH_HIGH = [-200, -749, 124.44, 0.929, 2.978, -0.227];
regions(1).P_APPROACH_LOW  = [-200, -749, 40.50,  1.132, 2.962, -0.392];
regions(1).P_INSERT_FLAT   = [-185, -730, 40.50,  1.132, 2.962, -0.392];
regions(1).P_ROTATE_LOCK   = [-185, -730, 40.50,  0.929, 2.978, -0.227];
regions(1).P_LIFT_LOCKED   = [-185, -730, 60.00,  0.929, 2.978, -0.227];

% R2
regions(2).name = "R2"; % _C1_D2
regions(2).baseSquare = "D1";
regions(2).approachDir = "[-1 -1 0]";
regions(2).Q_deg = [-79, -127, -2.5, -136.5, 90, 8];
regions(2).P_APPROACH_HIGH = [-40.2, -716, 150.00, 0.929, 2.975, -0.227];
regions(2).hasApproachMid = true;
regions(2).P_APPROACH_MID = [-38.15, -737.2, 114, 0.929, 2.975, -0.227];
regions(2).P_APPROACH_LOW  = [-34.2, -745, 40.50,  1.132, 2.962, -0.392];
regions(2).P_INSERT_FLAT   = [-18, -729, 40.00,  1.132, 2.962, -0.392];
regions(2).P_ROTATE_LOCK   = [-18, -729, 40.00,  0.929, 2.975, -0.227];
regions(2).P_LIFT_LOCKED   = [-18, -729, 60.00,  0.929, 2.975, -0.227];

% R3
regions(3).name = "R3"; %_E1_F2
regions(3).baseSquare = "E1";
regions(3).approachDir = "[1 -1 0]";
regions(3).Q_deg = [-62, -116, -25.7, -123, 88.6, 27.8];
regions(3).P_APPROACH_HIGH = [98, -731, 133.00, 0.852, -3.035, 0.180];
regions(3).hasApproachMid = true;
regions(3).P_APPROACH_MID = [95.5, -736, 117.50, 0.852, -3.035, 0.180];
regions(3).P_APPROACH_LOW  = [97, -751, 41.00, 1.125, -3.020, 0.408];
regions(3).P_INSERT_FLAT   = [81, -729, 40.50, 1.125, -3.020, 0.408];
regions(3).P_ROTATE_LOCK   = [81, -729, 40.50, 0.852, -3.035, 0.180];
regions(3).P_LIFT_LOCKED   = [81, -729, 60.50, 0.852, -3.035, 0.180];

% R4
regions(4).name = "R4"; % _G1_H2
regions(4).baseSquare = "H1";
regions(4).approachDir = "[1 -1 0]";
regions(4).Q_deg = [-52, -118.8, -24, -120.7, 87.7, 29.14];
regions(4).P_APPROACH_HIGH = [252, -723, 140.00, 0.852, -3.035, 0.180];
regions(4).hasApproachMid  = true;
regions(4).P_APPROACH_MID  = [253.7 -744.8 123.3 1.015 -2.964 0.248];
regions(4).P_APPROACH_LOW  = [263, -750, 40.00,  1.125, -3.020, 0.408];
regions(4).P_INSERT_FLAT   = [244, -725, 40.00,  1.125, -3.020, 0.408];
regions(4).P_ROTATE_LOCK   = [244, -725, 40.00,  0.852, -3.035, 0.180];
regions(4).P_LIFT_LOCKED   = [244, -725, 60.00,  0.852, -3.035, 0.180];

% R5
regions(5).name = "R5"; % _A3_B4
regions(5).baseSquare = "A3";
regions(5).approachDir = "[-1 -1 0]";
regions(5).Q_deg = [-80, -94, -51.5, -121, 90, 27];
regions(5).P_APPROACH_HIGH = [-201, -636, 124.44, 0.929, 2.978, -0.227];
regions(5).P_APPROACH_LOW  = [-202, -636, 38.50,  1.132, 2.962, -0.392];
regions(5).P_INSERT_FLAT   = [-182, -618, 38.50,  1.132, 2.962, -0.392];
regions(5).P_ROTATE_LOCK   = [-182, -618, 38.50,  0.929, 2.978, -0.227];
regions(5).P_LIFT_LOCKED   = [-182, -618, 60.00,  0.929, 2.978, -0.227];

% R6
regions(6).name = "R6"; % _C3_D4
regions(6).baseSquare = "D3";
regions(6).approachDir = "[1 -1 0]";
regions(6).Q_deg = [-74.3, -96, -45.5, -126.8, 90, 17];
regions(6).P_APPROACH_HIGH = [37, -640, 124.44, 0.852, -3.035, 0.180];
regions(6).P_APPROACH_LOW  = [37, -640, 38.00,   1.125, -3.020, 0.408];
regions(6).P_INSERT_FLAT   = [24, -619, 38.00,   1.125, -3.020, 0.408];
regions(6).P_ROTATE_LOCK   = [24, -619, 38.00,   0.852, -3.035, 0.180];
regions(6).P_LIFT_LOCKED   = [24, -619, 60.00,   0.852, -3.035, 0.180];

% R7
regions(7).name = "R7"; % _E3_F4
regions(7).baseSquare = "F3";
regions(7).approachDir = "[1 -1 0]";
regions(7).Q_deg = [-53.2, -91, -54, -121.6, 90, 36];
regions(7).P_APPROACH_HIGH = [150, -640, 126.00, 0.852, -3.035, 0.180];
regions(7).P_APPROACH_LOW  = [149, -639, 38.50,  1.125, -3.020, 0.408];
regions(7).P_INSERT_FLAT   = [133, -619, 38.50,  1.125, -3.020, 0.408];
regions(7).P_ROTATE_LOCK   = [133, -619, 38.50,  0.852, -3.035, 0.180];
regions(7).P_LIFT_LOCKED   = [133, -619, 60.00,  0.852, -3.035, 0.180];

% R8
regions(8).name = "R8"; % _G3_H4
regions(8).baseSquare = "H3";
regions(8).approachDir = "[1 -1 0]";
regions(8).Q_deg = [-42.5, -98, -49, -120, 87, 36.5];
regions(8).P_APPROACH_HIGH = [252, -636, 140.00, 0.852, -3.035, 0.180];
regions(8).P_APPROACH_LOW  = [260, -638, 38.00,  1.125, -3.020, 0.408];
regions(8).P_INSERT_FLAT   = [242, -616, 38.00,  1.125, -3.020, 0.408];
regions(8).P_ROTATE_LOCK   = [242, -616, 38.00,  0.852, -3.035, 0.180];
regions(8).P_LIFT_LOCKED   = [242, -616, 60.00,  0.852, -3.035, 0.180];

% R9
regions(9).name = "R9"; % _A5_B6
regions(9).baseSquare = "B5";
regions(9).approachDir = "[1 -1 0]";
regions(9).Q_deg = [-118.8, -96.5, -46.6, -124.5, 90, -48.7];
regions(9).P_APPROACH_HIGH = [-74, -531, 140.00, 0.852, -3.035, 0.180];
regions(9).P_APPROACH_LOW  = [-74, -531, 37.50,  1.125, -3.020, 0.408];
regions(9).P_INSERT_FLAT   = [-89, -511, 37.50,  1.125, -3.020, 0.408];
regions(9).P_ROTATE_LOCK   = [-89, -511, 37.50,  0.852, -3.035, 0.180];
regions(9).P_LIFT_LOCKED   = [-89, -511, 60.00,  0.852, -3.035, 0.180];

% R10
regions(10).name = "R10"; % _C5_D6
regions(10).baseSquare = "D5";
regions(10).approachDir = "[1 -1 0]";
regions(10).Q_deg = [-92.2, -78.50, -62, -127.7, 90, -22];
regions(10).P_APPROACH_HIGH = [37, -529, 140.00, 0.852, -3.035, 0.180];
regions(10).P_APPROACH_LOW  = [37, -529, 37.00,  1.125, -3.020, 0.408];
regions(10).P_INSERT_FLAT   = [22, -508, 37.00,  1.125, -3.020, 0.408];
regions(10).P_ROTATE_LOCK   = [22, -508, 37.00,  0.852, -3.035, 0.180];
regions(10).P_LIFT_LOCKED   = [22, -508, 60.00,  0.852, -3.035, 0.180];

% R11
regions(11).name = "R11"; % _E5_F6
regions(11).baseSquare = "F5";
regions(11).approachDir = "[1 -1 0]";
regions(11).Q_deg = [-57.5, -71, -66.77, -130.8, 90, 12.6];
regions(11).P_APPROACH_HIGH = [150, -524, 140.00, 0.852, -3.035, 0.180];
regions(11).P_APPROACH_LOW  = [150, -524, 36.50,  1.125, -3.020, 0.408];
regions(11).P_INSERT_FLAT   = [131, -505, 36.50,  1.125, -3.020, 0.408];
regions(11).P_ROTATE_LOCK   = [131, -505, 36.50,  0.852, -3.035, 0.180];
regions(11).P_LIFT_LOCKED   = [131, -505, 60.00,  0.852, -3.035, 0.180];

% R12
regions(12).name = "R12"; % _G5_H6
regions(12).baseSquare = "G5";
regions(12).approachDir = "[-1 -1 0]";
regions(12).Q_deg = [-14, -112.5, -23.2, -134.2, 87.5, 99.5];
regions(12).P_APPROACH_HIGH = [128, -525, 140.00, 0.929, 2.978, -0.227];
regions(12).P_APPROACH_LOW  = [128, -525, 35.50,  1.132, 2.962, -0.392];
regions(12).P_INSERT_FLAT   = [145, -507, 35.50,  1.132, 2.962, -0.392];
regions(12).P_ROTATE_LOCK   = [145, -507, 35.50,  0.929, 2.978, -0.227];
regions(12).P_LIFT_LOCKED   = [145, -507, 60.50,  0.929, 2.978, -0.227];

% R13
regions(13).name = "R13"; % _A7_B8
regions(13).baseSquare = "B7";
regions(13).approachDir = "[1 -1 0]";
regions(13).Q_deg = [-131.7, -86.2, -53, -130, 90, -63];
regions(13).P_APPROACH_HIGH = [-70, -420, 140.00, 0.852, -3.035, 0.180];
regions(13).P_APPROACH_LOW  = [-70, -420, 36.00,  1.125, -3.020, 0.408];
regions(13).P_INSERT_FLAT   = [-90, -398, 36.00,  1.125, -3.020, 0.408];
regions(13).P_ROTATE_LOCK   = [-90, -398, 36.00,  0.852, -3.035, 0.180];
regions(13).P_LIFT_LOCKED   = [-90, -398, 60.00,  0.852, -3.035, 0.180];

% R14
regions(14).name = "R14"; % _C7_D8
regions(14).baseSquare = "D7";
regions(14).approachDir = "[1 -1 0]";
regions(14).Q_deg = [-99.5, -64, -66, -139, 90, -31];
regions(14).P_APPROACH_HIGH = [39, -414, 140.00, 0.852, -3.035, 0.180];
regions(14).P_APPROACH_LOW  = [39, -414, 35.50,  1.125, -3.020, 0.408];
regions(14).P_INSERT_FLAT   = [19, -397, 35.50,  1.125, -3.020, 0.408];
regions(14).P_ROTATE_LOCK   = [19, -397, 35.50,  0.852, -3.035, 0.180];
regions(14).P_LIFT_LOCKED   = [19, -397, 60.00,  0.852, -3.035, 0.180];

% R15
regions(15).name = "R15"; % _E7_F8
regions(15).baseSquare = "E7";
regions(15).approachDir = "[-1 -1 0]";
regions(15).Q_deg = [-3, -90, -52, -127.5, 87.5, 127.5];
regions(15).P_APPROACH_HIGH = [16, -420, 140.00, 0.929, 2.978, -0.227];
regions(15).P_APPROACH_LOW  = [16, -420, 34.50,  1.132, 2.962, -0.392];
regions(15).P_INSERT_FLAT   = [32, -399, 34.50,  1.132, 2.962, -0.392];
regions(15).P_ROTATE_LOCK   = [32, -399, 34.50,  0.929, 2.978, -0.227];
regions(15).P_LIFT_LOCKED   = [32, -399, 60.00,  0.929, 2.978, -0.227];

% R16
regions(16).name = "R16"; % _G7_H8
regions(16).baseSquare = "H8";
regions(16).approachDir = "[-1 -1 0]";
regions(16).Q_deg = [0, -117.7, -12.9, -138, 87.5, 126];
regions(16).P_APPROACH_HIGH = [178, -363, 102.00, 1.164, 2.854, 0.000];
regions(16).P_APPROACH_LOW  = [178, -363, 33.00,  1.186, 2.947, -0.391];
regions(16).P_INSERT_FLAT   = [197, -341, 33.00,  1.186, 2.947, -0.391];
regions(16).P_ROTATE_LOCK   = [197, -341, 33.00,  1.164, 2.854, 0.000];
regions(16).P_LIFT_LOCKED   = [197, -341, 53.00,  1.164, 2.854, 0.000];

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
