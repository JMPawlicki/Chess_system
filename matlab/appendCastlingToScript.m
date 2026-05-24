function script = appendCastlingToScript( ...
    script, kingFromSquare, kingToSquare, rookFromSquare, rookToSquare, ...
    regions, squareCenter, pieceParams, motionParams)
%APPENDCASTLINGTOSCRIPT Append castling sequence to URScript.
%
%   Castling is executed as two standard transfers:
%   1. King transfer: kingFromSquare -> kingToSquare, piece "K"
%   2. Rook transfer: rookFromSquare -> rookToSquare, piece "R"
%
%   Inputs:
%       script          - existing URScript string
%       kingFromSquare  - e.g. "E1"
%       kingToSquare    - e.g. "G1"
%       rookFromSquare  - e.g. "H1"
%       rookToSquare    - e.g. "F1"
%       regions         - from robotRegions()
%       squareCenter    - from robotRegions()
%       pieceParams     - from robotPieceParams()
%       motionParams    - from robotMotionParams()
%
%   Example:
%       script = appendCastlingToScript(script, "E1", "G1", "H1", "F1", ...
%           regions, squareCenter, pieceParams, motionParams);

    arguments
        script string
        kingFromSquare string
        kingToSquare string
        rookFromSquare string
        rookToSquare string
        regions struct
        squareCenter function_handle
        pieceParams struct
        motionParams struct
    end

    kingFromSquare = upper(strtrim(kingFromSquare));
    kingToSquare   = upper(strtrim(kingToSquare));
    rookFromSquare = upper(strtrim(rookFromSquare));
    rookToSquare   = upper(strtrim(rookToSquare));

    fprintf("CASTLING SCRIPT\n");
    fprintf("King: %s -> %s\n", kingFromSquare, kingToSquare);
    fprintf("Rook: %s -> %s\n", rookFromSquare, rookToSquare);

    kingMoveData = generateTransferData( ...
        kingFromSquare, kingToSquare, "K", ...
        regions, squareCenter, pieceParams);

    rookMoveData = generateTransferData( ...
        rookFromSquare, rookToSquare, "R", ...
        regions, squareCenter, pieceParams);

    script = script + "  # CASTLING - KING TRANSFER" + newline;
    script = appendTransferToScript(script, kingMoveData, motionParams);

    script = script + "  # CASTLING - ROOK TRANSFER" + newline;
    script = appendTransferToScript(script, rookMoveData, motionParams);
end
