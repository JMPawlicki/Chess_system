function moveData = generateTransferData(fromSquare, toSquare, movingPiece, regions, squareCenter, pieceParams)
%GENERATETRANSFERDATA Generate all points needed for one piece transfer.
%
%   moveData = generateTransferData(fromSquare, toSquare, movingPiece, ...
%       regions, squareCenter, pieceParams)
%
% Inputs:
%   fromSquare   - string/char, e.g. "E2"
%   toSquare     - string/char, e.g. "E4"
%   movingPiece  - string/char: "P", "N", "B", "R", "Q", "K"
%   regions      - output from robotRegions()
%   squareCenter - output from robotRegions()
%   pieceParams  - output from robotPieceParams()
%
% Units:
%   Region P_* input data: [X Y Z rx ry rz], XYZ in mm, rotation vector in rad
%   moveData P_* output data: [X Y Z rx ry rz], XYZ in meters, rotation vector in rad
%   Q_* output data: radians
%
% Notes:
%   This function does not send anything to the robot.
%   It only generates the trajectory points for:
%       pick from fromSquare
%       place on toSquare

    fromSquare = upper(string(fromSquare));
    toSquare = upper(string(toSquare));
    movingPiece = upper(string(movingPiece));

    validatePiece(movingPiece, pieceParams);

    [fromFileIdx, fromRankIdx] = squareToIndex(fromSquare);
    [toFileIdx, toRankIdx] = squareToIndex(toSquare);

    %% Determine FROM / TO regions

    fromRegionIdx = squareToRegionIndex(fromFileIdx, fromRankIdx);
    toRegionIdx = squareToRegionIndex(toFileIdx, toRankIdx);

    R_from = regions(fromRegionIdx);
    R_to = regions(toRegionIdx);

    fprintf("\nTransfer %s: %s -> %s\n", movingPiece, fromSquare, toSquare);
    fprintf("FROM region: %s, baseSquare: %s\n", R_from.name, R_from.baseSquare);
    fprintf("TO region:   %s, baseSquare: %s\n", R_to.name, R_to.baseSquare);

    %% Compute delta FROM relative to region base square

    [baseFromFileIdx, baseFromRankIdx] = squareToIndex(R_from.baseSquare);

    C_from_base = squareCenter(baseFromFileIdx, baseFromRankIdx);
    C_from = squareCenter(fromFileIdx, fromRankIdx);

    delta_from_mm = C_from - C_from_base;

    %% Compute delta TO relative to region base square

    [baseToFileIdx, baseToRankIdx] = squareToIndex(R_to.baseSquare);

    C_to_base = squareCenter(baseToFileIdx, baseToRankIdx);
    C_to = squareCenter(toFileIdx, toRankIdx);

    delta_to_mm = C_to - C_to_base;

    %% Generate FROM points in mm

    Q_FROM_HIGH = deg2rad(R_from.Q_deg);

    P_FROM_APPROACH_HIGH = R_from.P_APPROACH_HIGH;
    P_FROM_APPROACH_LOW  = R_from.P_APPROACH_LOW;
    P_FROM_INSERT_FLAT   = R_from.P_INSERT_FLAT;
    P_FROM_ROTATE_LOCK   = R_from.P_ROTATE_LOCK;
    P_FROM_LIFT_LOCKED   = R_from.P_LIFT_LOCKED;

    if isfield(R_from, 'hasApproachMid') && R_from.hasApproachMid
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

    %% Generate TO points in mm

    Q_TO_HIGH = deg2rad(R_to.Q_deg);

    P_TO_APPROACH_HIGH = R_to.P_APPROACH_HIGH;
    P_TO_APPROACH_LOW  = R_to.P_APPROACH_LOW;
    P_TO_INSERT_FLAT   = R_to.P_INSERT_FLAT;
    P_TO_ROTATE_LOCK   = R_to.P_ROTATE_LOCK;
    P_TO_LIFT_LOCKED   = R_to.P_LIFT_LOCKED;

    if isfield(R_to, 'hasApproachMid') && R_to.hasApproachMid
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

    %% Piece-specific correction

    if pieceParams.usePieceZCorrection
        baseDeltaZ = pieceParams.pieceZ.(char(movingPiece)) - ...
                     pieceParams.pieceZ.(char(pieceParams.basePiece));

        pieceDeltaZFrom = baseDeltaZ;
        pieceDeltaZTo   = baseDeltaZ;

        % Optional local FROM region correction
        if isfield(R_from, "pieceZOffset") && ...
        isfield(R_from.pieceZOffset, char(movingPiece))

            pieceDeltaZFrom = pieceDeltaZFrom + ...
                R_from.pieceZOffset.(char(movingPiece));
        end

        % Optional local TO region correction
        if isfield(R_to, "pieceZOffset") && ...
            isfield(R_to.pieceZOffset, char(movingPiece))

            pieceDeltaZTo = pieceDeltaZTo + ...
                R_to.pieceZOffset.(char(movingPiece));
        end

        % FROM - picking moving piece
        P_FROM_APPROACH_LOW(3) = P_FROM_APPROACH_LOW(3) + pieceDeltaZFrom;
        P_FROM_INSERT_FLAT(3)  = P_FROM_INSERT_FLAT(3)  + pieceDeltaZFrom;
        P_FROM_ROTATE_LOCK(3)  = P_FROM_ROTATE_LOCK(3)  + pieceDeltaZFrom;
        P_FROM_LIFT_LOCKED(3)  = P_FROM_LIFT_LOCKED(3)  + pieceDeltaZFrom;

        % TO - placing moving piece
        P_TO_APPROACH_LOW(3) = P_TO_APPROACH_LOW(3) + pieceDeltaZTo;
        P_TO_INSERT_FLAT(3)  = P_TO_INSERT_FLAT(3)  + pieceDeltaZTo;
        P_TO_ROTATE_LOCK(3)  = P_TO_ROTATE_LOCK(3)  + pieceDeltaZTo;
        P_TO_LIFT_LOCKED(3)  = P_TO_LIFT_LOCKED(3)  + pieceDeltaZTo;

    else
        pieceDeltaZFrom = 0;
        pieceDeltaZTo   = 0;
    end

    if pieceParams.usePieceInsertScale
        scale = pieceParams.pieceInsertLen.(char(movingPiece)) / ...
                pieceParams.pieceInsertLen.(char(pieceParams.basePiece));

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
    else
        scale = 1;
    end

    %% Place-specific backoff correction
    % This correction is applied only when placing the piece on the target square.
    % It moves the final placing position slightly backwards along the insert
    % direction, so the piece is not left too far forward on the square.
    
    placeBackoff_mm = 0;
    
    if isfield(pieceParams, "placeBackoff") && ...
       isfield(pieceParams.placeBackoff, char(movingPiece))
    
        placeBackoff_mm = pieceParams.placeBackoff.(char(movingPiece));
    end
    
    toPlaceVec = P_TO_INSERT_FLAT(1:2) - P_TO_APPROACH_LOW(1:2);
    
    if placeBackoff_mm ~= 0 && norm(toPlaceVec) > 1e-6
    
        toPlaceDir = toPlaceVec / norm(toPlaceVec);
    
        P_TO_INSERT_FLAT(1:2) = P_TO_INSERT_FLAT(1:2) - placeBackoff_mm * toPlaceDir;
        P_TO_ROTATE_LOCK(1:2) = P_TO_INSERT_FLAT(1:2);
        P_TO_LIFT_LOCKED(1:2) = P_TO_INSERT_FLAT(1:2);
    end
    fprintf("pieceDeltaZFrom = %.2f mm\n", pieceDeltaZFrom);
    fprintf("pieceDeltaZTo = %.2f mm\n", pieceDeltaZTo);
    fprintf("insertScale = %.3f\n", scale);
    fprintf("placeBackoff = %.2f mm\n", placeBackoff_mm);
    %% Convert XYZ mm -> m

    P_FROM_APPROACH_HIGH = xyzMmToM(P_FROM_APPROACH_HIGH);
    P_FROM_APPROACH_LOW  = xyzMmToM(P_FROM_APPROACH_LOW);
    P_FROM_INSERT_FLAT   = xyzMmToM(P_FROM_INSERT_FLAT);
    P_FROM_ROTATE_LOCK   = xyzMmToM(P_FROM_ROTATE_LOCK);
    P_FROM_LIFT_LOCKED   = xyzMmToM(P_FROM_LIFT_LOCKED);
    P_FROM_EXIT_HIGH     = xyzMmToM(P_FROM_EXIT_HIGH);

    if ~isempty(P_FROM_APPROACH_MID)
        P_FROM_APPROACH_MID = xyzMmToM(P_FROM_APPROACH_MID);
    end

    P_TO_APPROACH_HIGH = xyzMmToM(P_TO_APPROACH_HIGH);
    P_TO_APPROACH_LOW  = xyzMmToM(P_TO_APPROACH_LOW);
    P_TO_INSERT_FLAT   = xyzMmToM(P_TO_INSERT_FLAT);
    P_TO_ROTATE_LOCK   = xyzMmToM(P_TO_ROTATE_LOCK);
    P_TO_LIFT_LOCKED   = xyzMmToM(P_TO_LIFT_LOCKED);
    P_TO_EXIT_HIGH     = xyzMmToM(P_TO_EXIT_HIGH);

    if ~isempty(P_TO_APPROACH_MID)
        P_TO_APPROACH_MID = xyzMmToM(P_TO_APPROACH_MID);
    end

    %% Return struct

    moveData = struct();

    moveData.type = "transfer";
    moveData.piece = movingPiece;
    moveData.fromSquare = fromSquare;
    moveData.toSquare = toSquare;

    moveData.fromRegion = string(R_from.name);
    moveData.toRegion = string(R_to.name);

    moveData.delta_from_mm = delta_from_mm;
    moveData.delta_to_mm = delta_to_mm;

    moveData.pieceDeltaZFrom = pieceDeltaZFrom;
    moveData.pieceDeltaZTo = pieceDeltaZTo;
    moveData.insertScale = scale;
    moveData.placeBackoff = placeBackoff_mm;
    
    moveData.Q_FROM_HIGH = Q_FROM_HIGH;
    moveData.Q_TO_HIGH   = Q_TO_HIGH;

    moveData.P_FROM_APPROACH_HIGH = P_FROM_APPROACH_HIGH;
    moveData.P_FROM_APPROACH_MID  = P_FROM_APPROACH_MID;
    moveData.P_FROM_APPROACH_LOW  = P_FROM_APPROACH_LOW;
    moveData.P_FROM_INSERT_FLAT   = P_FROM_INSERT_FLAT;
    moveData.P_FROM_ROTATE_LOCK   = P_FROM_ROTATE_LOCK;
    moveData.P_FROM_LIFT_LOCKED   = P_FROM_LIFT_LOCKED;
    moveData.P_FROM_EXIT_HIGH     = P_FROM_EXIT_HIGH;

    moveData.P_TO_APPROACH_HIGH = P_TO_APPROACH_HIGH;
    moveData.P_TO_APPROACH_MID  = P_TO_APPROACH_MID;
    moveData.P_TO_APPROACH_LOW  = P_TO_APPROACH_LOW;
    moveData.P_TO_INSERT_FLAT   = P_TO_INSERT_FLAT;
    moveData.P_TO_ROTATE_LOCK   = P_TO_ROTATE_LOCK;
    moveData.P_TO_LIFT_LOCKED   = P_TO_LIFT_LOCKED;
    moveData.P_TO_EXIT_HIGH     = P_TO_EXIT_HIGH;
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
