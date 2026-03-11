function drawBoardFromFen(ax, fen, perspective)
% perspective: "white" or "black" (who is at the bottom of the GUI)

perspective = lower(string(perspective));
if perspective ~= "white" && perspective ~= "black"
    perspective = "white";
end

board = fenToBoard(fen); % ranks 8->1, files a->h

cla(ax);
hold(ax, 'on');
axis(ax, 'equal');
axis(ax, [0 8 0 8]);
ax.XTick = [];
ax.YTick = [];
ax.YDir = 'normal';

% ---------------------------
% Dynamic piece font sizing
% ---------------------------
axPix = getpixelposition(ax, true);   % [x y w h] in pixels
squarePix = min(axPix(3), axPix(4)) / 8; % square size (approx) in pixels

% Tune these to taste:
pieceFont = round(squarePix * 0.88);  % 0.70-0.85 usually looks good
pieceFont = max(18, min(160, pieceFont)); % clamp so it doesn't get silly

light = [0.93 0.93 0.90];
dark  = [0.45 0.55 0.65];

for r = 1:8
    for c = 1:8
        isDark = mod(r + c, 2) == 0;
        color = light;
        if isDark
            color = dark;
        end

        % Map display coords depending on perspective
        if perspective == "white"
            x = c - 1;
            y = 8 - r;
        else
            x = 8 - c;
            y = r - 1;
        end

        rectangle(ax, 'Position', [x y 1 1], ...
            'FaceColor', color, ...
            'EdgeColor', 'none');

        p = board(r,c);
        if p ~= '.'
            text(ax, x+0.5, y+0.5, pieceGlyph(p), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', pieceFont);
        end
    end
end

hold(ax, 'off');
end