function binParams = robotBinParams()
%ROBOTBINPARAMS Parameters for captured-piece disposal bin.
%
% Usage:
%   binParams = robotBinParams();
%
% Units:
%   Q_BIN_HIGH_deg  - joint angles in degrees
%   Q_BIN_HIGH      - joint angles in radians
%   P_BIN_DROP      - [X Y Z rx ry rz], XYZ in mm, orientation in radians
%
% Notes:
%   P_BIN_DROP is intentionally kept in mm here, the same convention as
%   region points. Functions that generate URScript should convert XYZ to m
%   immediately before sending movel(p[...]).

    binParams = struct();

    % Safe joint-space point above the disposal bin.
    binParams.Q_BIN_HIGH_deg = [-128, -93, -66, -108, 90, 0];
    binParams.Q_BIN_HIGH = deg2rad(binParams.Q_BIN_HIGH_deg);

    % Drop pose above/inside the bin.
    binParams.P_BIN_DROP = [-502, -451, 162, 1.185, 2.959, -0.883];

    % Optional aliases used by some scripts.
    binParams.Q_HIGH = binParams.Q_BIN_HIGH;
    binParams.P_DROP = binParams.P_BIN_DROP;
end
