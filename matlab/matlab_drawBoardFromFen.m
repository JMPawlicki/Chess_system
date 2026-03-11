function drawBoardFromFen(ax, fen, perspective)
% perspective: "white" or "black" (who is at the bottom of the GUI)

board = fenToBoard(fen); % ranks 8->1, files a->h

cla(ax);
hold(ax, 'on');
axis(ax, 'equal');
axis(ax, [0 8 0 8]);
ax.XTick = [];
ax.YTick = [];
ax.YDir = 'normal';

light = [0.93 0.93 0.90];
dark  = [0.45 0.55 0.65];

for r = 1:8
    for c = 1:8
        isDark = mod(r + c, 2) == 0;
        color = light; if isDark, color = dark; end

        % Map display coords depending on perspective
        if perspective == "white"
            x = c - 1;
            y = 8 - r;
        else
            x = 8 - c;
            y = r - 1;
        end

        rectangle(ax, 'Position', [x y 1 1], 'FaceColor', color, 'EdgeColor', 'none');

        p = board(r,c);
        if p ~= '.'
            text(ax, x+0.5, y+0.5, pieceGlyph(p), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', 26);
        end
    end
end

hold(ax, 'off');
end