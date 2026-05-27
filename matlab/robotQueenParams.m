function queenParams = robotQueenParams()
%ROBOTQUEENPARAMS Spare queen storage positions.

    queenParams = struct();
    queenParams.defaultSlot = "original";

    %% Original queen storage slot
    queenParams.slots.original = struct();

    queenParams.slots.original.Q_QUEEN_HIGH_deg = [-45, -102, -40, -125, 90, 0];
    queenParams.slots.original.Q_QUEEN_HIGH = deg2rad(queenParams.slots.original.Q_QUEEN_HIGH_deg);

    queenParams.slots.original.P_QUEEN_APPROACH_HIGH = [379, -532, 100, 0.852, -3.035, 0.180];
    queenParams.slots.original.P_QUEEN_APPROACH_LOW  = [379, -532, 47,  1.125, -3.020, 0.408];
    queenParams.slots.original.P_QUEEN_INSERT_FLAT   = [359, -511, 47, 1.125, -3.020, 0.408];
    queenParams.slots.original.P_QUEEN_LOCK          = [359, -511, 47, 0.852, -3.035, 0.180];
    queenParams.slots.original.P_QUEEN_LIFT_LOCKED   = [359, -511, 80, 0.852, -3.035, 0.180];
    queenParams.slots.original.P_QUEEN_EXIT_HIGH     = queenParams.slots.original.P_QUEEN_APPROACH_HIGH;

    %% Secondary queen storage slot
    queenParams.slots.secondary = struct();

    queenParams.slots.secondary.Q_QUEEN_HIGH_deg = [-45, -102, -40, -125, 90, 0];
    queenParams.slots.secondary.Q_QUEEN_HIGH = deg2rad(queenParams.slots.secondary.Q_QUEEN_HIGH_deg);

    queenParams.slots.secondary.P_QUEEN_APPROACH_HIGH = [379, -585, 100, 0.852, -3.035, 0.180];
    queenParams.slots.secondary.P_QUEEN_APPROACH_LOW  = [379, -585, 48,  1.125, -3.020, 0.408];
    queenParams.slots.secondary.P_QUEEN_INSERT_FLAT   = [359, -564, 48,  1.125, -3.020, 0.408];
    queenParams.slots.secondary.P_QUEEN_LOCK          = [359, -564, 48,  0.852, -3.035, 0.180];
    queenParams.slots.secondary.P_QUEEN_LIFT_LOCKED   = [359, -564, 80,  0.852, -3.035, 0.180];
    queenParams.slots.secondary.P_QUEEN_EXIT_HIGH     = queenParams.slots.secondary.P_QUEEN_APPROACH_HIGH;
end