function g = pieceGlyph(p)
switch p
    case 'P', g = "♙";
    case 'N', g = "♘";
    case 'B', g = "♗";
    case 'R', g = "♖";
    case 'Q', g = "♕";
    case 'K', g = "♔";
    case 'p', g = "♟";
    case 'n', g = "♞";
    case 'b', g = "♝";
    case 'r', g = "♜";
    case 'q', g = "♛";
    case 'k', g = "♚";
    otherwise, g = "";
end
end