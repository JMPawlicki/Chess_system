ip = '192.168.0.10';
ur = tcpclient(ip, 30002, "Timeout", 3);

% Fill these with your pendant values in degrees:
q_deg = [0, -135, 45, -70, -90, 0];   % <-- example only!

q = deg2rad(q_deg);

a = 0.2;   % acceleration (rad/s^2) conservative
v = 0.2;   % speed (rad/s) conservative

script = sprintf([ ...
    'def matlab_go_home():\n' ...
    '  movej([%.6f, %.6f, %.6f, %.6f, %.6f, %.6f], a=%.3f, v=%.3f)\n' ...
    'end\n' ...
    'matlab_go_home()\n' ...
], q(1),q(2),q(3),q(4),q(5),q(6), a, v);

write(ur, uint8(script));
clear ur