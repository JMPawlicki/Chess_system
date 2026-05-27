function commParams = robotCommParams()
%ROBOTCOMMPARAMS Communication settings between UR3 and MATLAB GUI.

% Below set your own IP address
    commParams.pcIp = "192.168.0.154";
    commParams.robotDonePort = 5001;
    commParams.socketName = "gui";
end