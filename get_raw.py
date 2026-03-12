import serial
import time

# ===========================
# Funkcje pomocnicze
# ===========================

def square_id_to_uci(square):
    file = square % 8
    rank = square // 8
    file = 7 - file  # odwrócona kolumna dla DGT
    return chr(ord('a') + file) + str(rank + 1)

# ===========================
# Dekodowanie ruchów z segmentów
# ===========================

current_move_segments = []  # bufor aktualnego ruchu

def decode_segments_to_uci(segments):
    """Zwraca jeden ruch UCI, wykrywając bicie heurystycznie"""
    if len(segments) < 2:
        return None

    src = square_id_to_uci(segments[0][3])
    dst = square_id_to_uci(segments[1][3])

    is_capture = False  # tymczasowo

    move = src + ('x' if is_capture else '') + dst
    return move

# ===========================
# Połączenie z DGT Board
# ===========================

ser = serial.Serial("COM6", 38400, timeout=0.1)
DTG_REQ_UPDATE_BOARD = bytes([0x44])

print("Połączono z DGT, oczekiwanie na ruchy...")

while True:
    ser.write(DTG_REQ_UPDATE_BOARD)

    # Spróbuj odczytać dokładnie tyle bajtów, ile jest dostępnych,
    # jeśli in_waiting jest obsługiwane przez port
    to_read = ser.in_waiting if hasattr(ser, 'in_waiting') else 32
    if to_read:
        data = ser.read(to_read)
    else:
        # fallback: przeczytaj do 32 bajtów (jak w Twoim oryginale)
        data = ser.read(32)

    # tylko drukuj gdy są jakieś dane
    if data:
        # kilka sposobów na wyświetlenie surowych danych:
        print("RAW repr:", repr(data))


    # # dzielimy na segmenty 5-bajtowe
    # for i in range(0, len(data), 5):
    #     segment = data[i:i+5]
    #     if len(segment) < 4 or segment[0] != 0x8e:
    #         # pokaż niepasujący fragment (opcjonalnie)
    #         if segment:
    #             print("Nieprawidłowy/krótki segment:", " ".join(f"{b:02X}" for b in segment))
    #         continue

    #     # pokaz segment w heksie
    #     print("Segment:", " ".join(f"{b:02X}" for b in segment))

    #     current_move_segments.append(segment)

    #     # sprawdzenie czy ruch może być kompletny
    #     if len(current_move_segments) >= 2:
    #         move = decode_segments_to_uci(current_move_segments)
    #         if move:
    #             print("Wykonano ruch:", move)
    #             current_move_segments = []  # reset bufora

    time.sleep(0.1)