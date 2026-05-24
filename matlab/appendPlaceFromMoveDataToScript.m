function script = appendPlaceFromMoveDataToScript(script, moveData, motionParams)
%APPENDPLACEFROMMOVEDATATOSCRIPT Append only the PLACE part of a transfer.
%
%   This is used when the robot is already holding a piece and only needs
%   to place it on the target square. Example: promotion after picking the
%   spare queen from storage.
%
%   moveData should be created by generateTransferData(fromSquare,toSquare,...)
%   or by a similar helper. Only the TO-side fields are used.
%
%   Required moveData fields:
%       Q_TO_HIGH
%       P_TO_APPROACH_HIGH
%       P_TO_APPROACH_MID
%       P_TO_LIFT_LOCKED
%       P_TO_ROTATE_LOCK
%       P_TO_INSERT_FLAT
%       P_TO_APPROACH_LOW
%       P_TO_EXIT_HIGH

    arguments
        script string
        moveData struct
        motionParams struct
    end

    a_joint = motionParams.a_joint;
    v_joint = motionParams.v_joint;
    a_lin   = motionParams.a_lin;
    v_lin   = motionParams.v_lin;

    %% Move to TO region high

    script = appendMoveJ(script, moveData.Q_TO_HIGH, a_joint, v_joint);

    %% PLACE - approach high

    script = appendMoveL(script, moveData.P_TO_APPROACH_HIGH, a_lin, v_lin);

    %% PLACE - optional approach mid while approaching

    if isfield(moveData, "P_TO_APPROACH_MID") && ~isempty(moveData.P_TO_APPROACH_MID)
        script = appendMoveL(script, moveData.P_TO_APPROACH_MID, a_lin, v_lin);
    end

    %% PLACE - lower and release sequence

    script = appendMoveL(script, moveData.P_TO_LIFT_LOCKED, a_lin, v_lin);
    script = appendMoveL(script, moveData.P_TO_ROTATE_LOCK, a_lin, v_lin);
    script = appendMoveL(script, moveData.P_TO_INSERT_FLAT, a_lin, v_lin);
    script = appendMoveL(script, moveData.P_TO_APPROACH_LOW, a_lin, v_lin);

    %% PLACE - optional approach mid while exiting

    if isfield(moveData, "P_TO_APPROACH_MID") && ~isempty(moveData.P_TO_APPROACH_MID)
        script = appendMoveL(script, moveData.P_TO_APPROACH_MID, a_lin, v_lin);
    end

    %% PLACE - exit high and return to region high

    script = appendMoveL(script, moveData.P_TO_EXIT_HIGH, a_lin, v_lin);
    script = appendMoveJ(script, moveData.Q_TO_HIGH, a_joint, v_joint);
end
