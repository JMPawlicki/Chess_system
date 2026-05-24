function script = appendTransferToScript(script, moveData, motionParams)
%APPENDTRANSFERTOSCRIPT Append a complete pick-and-place transfer to URScript.
%
%   script = appendTransferToScript(script, moveData, motionParams)
%
% Inputs:
%   script       - string containing current URScript
%   moveData     - struct returned by generateTransferData(...)
%   motionParams - struct with fields:
%                  a_joint, v_joint, a_lin, v_lin
%
% Sequence:
%   FROM Q_HIGH
%   FROM APPROACH_HIGH
%   FROM APPROACH_MID, if available
%   FROM APPROACH_LOW
%   FROM INSERT_FLAT
%   FROM ROTATE_LOCK
%   FROM LIFT_LOCKED
%   FROM EXIT_HIGH
%   FROM Q_HIGH
%   TO Q_HIGH
%   TO APPROACH_HIGH
%   TO APPROACH_MID, if available
%   TO LIFT_LOCKED
%   TO ROTATE_LOCK
%   TO INSERT_FLAT
%   TO APPROACH_LOW
%   TO APPROACH_MID, if available
%   TO EXIT_HIGH
%   TO Q_HIGH
%
% Notes:
%   - moveData pose points must already have XYZ converted to metres.
%   - Q vectors must be in radians.
%   - This function does not add "def ...", HOME, "end", or function call.

    arguments
        script string
        moveData struct
        motionParams struct
    end

    a_joint = motionParams.a_joint;
    v_joint = motionParams.v_joint;
    a_lin   = motionParams.a_lin;
    v_lin   = motionParams.v_lin;

    %% Move to FROM region high

    script = appendMoveJ(script, moveData.Q_FROM_HIGH, a_joint, v_joint);
    script = script + "  sleep(0.1)" + newline;

    %% PICK - approach high

    script = appendMoveL(script, moveData.P_FROM_APPROACH_HIGH, a_lin, v_lin);

    %% PICK - optional approach mid

    if isfield(moveData, "P_FROM_APPROACH_MID") && ~isempty(moveData.P_FROM_APPROACH_MID)
        script = appendMoveL(script, moveData.P_FROM_APPROACH_MID, a_lin, v_lin);
    end

    %% PICK - approach low / insert / lock / lift

    script = appendMoveL(script, moveData.P_FROM_APPROACH_LOW,  a_lin, v_lin);
    script = appendMoveL(script, moveData.P_FROM_INSERT_FLAT,   a_lin, v_lin);
    script = appendMoveL(script, moveData.P_FROM_ROTATE_LOCK,   a_lin, v_lin);
    script = appendMoveL(script, moveData.P_FROM_LIFT_LOCKED,   a_lin, v_lin);

    %% PICK - exit high

    script = appendMoveL(script, moveData.P_FROM_EXIT_HIGH, a_lin, v_lin);

    %% Return to FROM region high

    script = appendMoveJ(script, moveData.Q_FROM_HIGH, a_joint, v_joint);
    script = script + "  sleep(0.1)" + newline;

    %% Move to TO region high

    script = appendMoveJ(script, moveData.Q_TO_HIGH, a_joint, v_joint);
    script = script + "  sleep(0.1)" + newline;

    %% PLACE - approach high

    script = appendMoveL(script, moveData.P_TO_APPROACH_HIGH, a_lin, v_lin);

    %% PLACE - optional approach mid while approaching

    if isfield(moveData, "P_TO_APPROACH_MID") && ~isempty(moveData.P_TO_APPROACH_MID)
        script = appendMoveL(script, moveData.P_TO_APPROACH_MID, a_lin, v_lin);
    end

    %% PLACE - lift / lower / unrotate / exit

    script = appendMoveL(script, moveData.P_TO_LIFT_LOCKED, a_lin, v_lin);
    script = appendMoveL(script, moveData.P_TO_ROTATE_LOCK, a_lin, v_lin);
    script = appendMoveL(script, moveData.P_TO_INSERT_FLAT, a_lin, v_lin);
    script = appendMoveL(script, moveData.P_TO_APPROACH_LOW, a_lin, v_lin);

    %% PLACE - optional approach mid while exiting

    if isfield(moveData, "P_TO_APPROACH_MID") && ~isempty(moveData.P_TO_APPROACH_MID)
        script = appendMoveL(script, moveData.P_TO_APPROACH_MID, a_lin, v_lin);
    end

    script = appendMoveL(script, moveData.P_TO_EXIT_HIGH, a_lin, v_lin);

    %% Return to TO region high

    script = appendMoveJ(script, moveData.Q_TO_HIGH, a_joint, v_joint);
    script = script + "  sleep(0.1)" + newline;
end
