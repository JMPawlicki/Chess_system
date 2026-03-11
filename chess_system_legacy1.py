import serial
import time
import chess
from stockfish import Stockfish

stockfish = Stockfish(path="./stockfish/stockfish-windows-x86-64-avx2.exe")
# ===========================
# Funkcje pomocnicze
# ===========================
def square_id_to_uci(square):
    """Konwertuje ID pola DGT na notację UCI a1-h8"""
    file = square % 8
    rank = square // 8
    file = 7 - file  # odwrócone kolumny, aby a-h było poprawnie
    return chr(ord('a') + file) + str(rank + 1)

def update_board_and_get_move(board, src_idx, dst_idx):
    """
    Aktualizuje stan planszy i zwraca, czy ruch jest biciem.
    board: lista 64 elementów, None = puste pole, lub 'P','p','N','n', etc.
    src_idx: pole źródłowe (0-63)
    dst_idx: pole docelowe (0-63)
    """
    is_capture = board[dst_idx] is not None
    board[dst_idx] = board[src_idx]
    board[src_idx] = None
    return is_capture


def ask_promotion_piece(is_white):
    """Prosty prompt w konsoli, zwraca literę promocji q/r/b/n."""
    color = "białego" if is_white else "czarnego"
    prompt = f"Promocja piona {color}. Wpisz q/r/b/n (Enter=hetman): "
    while True:
        choice = input(prompt).strip().lower()
        if choice == "":
            return "q"
        if choice in {"q", "r", "b", "n"}:
            return choice
        print("Nieprawidłowy wybór, użyj q/r/b/n lub Enter.")

def initialize_board():
    """
    Tworzy pełną planszę szachową w tablicy 64 elementów
    """
    board = [None] * 64
    # białe pionki
    for i in range(8,16):
        board[i] = 'P'
    # czarne pionki
    for i in range(48,56):
        board[i] = 'p'
    # białe figury
    board[0], board[7] = 'R','R'
    board[1], board[6] = 'N','N'
    board[2], board[5] = 'B','B'
    board[3], board[4] = 'Q','K'
    # czarne figury
    board[56], board[63] = 'r','r'
    board[57], board[62] = 'n','n'
    board[58], board[61] = 'b','b'
    board[59], board[60] = 'q','k'
    return board

# ===========================
# Inicjalizacja DGT Board
# ===========================
ser = serial.Serial("COM6", 38400, timeout=0.3)
DTG_REQ_UPDATE_BOARD = bytes([0x44])

print("Połączono z DGT, oczekiwanie na ruchy...")

# ===========================
# Konfiguracja Stockfish
# ===========================
while True:
    try:
        depth = int(input("Wpisz głębokość silnika (1-20): "))
        if 1 <= depth <= 20:
            stockfish.set_depth(depth)
            print(f"Ustawiono głębokość: {depth}")
            break
        else:
            print("Głębokość musi być między 1 a 20.")
    except ValueError:
        print("Podaj liczbę całkowitą.")

while True:
    player_starts = input("\nGracz czy Komputer? (g=gracz, k=komputer): ").strip().lower()
    if player_starts == 'g':
        player_is_white = True
        print("Gracz: białe, Komputer: czarne")
        break
    elif player_starts == 'k':
        player_is_white = False
        print("Gracz: czarne, Komputer: białe")
        break
    else:
        print("Wpisz: g lub k")

# ===========================
# Bufor i stan planszy
# ===========================
current_segments = []
last_segment_time = None
SEGMENT_TIMEOUT = 2.5  # czas w sekundach do uznania ruchu za kompletny
board = initialize_board()  # pełna plansza
pending_promotion_move = None  # zapamiętany ruch promocji czekający na wymianę figury
moves_history = []
chess_board = chess.Board()

# ===========================
# Pętla główna
# ===========================
# Jeśli komputer zaczyna, wypisz jego pierwszy ruch
if not player_is_white:
    best_move = stockfish.get_best_move()
    print(f"\n>>> Rekomendowany ruch komputera: {best_move}\n")

while True:
    ser.write(DTG_REQ_UPDATE_BOARD)
    data = ser.read(32)
    current_time = time.time()
    
    # dzielimy na segmenty 5-bajtowe
    for i in range(0, len(data), 5):
        segment = data[i:i+5]
        if len(segment) < 4 or segment[0] != 0x8e:
            continue
        current_segments.append(segment)
        last_segment_time = current_time

    # sprawdzenie timeoutu – uznajemy, że ruch jest kompletny
    if current_segments and last_segment_time and (current_time - last_segment_time > SEGMENT_TIMEOUT):
        # Jeśli czekamy na wymianę figury po promocji
        if pending_promotion_move and len(current_segments) == 2:
            # To jest zdjęcie piona i postawienie figury - wypisz zapamiętany ruch
            try:
                move_obj = chess.Move.from_uci(pending_promotion_move)
                if move_obj in chess_board.legal_moves:
                    chess_board.push_uci(pending_promotion_move)
                    moves_history.append(pending_promotion_move)
                    print("Wykonano ruch:", pending_promotion_move)
                    print(chess_board)
                    # Aktualizuj Stockfish
                    stockfish.set_fen_position(chess_board.fen())
                    # Jeśli teraz kolej komputera, wydrukuj rekomendowany ruch
                    if (player_is_white and not chess_board.turn) or (not player_is_white and chess_board.turn):
                        best_move = stockfish.get_best_move()
                        print(f"\n>>> Rekomendowany ruch komputera: {best_move}\n")                    
                else:
                    print(f"RUCH NIELEGALNY: {pending_promotion_move}")
                    print(f"Zwycięstwo dla {'czarnych' if chess_board.turn else 'białych'}!")
                    break
            except Exception as exc:
                print("Błąd push promocji:", exc)
                print(f"Zwycięstwo dla {'czarnych' if chess_board.turn else 'białych'}!")
                break
            pending_promotion_move = None
            current_segments = []
            last_segment_time = None
            continue
        
        if len(current_segments) == 2:
            # Normalny ruch: zdjęcie z src, postawienie na dst
            src_idx = current_segments[0][3]
            dst_idx = current_segments[1][3]
            is_capture = False
        elif len(current_segments) == 3:
            # Bicie: zdjęcie z dst (bita figura), zdjęcie z src (atakująca), postawienie na dst
            src_idx = current_segments[1][3]
            dst_idx = current_segments[2][3]
            is_capture = True
        # --- ROSZADA LUB PROMOCJA 4-SEGMENTOWA ---
        elif len(current_segments) == 4:
            squares = [seg[3] for seg in current_segments]
            uci_squares = [square_id_to_uci(sq) for sq in squares]

            # Próba rozpoznania roszady
            if "e1" in uci_squares and "g1" in uci_squares:
                move = "e1g1"
            elif "e1" in uci_squares and "c1" in uci_squares:
                move = "e1c1"
            elif "e8" in uci_squares and "g8" in uci_squares:
                move = "e8g8"
            elif "e8" in uci_squares and "c8" in uci_squares:
                move = "e8c8"
            else:
                move = None

            if move:
                try:
                    move_obj = chess.Move.from_uci(move)
                    if move_obj in chess_board.legal_moves:
                        chess_board.push_uci(move)
                        moves_history.append(move)
                        print("Wykonano ruch:", move)
                        print(chess_board)
                        # Aktualizuj Stockfish
                        stockfish.set_fen_position(chess_board.fen())
                        # Jeśli teraz kolej komputera, wydrukuj rekomendowany ruch
                        if (player_is_white and not chess_board.turn) or (not player_is_white and chess_board.turn):
                            best_move = stockfish.get_best_move()
                            print(f"\n>>> Rekomendowany ruch komputera: {best_move}\n")                        
                    else:
                        print(f"RUCH NIELEGALNY: {move}")
                        print(f"Zwycięstwo dla {'czarnych' if chess_board.turn else 'białych'}!")
                        break
                except Exception as exc:
                    print("Błąd push roszady:", exc)
                    print(f"Zwycięstwo dla {'czarnych' if chess_board.turn else 'białych'}!")
                    break
                current_segments = []
                last_segment_time = None
                continue

            # Fallback: traktuj jako ruch (np. promocja z dołożeniem figury)
            src_idx = squares[0]
            dst_idx = squares[1]
            is_capture = board[dst_idx] is not None
        else:
            # Nieprawidłowa liczba segmentów, reset
            current_segments = []
            continue

        # Podniesienie i odłożenie tej samej figury na to samo pole – ignoruj
        if src_idx == dst_idx:
            current_segments = []
            last_segment_time = None
            continue

        # sprawdzenie promocji PRZED aktualizacją planszy
        dst_rank = int(square_id_to_uci(dst_idx)[1])
        piece = board[src_idx]
        promotion = None

        # białe pionki
        if piece == 'P' and dst_rank == 8:
            promotion = ask_promotion_piece(True)
        # czarne pionki
        elif piece == 'p' and dst_rank == 1:
            promotion = ask_promotion_piece(False)

        # aktualizacja własnej planszy
        update_board_and_get_move(board, src_idx, dst_idx)

        # konwersja do notacji z "x" dla bicia
        src = square_id_to_uci(src_idx)
        dst = square_id_to_uci(dst_idx)
        if is_capture:
            move = src + dst
        else:
            move = src + dst

        if promotion:
            move += promotion  # np. e7e8q
            pending_promotion_move = move  # zapamiętaj ruch, wypisz po wymianie figury
        else:
            try:
                move_obj = chess.Move.from_uci(move)
                if move_obj in chess_board.legal_moves:
                    chess_board.push_uci(move)
                    moves_history.append(move)
                    print("Wykonano ruch:", move)
                    print(chess_board)
                    # Aktualizuj Stockfish
                    stockfish.set_fen_position(chess_board.fen())
                    # Jeśli teraz kolej komputera, wydrukuj rekomendowany ruch
                    if (player_is_white and not chess_board.turn) or (not player_is_white and chess_board.turn):
                        best_move = stockfish.get_best_move()
                        print(f"\n>>> Rekomendowany ruch komputera: {best_move}\n")                    
                else:
                    print(f"RUCH NIELEGALNY: {move}")
                    print(f"Zwycięstwo dla {'czarnych' if chess_board.turn else 'białych'}!")
                    break
            except Exception as exc:
                print("Błąd push ruchu:", exc)
                print(f"Zwycięstwo dla {'czarnych' if chess_board.turn else 'białych'}!")
                break

        # reset bufora
        current_segments = []
        last_segment_time = None

    time.sleep(0.01)