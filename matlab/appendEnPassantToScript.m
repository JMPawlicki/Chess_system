function script = appendEnPassantToScript( ...
    script, fromSquare, toSquare, capturedSquare, ...
    regions, squareCenter, pieceParams, ...
    binParams, motionParams)
%APPENDENPASSANTTOSCRIPT Append URScript sequence for en passant.
%
%   En passant is executed as:
%   1. Pick captured pawn from capturedSquare and drop it to BIN.
%   2. Transfer moving pawn from fromSquare to toSquare.
%
%   Inputs:
%       fromSquare      - logical/physical square already mapped for robot, e.g. "E5"
%       toSquare        - destination square, e.g. "D6"
%       capturedSquare  - square of captured pawn, e.g. "D5"
%
%   All square names passed to this function should already be PHYSICAL
%   robot square names if board rotation mapping is used.

    arguments
        script string
        fromSquare {mustBeTextScalar}
        toSquare {mustBeTextScalar}
        capturedSquare {mustBeTextScalar}
        regions struct
        squareCenter function_handle
        pieceParams struct
        binParams struct
        motionParams struct
    end

    % In en passant both the moving and captured pieces are pawns.
    capturedPawnData = generatePickToBinData( ...
        string(capturedSquare), "P", ...
        regions, squareCenter, pieceParams);

    movingPawnData = generateTransferData( ...
        string(fromSquare), string(toSquare), "P", ...
        regions, squareCenter, pieceParams);

    script = script + "  # EN PASSANT - remove captured pawn" + newline;
    script = appendPickToBinToScript(script, capturedPawnData, binParams, motionParams);

    script = script + "  # EN PASSANT - move pawn" + newline;
    script = appendTransferToScript(script, movingPawnData, motionParams);
end
