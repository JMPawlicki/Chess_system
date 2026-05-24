function script = appendMoveJ(script, q, a_joint, v_joint)
%APPENDMOVEJ Append one URScript movej command.
%
%   q must be [q1 q2 q3 q4 q5 q6] in radians.

    arguments
        script string
        q double {mustBeVector, mustBeNumeric}
        a_joint double
        v_joint double
    end

    if numel(q) ~= 6
        error("appendMoveJ:InvalidJointVector", "q must have 6 elements.");
    end

    script = script + sprintf( ...
        "  movej([%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
        q(1), q(2), q(3), q(4), q(5), q(6), ...
        a_joint, v_joint);

    script = script + "  sleep(0.1)" + newline;
end
