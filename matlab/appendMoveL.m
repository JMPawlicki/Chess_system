function script = appendMoveL(script, p, a_lin, v_lin)
%APPENDMOVEL Append one URScript movel command.
%
%   p must be [x y z rx ry rz], where XYZ are in metres and orientation is
%   axis-angle in radians.

    arguments
        script string
        p double {mustBeVector, mustBeNumeric}
        a_lin double
        v_lin double
    end

    if numel(p) ~= 6
        error("appendMoveL:InvalidPose", "p must have 6 elements [x y z rx ry rz].");
    end

    script = script + sprintf( ...
        "  movel(p[%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.4f, v=%.4f)" + newline, ...
        p(1), p(2), p(3), p(4), p(5), p(6), ...
        a_lin, v_lin);

    script = script + "  sleep(0.1)" + newline;
end
