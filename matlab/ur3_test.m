% ip = '192.168.0.10';
% dash = tcpclient(ip, 29999, "Timeout", 3);
% 
% cmd = sprintf('robotmode\n');
% write(dash, uint8(cmd));
% 
% pause(0.2);
% n = dash.NumBytesAvailable;
% if n > 0
% disp(char(read(dash, n, "uint8")));
% else
% disp("No response from dashboard server (port 29999).");
% end
% 
% clear dash
ip = '192.168.0.10';
dash = tcpclient(ip, 29999, "Timeout", 3);

cmds = ["robotmode", "safetystatus", "programState"];
for c = cmds
    write(dash, uint8(sprintf('%s\n', c)));
    pause(0.2);
    n = dash.NumBytesAvailable;
    if n > 0
        disp(strtrim(char(read(dash, n, "uint8"))));
    end
end

clear dash