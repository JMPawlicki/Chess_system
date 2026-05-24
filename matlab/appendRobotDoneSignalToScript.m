function script = appendRobotDoneSignalToScript(script, commParams)
%APPENDROBOTDONESIGNALTOSCRIPT Append URScript TCP notification to MATLAB.
%
% UR3 sends "ROBOT_DONE\n" to MATLAB after completing the robot move.

    arguments
        script string
        commParams struct
    end

    pcIp = string(commParams.pcIp);
    port = commParams.robotDonePort;
    socketName = string(commParams.socketName);

    script = script + ...
        "  socket_open(""" + pcIp + """, " + string(port) + ", """ + socketName + """)" + newline;

    script = script + ...
        "  sleep(0.1)" + newline;

    % Important:
    % We want the generated URScript to contain ROBOT_DONE\n.
    % In MATLAB string notation this is safe as literal backslash+n.
    script = script + ...
        "  socket_send_string(""ROBOT_DONE"", """ + socketName + """)" + newline;

    script = script + ...
        "  sleep(0.1)" + newline;

    script = script + ...
        "  socket_close(""" + socketName + """)" + newline;
end