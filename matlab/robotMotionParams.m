function motionParams = robotMotionParams()
%ROBOTMOTIONPARAMS Return default UR3 motion parameters for chess robot.
%
% Units:
%   - Joint positions are in radians when used in URScript.
%   - Cartesian positions are expected as p[x,y,z,rx,ry,rz], XYZ in meters.
%   - Accelerations and velocities are URScript units.
%
% Usage:
%   motionParams = robotMotionParams();
%
% Fields:
%   a_joint, v_joint - movej acceleration/velocity
%   a_lin,   v_lin   - movel acceleration/velocity
%   Q_HOME_deg       - home joint pose in degrees
%   Q_HOME           - home joint pose in radians

    motionParams = struct();

    % Joint motion parameters
    motionParams.a_joint = 1.00;
    motionParams.v_joint = 2.00;

    % Linear Cartesian motion parameters
    motionParams.a_lin = 0.30;
    motionParams.v_lin = 0.65;

    % Current safe home / standby pose
    motionParams.Q_HOME_deg = [-90, -45, -90, -90, 90, 0];
    motionParams.Q_HOME = deg2rad(motionParams.Q_HOME_deg);
end
