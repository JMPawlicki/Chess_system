function queenPickData = generateQueenPickData(queenParams, queenSlot)
%GENERATEQUEENPICKDATA Prepare points for picking the spare queen.
%
%   queenPickData = generateQueenPickData(queenParams)
%
%   Input:
%       queenParams - struct returned by robotQueenParams()
%
%   Output:
%       queenPickData - struct compatible with pick sequence appenders
%
%   Units:
%       Input P_* points: [X Y Z rx ry rz], XYZ in mm, orientation in rad
%       Output P_* points: [X Y Z rx ry rz], XYZ in m, orientation in rad
%
%   This function only prepares the pick trajectory from the queen storage.
%   It does not generate URScript and does not place the queen on the board.
%
% queenSlot:
%   "original" or "secondary"

    arguments
        queenParams struct
        queenSlot = ""
    end

    if strlength(string(queenSlot)) == 0
        queenSlot = queenParams.defaultSlot;
    end

    queenSlot = lower(string(queenSlot));

    if ~isfield(queenParams, "slots")
        error("generateQueenPickData:MissingSlots", ...
            "queenParams is missing required field: slots");
    end

    if ~isfield(queenParams.slots, char(queenSlot))
        error("generateQueenPickData:InvalidSlot", ...
            "Unknown queen slot: %s", queenSlot);
    end

    q = queenParams.slots.(char(queenSlot));

    requiredFields = [ ...
        "Q_QUEEN_HIGH", ...
        "P_QUEEN_APPROACH_HIGH", ...
        "P_QUEEN_APPROACH_LOW", ...
        "P_QUEEN_INSERT_FLAT", ...
        "P_QUEEN_LOCK", ...
        "P_QUEEN_LIFT_LOCKED", ...
        "P_QUEEN_EXIT_HIGH" ...
    ];

    for k = 1:numel(requiredFields)
        f = char(requiredFields(k));
        if ~isfield(q, f)
            error("generateQueenPickData:MissingField", ...
                "queen slot %s is missing required field: %s", ...
                queenSlot, f);
        end
    end

    queenPickData = struct();

    queenPickData.type = "queen_pick";
    queenPickData.slot = queenSlot;

    % Standard output fields expected by appendQueenPickToScript.m
    queenPickData.Q_HIGH = q.Q_QUEEN_HIGH;

    queenPickData.P_APPROACH_HIGH = xyzMmToM(q.P_QUEEN_APPROACH_HIGH);
    queenPickData.P_APPROACH_LOW  = xyzMmToM(q.P_QUEEN_APPROACH_LOW);
    queenPickData.P_INSERT_FLAT   = xyzMmToM(q.P_QUEEN_INSERT_FLAT);
    queenPickData.P_ROTATE_LOCK          = xyzMmToM(q.P_QUEEN_LOCK);
    queenPickData.P_LIFT_LOCKED   = xyzMmToM(q.P_QUEEN_LIFT_LOCKED);
    queenPickData.P_EXIT_HIGH     = xyzMmToM(q.P_QUEEN_EXIT_HIGH);

    % Optional aliases for readability/debugging
    queenPickData.Q_QUEEN_HIGH = queenPickData.Q_HIGH;

    queenPickData.P_QUEEN_APPROACH_HIGH = queenPickData.P_APPROACH_HIGH;
    queenPickData.P_QUEEN_APPROACH_LOW  = queenPickData.P_APPROACH_LOW;
    queenPickData.P_QUEEN_INSERT_FLAT   = queenPickData.P_INSERT_FLAT;
    queenPickData.P_QUEEN_ROTATE_LOCK   = queenPickData.P_ROTATE_LOCK;
    queenPickData.P_QUEEN_LIFT_LOCKED   = queenPickData.P_LIFT_LOCKED;
    queenPickData.P_QUEEN_EXIT_HIGH     = queenPickData.P_EXIT_HIGH;
end

function p = xyzMmToM(p)
    if ~isempty(p)
        p(1:3) = p(1:3) / 1000;
    end
end