function params = robotPieceParams()
%ROBOTPIECEPARAMS Piece-specific robot grasp parameters.
%
% Usage:
%   params = robotPieceParams();
%
% Units:
%   pieceZ        - millimetres, measured as the Z level for APPROACH_LOW /
%                   INSERT_FLAT / ROTATE_LOCK for each piece type.
%   pieceInsertXY - millimetres, reference insert offsets measured on A1.
%   pieceInsertLen- Euclidean length of pieceInsertXY, used for scaling
%                   insert vectors relative to the knight calibration.
%
% Piece names:
%   P - pawn
%   N - knight
%   B - bishop
%   R - rook
%   Q - queen
%   K - king

    params = struct();

    % Current regional trajectories were calibrated using the knight as the
    % reference piece, so Z corrections and insert scaling are relative to N.
    params.basePiece = "N";

    %% Piece Z levels [mm]
    params.pieceZ = struct();
    params.pieceZ.P = 56.0;
    params.pieceZ.N = 41.0;
    params.pieceZ.B = 63.2;
    params.pieceZ.R = 66.0;
    params.pieceZ.Q = 74.5;
    params.pieceZ.K = 78.0;

    %% Insert offsets measured on A1 [mm]
    params.pieceInsertXY = struct();
    params.pieceInsertXY.P = [13, 27];
    params.pieceInsertXY.N = [14, 14];
    params.pieceInsertXY.B = [18, 25];
    params.pieceInsertXY.R = [16, 20];
    params.pieceInsertXY.Q = [17, 25];
    params.pieceInsertXY.K = [15, 25];
    
    %% Place backoff correction [mm]
    % Used only when placing a piece on the target square.
    % Positive value means that the piece is placed slightly less deep
    % along the insert direction, so it ends up closer to the square center.
    
    params.placeBackoff.P = 5.5;
    params.placeBackoff.N = 6.0;
    params.placeBackoff.B = 5.0;
    params.placeBackoff.R = 8.0;
    params.placeBackoff.Q = 7.0;
    params.placeBackoff.K = 7.5;

    %% Insert vector lengths [mm]
    params.pieceInsertLen = struct();
    params.pieceInsertLen.P = norm(params.pieceInsertXY.P);
    params.pieceInsertLen.N = norm(params.pieceInsertXY.N);
    params.pieceInsertLen.B = norm(params.pieceInsertXY.B);
    params.pieceInsertLen.R = norm(params.pieceInsertXY.R);
    params.pieceInsertLen.Q = norm(params.pieceInsertXY.Q);
    params.pieceInsertLen.K = norm(params.pieceInsertXY.K);

    %% Optional defaults for motion generation
    params.usePieceZCorrection = true;
    params.usePieceInsertScale = true;

    %% Allowed pieces, useful for validation
    params.allowedPieces = ["P", "N", "B", "R", "Q", "K"];
end
