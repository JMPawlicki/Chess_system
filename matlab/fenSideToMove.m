function side = fenSideToMove(fen)
parts = split(string(strtrim(fen)));
if numel(parts) < 2
    side = "?";
else
    side = parts(2);   % scalar string
end
end