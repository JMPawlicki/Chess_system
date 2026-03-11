% matlab_client_example.m
%
% Example MATLAB client for brain_server.py.
%
% Demonstrates the full command/event flow:
%   CONFIG -> NEW_GAME -> READY -> READY_OK
%   -> (DGT) HUMAN_MOVE -> GET_BEST_MOVE -> BEST_MOVE -> ENGINE_MOVE_DONE
%   -> repeat until GAME_OVER
%
% Promotions: the example defaults to queen for both human and engine.
%
% Requires MATLAB R2021a or later (tcpclient).
% Run brain_server.py first, then execute this script.

HOST = '127.0.0.1';
PORT = 5000;

t = tcpclient(HOST, PORT, 'Timeout', 30);

% -----------------------------------------------------------------------
% Helper: send a command (appends newline)
% -----------------------------------------------------------------------
    function send_cmd(t, cmd)
        write(t, uint8([cmd, newline]));
        fprintf('[TX] %s\n', cmd);
    end

% -----------------------------------------------------------------------
% Helper: read one newline-terminated message (blocks until received)
% -----------------------------------------------------------------------
    function msg = recv_msg(t)
        msg = '';
        while true
            if t.NumBytesAvailable > 0
                c = char(read(t, 1, 'uint8'));
                if c == newline
                    break;
                end
                msg = [msg, c];
            else
                pause(0.01);
            end
        end
        fprintf('[RX] %s\n', msg);
    end

% -----------------------------------------------------------------------
% Configure the session: depth 5, human plays white
% -----------------------------------------------------------------------
send_cmd(t, 'CONFIG depth=5 human=white');

% Reset / start a new game
send_cmd(t, 'NEW_GAME');

% Signal that MATLAB is ready
send_cmd(t, 'READY');

% Expect READY_OK
msg = recv_msg(t);
if ~strcmp(msg, 'READY_OK')
    error('Unexpected response to READY: %s', msg);
end
disp('Session started.');

% -----------------------------------------------------------------------
% Main game loop
% -----------------------------------------------------------------------
while true
    msg = recv_msg(t);

    if startsWith(msg, 'HUMAN_MOVE')
        % Human made a move on the DGT board.
        % Request the engine's best reply.
        send_cmd(t, 'GET_BEST_MOVE');

    elseif startsWith(msg, 'BEST_MOVE')
        parts = strsplit(msg);
        engine_uci = parts{2};
        fprintf('Robot should execute move: %s\n', engine_uci);

        % For testing (no robot integration yet):
        input('Execute the move physically / with the robot, then press Enter...', 's');
        pause(1.0);  % give DGT time to stop sending packets / vibrations to settle
        send_cmd(t, 'ENGINE_MOVE_DONE');

    elseif startsWith(msg, 'PROMOTION_REQUIRED')
        % Human pawn reached the last rank.
        % Default to queen; replace 'q' with the desired piece if needed.
        send_cmd(t, 'PROMOTE q');

    elseif startsWith(msg, 'GAME_OVER')
        parts = strsplit(msg);
        result = parts{2};
        fprintf('Game over: %s\n', result);
        break;

    elseif startsWith(msg, 'ERROR')
        fprintf('Server error: %s\n', msg);
        break;
    end
end

% -----------------------------------------------------------------------
% Clean up
% -----------------------------------------------------------------------
send_cmd(t, 'SHUTDOWN');
clear t;
disp('Done.');
