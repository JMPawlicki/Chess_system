function side = fenSideToMove(fen)
parts = split(string(strtrim(fen)));
if numel(parts) < 2
    side = "?";
    return;
end
side = parts(2); % "w" or "b"
end