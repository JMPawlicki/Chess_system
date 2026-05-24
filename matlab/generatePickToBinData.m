function pickData = generatePickToBinData(squareName, pieceType, regions, squareCenter, pieceParams)
%GENERATEPICKTOBINDATA Generate points for picking one piece from a square.
%
%   pickData = generatePickToBinData(squareName, pieceType, regions, ...
%       squareCenter, pieceParams)
%
% Inputs:
%   squareName   - string/char, e.g. "D5"
%   pieceType    - string/char: "P", "N", "B", "R", "Q", "K"
%   regions      - output from robotRegions()
%   squareCenter - output from robotRegions()
%   pieceParams  - output from robotPieceParams()
%
% Units:
%   Region P_* input data: [X Y Z rx ry rz], XYZ in mm, rotation vector in rad
%   pickData P_* output data: [X Y Z rx ry rz], XYZ in metres, rotation vector in rad
%   Q_HIGH output data: radians
%
% Notes:
%   This function only generates the pick sequence points.
%   The actual bin motion is appended later by appendPickToBinToScript(...).

    squareName = upper(string(squareName));
    pieceType = upper(string(pieceType));

    validatePiece(pieceType, pieceParams);

    [fileIdx, rankIdx] = squareToIndex(squareName);

    %% Determine region

    regionIdx = squareToRegionIndex(fileIdx, rankIdx);
    R = regions(regionIdx);

    fprintf("\nPick to BIN %s from %s\n", pieceType, squareName);
    fprintf("Region: %s, baseSquare: %s\n", R.name, R.baseSquare);

    %% Compute delta relative to region base square

    [baseFileIdx, baseRankIdx] = squareToIndex(R.baseSquare);

    C_base = squareCenter(baseFileIdx, baseRankIdx);
    C_target = squareCenter(fileIdx, rankIdx);

    delta_mm = C_target - C_base;

    %% Generate points in mm

    Q_HIGH = deg2rad(R.Q_deg);

    P_APPROACH_HIGH = R.P_APPROACH_HIGH;
    P_APPROACH_LOW  = R.P_APPROACH_LOW;
    P_INSERT_FLAT   = R.P_INSERT_FLAT;
    P_ROTATE_LOCK   = R.P_ROTATE_LOCK;
    P_LIFT_LOCKED   = R.P_LIFT_LOCKED;

    if isfield(R, 'hasApproachMid') && R.hasApproachMid
        P_APPROACH_MID = R.P_APPROACH_MID;
    else
        P_APPROACH_MID = [];
    end

    P_APPROACH_HIGH(1:3) = P_APPROACH_HIGH(1:3) + delta_mm;
    P_APPROACH_LOW(1:3)  = P_APPROACH_LOW(1:3)  + delta_mm;
    P_INSERT_FLAT(1:3)   = P_INSERT_FLAT(1:3)   + delta_mm;
    P_ROTATE_LOCK(1:3)   = P_ROTATE_LOCK(1:3)   + delta_mm;
    P_LIFT_LOCKED(1:3)   = P_LIFT_LOCKED(1:3)   + delta_mm;

    if ~isempty(P_APPROACH_MID)
        P_APPROACH_MID(1:3) = P_APPROACH_MID(1:3) + delta_mm;
    end

    P_EXIT_HIGH = P_APPROACH_HIGH;

    %% Piece-specific correction

    if pieceParams.usePieceZCorrection
        pieceDeltaZ = pieceParams.pieceZ.(char(pieceType)) - ...
                      pieceParams.pieceZ.(char(pieceParams.basePiece));

        % Optional local region correction, e.g.:
        % regions(16).pieceZOffset.P = 1.5;
        if isfield(R, "pieceZOffset") && ...
           isfield(R.pieceZOffset, char(pieceType))

            pieceDeltaZ = pieceDeltaZ + R.pieceZOffset.(char(pieceType));
        end

        P_APPROACH_LOW(3) = P_APPROACH_LOW(3) + pieceDeltaZ;
        P_INSERT_FLAT(3)  = P_INSERT_FLAT(3)  + pieceDeltaZ;
        P_ROTATE_LOCK(3)  = P_ROTATE_LOCK(3)  + pieceDeltaZ;
        P_LIFT_LOCKED(3)  = P_LIFT_LOCKED(3)  + pieceDeltaZ;
    else
        pieceDeltaZ = 0;
    end

    if pieceParams.usePieceInsertScale
        scale = pieceParams.pieceInsertLen.(char(pieceType)) / ...
                pieceParams.pieceInsertLen.(char(pieceParams.basePiece));

        insertVec = P_INSERT_FLAT(1:2) - P_APPROACH_LOW(1:2);
        insertVecScaled = insertVec * scale;

        P_INSERT_FLAT(1:2) = P_APPROACH_LOW(1:2) + insertVecScaled;
        P_ROTATE_LOCK(1:2) = P_INSERT_FLAT(1:2);
        P_LIFT_LOCKED(1:2) = P_INSERT_FLAT(1:2);
    else
        scale = 1;
    end

    fprintf("pieceDeltaZ = %.2f mm\n", pieceDeltaZ);
    fprintf("insertScale = %.3f\n", scale);

    %% Convert XYZ mm -> m

    P_APPROACH_HIGH = xyzMmToM(P_APPROACH_HIGH);
    P_APPROACH_LOW  = xyzMmToM(P_APPROACH_LOW);
    P_INSERT_FLAT   = xyzMmToM(P_INSERT_FLAT);
    P_ROTATE_LOCK   = xyzMmToM(P_ROTATE_LOCK);
    P_LIFT_LOCKED   = xyzMmToM(P_LIFT_LOCKED);
    P_EXIT_HIGH     = xyzMmToM(P_EXIT_HIGH);

    if ~isempty(P_APPROACH_MID)
        P_APPROACH_MID = xyzMmToM(P_APPROACH_MID);
    end

    %% Return struct

    pickData = struct();

    pickData.type = "pick_to_bin";
    pickData.piece = pieceType;
    pickData.square = squareName;
    pickData.region = string(R.name);
    pickData.delta_mm = delta_mm;
    pickData.pieceDeltaZ = pieceDeltaZ;
    pickData.insertScale = scale;

    pickData.Q_HIGH = Q_HIGH;

    pickData.P_APPROACH_HIGH = P_APPROACH_HIGH;
    pickData.P_APPROACH_MID  = P_APPROACH_MID;
    pickData.P_APPROACH_LOW  = P_APPROACH_LOW;
    pickData.P_INSERT_FLAT   = P_INSERT_FLAT;
    pickData.P_ROTATE_LOCK   = P_ROTATE_LOCK;
    pickData.P_LIFT_LOCKED   = P_LIFT_LOCKED;
    pickData.P_EXIT_HIGH     = P_EXIT_HIGH;
end

%% Local helper functions

function [fileIdx, rankIdx] = squareToIndex(squareName)
    sq = char(upper(string(squareName)));

    if numel(sq) ~= 2
        error("Invalid square name: %s", squareName);
    end

    fileIdx = double(sq(1) - 'A');
    rankIdx = str2double(sq(2)) - 1;

    if fileIdx < 0 || fileIdx > 7 || rankIdx < 0 || rankIdx > 7
        error("Invalid square name: %s", squareName);
    end
end

function regionIdx = squareToRegionIndex(fileIdx, rankIdx)
    fileGroup = floor(fileIdx / 2);
    rankGroup = floor(rankIdx / 2);
    regionIdx = rankGroup * 4 + fileGroup + 1;
end

function p = xyzMmToM(p)
    if ~isempty(p)
        p(1:3) = p(1:3) / 1000;
    end
end

function validatePiece(piece, pieceParams)
    if ~isfield(pieceParams.pieceZ, char(piece))
        error("Unknown piece type: %s", piece);
    end
end
