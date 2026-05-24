function script = executeRobotMove(info, boardRotated180, regions, squareCenter, pieceParams, motionParams, binParams, queenParams, useHome)
%EXECUTEROBOTMOVE Build a full URScript for one robot move described by Python.
%
%   script = executeRobotMove(info, boardRotated180, regions, squareCenter,
%       pieceParams, motionParams, binParams, queenParams)
%
%   info is the struct parsed from a ROBOT_MOVE message, for example:
%       info.type      = "normal" / "capture" / "en_passant" /
%                        "castle_kingside" / "castle_queenside" /
%                        "promotion" / "promotion_capture"
%       info.from      = "e7"
%       info.to        = "e8"
%       info.piece     = "P"
%       info.captured  = "R" or "none"
%       info.ep        = "d5" or "none"
%       info.rook_from = "h1" or "none"
%       info.rook_to   = "f1" or "none"
%
%   boardRotated180 indicates whether logical chess squares must be mapped
%   to physical robot squares.
%
%   This function only BUILDS the script. It does not send it to UR3.

    arguments
        info struct
        boardRotated180 logical
        regions struct
        squareCenter function_handle
        pieceParams struct
        motionParams struct
        binParams struct
        queenParams struct
        useHome logical = true
    end

    moveType = lower(getInfoString(info, "type", "normal"));
    movingPiece = upper(getInfoString(info, "piece", "P"));

    if movingPiece == "KING"
        movingPiece = "K";
    end

    script = "";
    script = script + "def robot_move_sequence():" + newline;
    
    if useHome
        % Start from HOME / safe neutral joint pose.
        script = appendMoveJ(script, motionParams.Q_HOME, ...
            motionParams.a_joint, motionParams.v_joint);
    end

    switch moveType
        case "normal"
            fromSquare = mapLogicalToPhysicalSquare(getInfoString(info, "from", ""), boardRotated180);
            toSquare   = mapLogicalToPhysicalSquare(getInfoString(info, "to", ""), boardRotated180);

            moveData = generateTransferData(fromSquare, toSquare, movingPiece, ...
                regions, squareCenter, pieceParams);

            script = appendTransferToScript(script, moveData, motionParams);

        case "capture"
            fromSquare = mapLogicalToPhysicalSquare(getInfoString(info, "from", ""), boardRotated180);
            toSquare   = mapLogicalToPhysicalSquare(getInfoString(info, "to", ""), boardRotated180);

            capturedPiece = upper(getInfoString(info, "captured", "P"));
            capturedPiece = normalizePieceName(capturedPiece);

            % Remove captured piece from target square.
            pickData = generatePickToBinData(toSquare, capturedPiece, ...
                regions, squareCenter, pieceParams);
            script = appendPickToBinToScript(script, pickData, binParams, motionParams);

            % Move attacking piece to target square.
            moveData = generateTransferData(fromSquare, toSquare, movingPiece, ...
                regions, squareCenter, pieceParams);
            script = appendTransferToScript(script, moveData, motionParams);

        case "en_passant"
            fromSquare = mapLogicalToPhysicalSquare(getInfoString(info, "from", ""), boardRotated180);
            toSquare   = mapLogicalToPhysicalSquare(getInfoString(info, "to", ""), boardRotated180);

            epSquareLogical = getInfoString(info, "ep", "none");
            if epSquareLogical == "none"
                epSquareLogical = getInfoString(info, "capture", "");
            end
            capturedSquare = mapLogicalToPhysicalSquare(epSquareLogical, boardRotated180);

            script = appendEnPassantToScript(script, fromSquare, toSquare, capturedSquare, ...
                regions, squareCenter, pieceParams, binParams, motionParams);

        case {"castle_kingside", "castle_queenside"}
            kingFrom = mapLogicalToPhysicalSquare(getInfoString(info, "from", ""), boardRotated180);
            kingTo   = mapLogicalToPhysicalSquare(getInfoString(info, "to", ""), boardRotated180);

            rookFrom = mapLogicalToPhysicalSquare(getInfoString(info, "rook_from", ""), boardRotated180);
            rookTo   = mapLogicalToPhysicalSquare(getInfoString(info, "rook_to", ""), boardRotated180);

            script = appendCastlingToScript(script, kingFrom, kingTo, rookFrom, rookTo, ...
                regions, squareCenter, pieceParams, motionParams);

        case "promotion"
            queenSlot = chooseQueenSlot(info.piece_color, boardRotated180);

            if ~isfield(queenParams.slots, char(queenSlot))
                queenSlot = queenParams.defaultSlot;
            end

            fromSquare = mapLogicalToPhysicalSquare(getInfoString(info, "from", ""), boardRotated180);
            toSquare   = mapLogicalToPhysicalSquare(getInfoString(info, "to", ""), boardRotated180);

            script = appendPromotionToScript(script, fromSquare, toSquare, ...
                regions, squareCenter, pieceParams, queenParams, binParams, motionParams, queenSlot);

        case "promotion_capture"
            queenSlot = chooseQueenSlot(info.piece_color, boardRotated180);

            if ~isfield(queenParams.slots, char(queenSlot))
                queenSlot = queenParams.defaultSlot;
            end

            fromSquare = mapLogicalToPhysicalSquare(getInfoString(info, "from", ""), boardRotated180);
            toSquare   = mapLogicalToPhysicalSquare(getInfoString(info, "to", ""), boardRotated180);

            capturedPiece = upper(getInfoString(info, "captured", "P"));
            capturedPiece = normalizePieceName(capturedPiece);

            script = appendPromotionCaptureToScript(script, fromSquare, toSquare, capturedPiece, ...
                regions, squareCenter, pieceParams, queenParams, binParams, motionParams, queenSlot);

        otherwise
            error("executeRobotMove:UnknownMoveType", ...
                "Unknown robot move type: %s", moveType);
    end
    
    % Robot is already in safe high position after completing the move.
    % Notify backend that the physical move is finished.
    commParams = robotCommParams();
    script = appendRobotDoneSignalToScript(script, commParams);

    % Return HOME only in human-vs-robot / safe operation.
    if useHome
        script = appendMoveJ(script, motionParams.Q_HOME, ...
            motionParams.a_joint, motionParams.v_joint);
    end
    
    script = script + "end" + newline;
    script = script + "robot_move_sequence()" + newline;
end

function value = getInfoString(info, fieldName, defaultValue)
%GETINFOSTRING Read a field from info as string with a default.

    fieldName = char(fieldName);

    if isfield(info, fieldName)
        value = string(info.(fieldName));
    else
        value = string(defaultValue);
    end

    if strlength(value) == 0
        value = string(defaultValue);
    end
end

function piece = normalizePieceName(piece)
%NORMALIZEPIECENAME Normalize possible long piece names to P/N/B/R/Q/K.

    piece = upper(string(piece));

    switch piece
        case {"PAWN", "P"}
            piece = "P";
        case {"KNIGHT", "N"}
            piece = "N";
        case {"BISHOP", "B"}
            piece = "B";
        case {"ROOK", "R"}
            piece = "R";
        case {"QUEEN", "Q"}
            piece = "Q";
        case {"KING", "K"}
            piece = "K";
        otherwise
            error("executeRobotMove:UnknownPiece", "Unknown piece type: %s", piece);
    end
end
