function sqOut = mapLogicalToPhysicalSquare(sqIn, boardRotated180)
%MAPLOGICALTOPHYSICALSQUARE Map chess logical square to physical board square.
%
%   sqOut = mapLogicalToPhysicalSquare(sqIn, boardRotated180)
%
%   sqIn can be string or char, for example "E2" or 'e2'.
%
%   boardRotated180 = false:
%       Logical square is equal to physical square.
%       Example: E2 -> E2
%
%   boardRotated180 = true:
%       Board is physically rotated 180 degrees relative to the robot
%       calibration, so square names are mirrored.
%       Example: E2 -> D7, A1 -> H8, H8 -> A1
%
%   Output is always an uppercase MATLAB string.

    arguments
        sqIn
        boardRotated180 (1,1) logical
    end

    sq = char(upper(string(sqIn)));
    sq = strtrim(sq);

    if numel(sq) ~= 2
        error("mapLogicalToPhysicalSquare:InvalidSquare", ...
            "Square must have exactly 2 characters, e.g. 'E2'. Got: %s", sq);
    end

    fileIdx = double(sq(1) - 'A');      % A=0 ... H=7
    rankIdx = str2double(sq(2)) - 1;    % 1=0 ... 8=7

    if fileIdx < 0 || fileIdx > 7 || isnan(rankIdx) || rankIdx < 0 || rankIdx > 7
        error("mapLogicalToPhysicalSquare:InvalidSquare", ...
            "Invalid chess square: %s", sq);
    end

    if ~boardRotated180
        sqOut = string(sq);
        return;
    end

    fileIdxRot = 7 - fileIdx;
    rankIdxRot = 7 - rankIdx;

    fileCharRot = char('A' + fileIdxRot);
    rankCharRot = char('1' + rankIdxRot);

    sqOut = string([fileCharRot rankCharRot]);
end
