function queenSlot = chooseQueenSlot(pieceColor, boardRotated180)
%CHOOSEQUEENSLOT Choose physical spare queen slot.
%
% pieceColor:
%   "white" or "black" from Python ROBOT_MOVE piece_color field.
%
% boardRotated180:
%   false -> human is white, robot is black, original slot is black queen
%   true  -> human is black, robot is white, original slot is white queen

    pieceColor = lower(string(pieceColor));

    if pieceColor ~= "white" && pieceColor ~= "black"
        queenSlot = "original";
        return;
    end

    if ~boardRotated180
        % Normal physical setup:
        % human white, robot black.
        % Original slot belongs to black queen.
        if pieceColor == "black"
            queenSlot = "original";
        else
            queenSlot = "secondary";
        end
    else
        % Rotated physical setup:
        % human black, robot white.
        % Original slot belongs to white queen.
        if pieceColor == "white"
            queenSlot = "original";
        else
            queenSlot = "secondary";
        end
    end
end