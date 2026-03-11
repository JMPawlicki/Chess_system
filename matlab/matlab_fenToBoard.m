function board = fenToBoard(fen)
% board is 8x8 char array, ranks 8->1, files a->h.
% Empty squares are '.'. Pieces are FEN chars: PNBRQKpnbrqk.

parts = split(string(strtrim(fen)));
placement = parts(1);

board = repmat('.', 8, 8);
r = 1; c = 1;

for ch = char(placement)'
    if ch == '/'
        r = r + 1; c = 1;
    elseif ch >= '1' && ch <= '8'
        n = double(ch - '0');
        c = c + n;
    else
        board(r, c) = ch;
        c = c + 1;
    end
end
end