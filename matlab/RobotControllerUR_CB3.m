classdef RobotControllerUR_CB3 < handle
    properties
        Ip (1,1) string
        Port (1,1) double = 30002
        Tcp
    end

    methods
        function obj = RobotControllerUR_CB3(ip)
            obj.Ip = string(ip);
        end

        function connect(obj)
            obj.Tcp = tcpclient(char(obj.Ip), obj.Port, "Timeout", 3);
        end

        function sendScript(obj, scriptText)
            if isempty(obj.Tcp)
                error("Robot not connected.");
            end
            if isstring(scriptText); scriptText = char(scriptText); end
            write(obj.Tcp, uint8(scriptText));
        end

        function popup(obj, msg)
            script = sprintf([ ...
                'def matlab_popup():\n' ...
                '  popup("%s", title="MATLAB", warning=False, blocking=False)\n' ...
                'end\n' ...
                'matlab_popup()\n' ...
            ], strrep(msg,'"','\"'));
            obj.sendScript(script);
        end

        function shutdown(obj)
            try
                clear obj.Tcp
            catch
            end
            obj.Tcp = [];
        end
    end
end