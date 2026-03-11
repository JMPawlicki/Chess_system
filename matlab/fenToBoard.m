function board = fenToBoard(fen)
% board is 8x8 char array, ranks 8->1, files a->h.
% Empty squares are '.'. Pieces are FEN chars: PNBRQKpnbrqk.

fen = char(strtrim(string(fen)));
parts = strsplit(fen, ' ');
placement = parts{1};          % char row like 'rnbqkbnr/pppp...'

board = repmat('.', 8, 8);

r = 1; c = 1;
for idx = 1:numel(placement)
    ch = placement(idx);       % <-- guaranteed 1x1 char

    if ch == '/'
        r = r + 1;
        c = 1;
    elseif ch >= '1' && ch <= '8'
        c = c + (double(ch) - double('0'));
    else
        board(r, c) = ch;
        c = c + 1;
    end
end
end