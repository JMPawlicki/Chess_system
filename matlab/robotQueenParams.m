function queenParams = robotQueenParams()
%ROBOTQUEENPARAMS Spare queen storage positions.

    queenParams = struct();
    queenParams.defaultSlot = "original";

    %% Original queen storage slot
    queenParams.slots.original = struct();

    queenParams.slots.original.Q_QUEEN_HIGH_deg = [-45, -102, -40, -125, 90, 0];
    queenParams.slots.original.Q_QUEEN_HIGH = deg2rad(queenParams.slots.original.Q_QUEEN_HIGH_deg);

    queenParams.slots.original.P_QUEEN_APPROACH_HIGH = [383, -534, 100, 0.852, -3.035, 0.180];
    queenParams.slots.original.P_QUEEN_APPROACH_LOW  = [390, -532, 47,  1.125, -3.020, 0.408];
    queenParams.slots.original.P_QUEEN_INSERT_FLAT   = [366.7, -508.5, 47, 1.125, -3.020, 0.408];
    queenParams.slots.original.P_QUEEN_LOCK          = [366.7, -508.5, 47, 0.852, -3.035, 0.180];
    queenParams.slots.original.P_QUEEN_LIFT_LOCKED   = [366.7, -508.5, 80, 0.852, -3.035, 0.180];
    queenParams.slots.original.P_QUEEN_EXIT_HIGH     = queenParams.slots.original.P_QUEEN_APPROACH_HIGH;

    %% Secondary queen storage slot
    queenParams.slots.secondary = struct();

    queenParams.slots.secondary.Q_QUEEN_HIGH_deg = [-45, -102, -40, -125, 90, 0];
    queenParams.slots.secondary.Q_QUEEN_HIGH = deg2rad(queenParams.slots.secondary.Q_QUEEN_HIGH_deg);

    queenParams.slots.secondary.P_QUEEN_APPROACH_HIGH = [394, -584, 100, 0.852, -3.035, 0.180];
    queenParams.slots.secondary.P_QUEEN_APPROACH_LOW  = [394, -584, 48,  1.125, -3.020, 0.408];
    queenParams.slots.secondary.P_QUEEN_INSERT_FLAT   = [370, -558, 48,  1.125, -3.020, 0.408];
    queenParams.slots.secondary.P_QUEEN_LOCK          = [370, -558, 48,  0.852, -3.035, 0.180];
    queenParams.slots.secondary.P_QUEEN_LIFT_LOCKED   = [366, -558, 80,  0.852, -3.035, 0.180];
    queenParams.slots.secondary.P_QUEEN_EXIT_HIGH     = queenParams.slots.secondary.P_QUEEN_APPROACH_HIGH;
end