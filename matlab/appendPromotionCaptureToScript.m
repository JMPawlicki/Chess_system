function script = appendPromotionCaptureToScript( ...
    script, fromSquare, toSquare, capturedPiece, ...
    regions, squareCenter, pieceParams, ...
    queenParams, binParams, motionParams, queenSlot)
%APPENDPROMOTIONCAPTURETOSCRIPT Append URScript for promotion with capture.
%
%   Sequence:
%   1. pick captured piece from toSquare and drop it to BIN
%   2. pick pawn from fromSquare and drop it to BIN
%   3. pick spare queen from queen storage
%   4. place queen on toSquare
%
%   fromSquare, toSquare are physical board squares, e.g. "E7", "F8".
%   capturedPiece is one of: "P", "N", "B", "R", "Q", "K".

    arguments
        script string
        fromSquare {mustBeTextScalar}
        toSquare {mustBeTextScalar}
        capturedPiece {mustBeTextScalar}
        regions struct
        squareCenter function_handle
        pieceParams struct
        queenParams struct
        binParams struct
        motionParams struct
        queenSlot = ""
    end

    if nargin < 11 || strlength(string(queenSlot)) == 0
        queenSlot = queenParams.defaultSlot;
    end

    fromSquare = upper(string(fromSquare));
    toSquare = upper(string(toSquare));
    capturedPiece = upper(string(capturedPiece));

    %% 1. Remove captured piece from target square

    capturedPickData = generatePickToBinData( ...
        toSquare, capturedPiece, ...
        regions, squareCenter, pieceParams);

    script = script + "  # PROMOTION CAPTURE - REMOVE CAPTURED PIECE" + newline;
    script = appendPickToBinToScript(script, capturedPickData, binParams, motionParams);

    %% 2. Remove promoting pawn from source square

    pawnPickData = generatePickToBinData( ...
        fromSquare, "P", ...
        regions, squareCenter, pieceParams);

    script = script + "  # PROMOTION CAPTURE - REMOVE PROMOTING PAWN" + newline;
    script = appendPickToBinToScript(script, pawnPickData, binParams, motionParams);

    %% 3. Pick spare queen from queen storage

    queenPickData = generateQueenPickData(queenParams, queenSlot);

    script = script + "  # PROMOTION CAPTURE - PICK SPARE QUEEN" + newline;
    script = appendQueenPickToScript(script, queenPickData, motionParams);

    %% 4. Place queen on target square

    % We only need the TO part of this moveData, but generateTransferData
    % gives us the same placement points as a normal queen transfer.
    queenPlaceData = generateTransferData( ...
        fromSquare, toSquare, "Q", ...
        regions, squareCenter, pieceParams);

    script = script + "  # PROMOTION CAPTURE - PLACE QUEEN" + newline;
    script = appendPlaceFromMoveDataToScript(script, queenPlaceData, motionParams);
end
