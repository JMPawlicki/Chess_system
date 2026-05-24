function script = appendPromotionToScript(script, fromSquare, toSquare, regions, squareCenter, pieceParams, queenParams, binParams, motionParams, queenSlot)
%APPENDPROMOTIONTOSCRIPT Append URScript sequence for robot queen promotion.
%
%   script = appendPromotionToScript(script, fromSquare, toSquare, ...)
%
%   Promotion without capture is executed as:
%       1. pick pawn from fromSquare and drop it to BIN
%       2. pick spare queen from queen storage
%       3. place queen on toSquare
%
%   This matches the physical strategy where the pawn is not placed on the
%   promotion square first.
%
%   Inputs:
%       script       - current URScript string
%       fromSquare   - pawn square, e.g. "E7"
%       toSquare     - promotion square, e.g. "E8"
%       regions      - from robotRegions()
%       squareCenter - from robotRegions()
%       pieceParams  - from robotPieceParams()
%       queenParams  - from robotQueenParams()
%       binParams    - from robotBinParams()
%       motionParams - from robotMotionParams()

    arguments
        script string
        fromSquare {mustBeTextScalar}
        toSquare {mustBeTextScalar}
        regions struct
        squareCenter function_handle
        pieceParams struct
        queenParams struct
        binParams struct
        motionParams struct
        queenSlot = ""
    end
    
    if nargin < 10 || strlength(string(queenSlot)) == 0
        queenSlot = queenParams.defaultSlot;
    end    

    fromSquare = upper(string(fromSquare));
    toSquare   = upper(string(toSquare));

    %% 1. Remove promoted pawn from its original square

    script = script + "  # PROMOTION - remove pawn from original square" + newline;

    pawnPickData = generatePickToBinData( ...
        fromSquare, "P", ...
        regions, squareCenter, pieceParams);

    script = appendPickToBinToScript(script, pawnPickData, binParams, motionParams);

    %% 2. Pick spare queen from storage

    script = script + "  # PROMOTION - pick spare queen from storage" + newline;

    queenPickData = generateQueenPickData(queenParams, queenSlot);
    script = appendQueenPickToScript(script, queenPickData, motionParams);

    %% 3. Place spare queen on promotion square

    script = script + "  # PROMOTION - place queen on promotion square" + newline;

    % generateTransferData needs both from/to squares, but appendPlaceFromMoveDataToScript
    % only uses the TO-side fields. fromSquare is passed only to keep the helper interface
    % consistent.
    placeQueenData = generateTransferData( ...
        fromSquare, toSquare, "Q", ...
        regions, squareCenter, pieceParams);

    script = appendPlaceFromMoveDataToScript(script, placeQueenData, motionParams);
end
