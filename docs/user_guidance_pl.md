# Instrukcja użytkownika systemu robota szachowego

Dokument opisuje podstawową procedurę konfiguracji, uruchomienia i obsługi systemu robota szachowego. System składa się z elektronicznej szachownicy DGT, backendu Python, aplikacji MATLAB GUI, silnika Stockfish oraz robota UR3.

---

## 1. Przygotowanie stanowiska

Przed uruchomieniem programu należy przygotować stanowisko robocze.

1. Ustaw szachownicę DGT w skalibrowanej pozycji względem robota UR3.
2. Ustaw wszystkie figury na poprawnych polach początkowych lub zgodnie z pozycją testową.
3. Upewnij się, że chwytak robota jest zamontowany i nie koliduje z szachownicą ani figurami.
4. Upewnij się, że komputer, robot UR3 i szachownica DGT są podłączone.
5. Sprawdź, czy robot UR3 znajduje się w stanie umożliwiającym przyjmowanie poleceń przez TCP/IP.
6. Zamknij aplikacje mogące blokować port DGT, np. DGT Live Chess.

---

## 2. Konfiguracja adresów IP, portów i ścieżek

Przed pierwszym uruchomieniem należy sprawdzić ustawienia komunikacji w projekcie. Domyślne wartości mogą wymagać zmiany po przeniesieniu systemu na inny komputer lub do innej sieci.

### 2.1. Konfiguracja backendu Python

W pliku:

```text
python/brain_server.py
```

należy sprawdzić podstawowe parametry komunikacji:

```text
HOST = 127.0.0.1
PORT = 5000
ROBOT_DONE_HOST = 0.0.0.0
ROBOT_DONE_PORT = 5001
SERIAL_PORT = COM5
SERIAL_BAUD = 38400
```

Znaczenie parametrów:

| Parametr | Znaczenie |
|---|---|
| `HOST` / `PORT` | Adres i port serwera TCP, z którym łączy się aplikacja MATLAB. |
| `ROBOT_DONE_HOST` / `ROBOT_DONE_PORT` | Adres i port nasłuchujący na sygnał zakończenia ruchu robota. |
| `SERIAL_PORT` | Port COM szachownicy DGT. |
| `SERIAL_BAUD` | Prędkość komunikacji szeregowej z DGT. |

Jeżeli szachownica DGT została wykryta pod innym portem, należy zmienić `SERIAL_PORT`, np. z `COM5` na `COM6`.

Ścieżka do Stockfisha powinna wskazywać plik wykonywalny w folderze:

```text
python/stockfish/
```

Jeżeli nazwa pliku wykonywalnego Stockfisha jest inna, należy zaktualizować odpowiednią zmienną w backendzie Python.

### 2.2. Konfiguracja aplikacji MATLAB

W aplikacji MATLAB należy sprawdzić adresy używane do połączenia z backendem i robotem.

Połączenie MATLAB → Python powinno wskazywać na:

```text
127.0.0.1:5000
```

jeżeli backend Python działa na tym samym komputerze co MATLAB.

Połączenie MATLAB → UR3 powinno wskazywać na adres IP robota oraz port sterownika UR:

```text
192.168.0.10:30002
```

Jeżeli robot ma inny adres IP, należy zmienić go w funkcji `connectUR3()` w aplikacji GUI.

### 2.3. Konfiguracja sygnału ROBOT_DONE

Robot UR3 po zakończeniu ruchu wysyła komunikat:

```text
ROBOT_DONE
```

do komputera z backendem Python. Parametry tego połączenia są definiowane w pliku:

```text
matlab/robotCommParams.m
```

Należy sprawdzić:

| Parametr | Znaczenie |
|---|---|
| `pcIp` | Adres IP komputera widoczny z sieci robota UR3. |
| `robotDonePort` | Port, na którym Python odbiera `ROBOT_DONE`, domyślnie `5001`. |
| `socketName` | Nazwa socketu używana w URScript. |

Adres `pcIp` musi być adresem komputera w tej samej sieci, w której znajduje się robot. Nie powinien to być `127.0.0.1`, ponieważ dla robota oznaczałoby to samego robota, a nie komputer.

### 2.4. Sprawdzenie sieci

Przed testami warto sprawdzić:

1. Czy komputer i UR3 są w tej samej podsieci.
2. Czy komputer może pingować robota.
3. Czy robot może połączyć się z komputerem na porcie `5001`.
4. Czy port `30002` robota jest dostępny dla MATLAB.
5. Czy zapora systemowa Windows nie blokuje połączeń przychodzących na port `5001`.

---

## 3. Uruchomienie aplikacji MATLAB

1. Otwórz projekt w MATLAB.
2. Uruchom aplikację:

   ```matlab
   ChessRobotGUI
   ```

3. Po uruchomieniu aplikacji powinno pojawić się okno GUI z widokiem szachownicy, panelem sterowania, tabelą ruchów i oknem logów.

---

## 4. Uruchomienie backendu Python

1. W aplikacji MATLAB kliknij przycisk **Start Server**.
2. Program uruchomi plik:

   ```text
   python/brain_server.py
   ```

3. Backend Python uruchamia:
   - serwer TCP dla MATLAB na porcie `5000`,
   - połączenie z szachownicą DGT przez port COM,
   - nasłuchiwanie sygnału `ROBOT_DONE` na porcie `5001`,
   - integrację z silnikiem Stockfish.

4. Jeśli backend uruchomi się poprawnie, w oknie logów MATLAB pojawi się informacja o uruchomieniu serwera.

---

## 5. Połączenie z backendem i robotem

1. Kliknij przycisk **Connect**.
2. Aplikacja MATLAB połączy się z backendem Python przez:

   ```text
   127.0.0.1:5000
   ```

3. Aplikacja spróbuje również połączyć się z robotem UR3 przez:

   ```text
   192.168.0.10:30002
   ```

4. Następnie MATLAB wysyła komendę `STATUS`, aby sprawdzić stan backendu i szachownicy DGT.
5. Jeśli DGT jest połączona poprawnie, w logu pojawi się komunikat `BOARD_OK`.
6. Jeśli szachownica nie jest dostępna, aplikacja wyświetli `BOARD_ERROR`.

---

## 6. Konfiguracja gry

Przed rozpoczęciem gry należy ustawić parametry:

1. Wybierz tryb pracy:
   - **Human vs Robot** — człowiek gra na szachownicy DGT, robot odpowiada ruchami silnika.
   - **Computer vs Computer** — silnik Stockfish steruje obiema stronami, a robot wykonuje wszystkie ruchy fizycznie.

2. Wybierz kolor gracza człowieka:
   - `white`
   - `black`

3. Wybierz głębokość silnika Stockfish z listy `Depth`.

4. Kliknij **New Game**.

Po kliknięciu **New Game** aplikacja:
- czyści log,
- resetuje tabelę ruchów,
- wysyła konfigurację do backendu,
- inicjalizuje nową partię,
- pobiera aktualny FEN.

---

## 7. Start gry

1. Sprawdź fizyczne ustawienie figur na szachownicy.
2. Kliknij przycisk **READY**.
3. Backend Python przejdzie do aktywnego stanu gry.
4. W zależności od trybu:
   - w trybie **Human vs Robot** system czeka na ruch człowieka albo od razu żąda ruchu robota, jeśli to robot jest na ruchu,
   - w trybie **Computer vs Computer** system automatycznie żąda pierwszego ruchu silnika.

---

## 8. Zasady zachowania gracza podczas rozgrywki

Poniższe zasady dotyczą obsługi fizycznej szachownicy i robota. Nie zastępują zasad gry w szachy, lecz opisują sposób korzystania z systemu.

### 8.1. Wykonywanie ruchu człowieka

1. Wykonuj ruch bezpośrednio na szachownicy DGT.
2. Podnieś figurę z pola źródłowego i odłóż ją na pole docelowe.
3. Nie przesuwaj figury przez wiele pól po powierzchni szachownicy.
4. Nie poprawiaj kilku figur jednocześnie podczas wykonywania jednego ruchu.
5. Po wykonaniu ruchu odczekaj chwilę, aż system odczyta i zatwierdzi zmianę.
6. Nie wykonuj kolejnego ruchu, dopóki robot nie zakończy swojego ruchu i system nie wróci do tury człowieka.

### 8.2. Bicia i ruchy specjalne

1. Przy biciu zdejmij zbijaną figurę z pola docelowego, a następnie przestaw swoją figurę na to pole.
2. Przy roszadzie przesuń króla i wieżę zgodnie z zasadami gry, wykonując oba przemieszczenia jako jeden ruch.
3. Przy en passant usuń zbijanego pionka z właściwego pola i przestaw swojego pionka na pole docelowe.
4. Przy promocji wykonaj ruch pionkiem na ostatnią linię, wymień go na figurę promowaną i wybierz figurę promocyjną w oknie GUI, jeśli system o to poprosi.

### 8.3. Zachowanie podczas ruchu robota

1. Nie dotykaj szachownicy, figur ani chwytaka podczas ruchu robota.
2. Nie poprawiaj figur w trakcie wykonywania ruchu przez UR3.
3. Poczekaj na zakończenie ruchu robota i aktualizację GUI.
4. Jeżeli robot upuści figurę lub przesunie inną figurę, nie wykonuj kolejnego ruchu. Poczekaj na komunikat systemu lub zatrzymaj działanie i przejdź do recovery.

### 8.4. Poprawianie pozycji

1. Figury można poprawiać tylko wtedy, gdy system jest zatrzymany, czeka na `READY`, albo wyświetlił komunikat recovery.
2. Popraw fizyczną pozycję figur zgodnie z planszą widoczną w GUI.
3. Po poprawieniu pozycji kliknij **READY**.
4. Nie klikaj **READY**, jeśli fizyczna szachownica nie zgadza się z pozycją wyświetlaną w GUI.

---

## 9. Przebieg gry w trybie Human vs Robot

1. Człowiek wykonuje ruch na fizycznej szachownicy DGT.
2. Backend Python odczytuje zmiany z DGT i rekonstruuje ruch.
3. Ruch jest walidowany przy użyciu `python-chess`.
4. Jeśli ruch jest legalny, backend wysyła do MATLAB komunikat:

   ```text
   HUMAN_MOVE <uci>
   ```

5. MATLAB aktualizuje tabelę ruchów i widok planszy.
6. MATLAB wysyła żądanie ruchu silnika:

   ```text
   GET_BEST_MOVE
   ```

7. Python pyta Stockfish o ruch i wysyła do MATLAB pełny opis ruchu robota:

   ```text
   ROBOT_MOVE ...
   ```

8. MATLAB generuje skrypt URScript.
9. Skrypt jest wysyłany do robota UR3.
10. Robot wykonuje ruch fizycznie na szachownicy.
11. Po zakończeniu ruchu robot wysyła sygnał:

   ```text
   ROBOT_DONE
   ```

12. MATLAB informuje backend o zakończeniu ruchu:

   ```text
   ROBOT_MOVE_DONE
   ```

13. Backend akceptuje ruch, aktualizuje stan gry i wysyła aktualny FEN.

---

## 10. Przebieg gry w trybie Computer vs Computer

1. Po kliknięciu **READY** MATLAB wysyła:

   ```text
   GET_BEST_MOVE
   ```

2. Python wybiera ruch silnika Stockfish.
3. Backend wysyła do MATLAB komunikat `ROBOT_MOVE`.
4. MATLAB generuje URScript i wysyła go do UR3.
5. Robot wykonuje ruch.
6. Po ruchu robot wysyła `ROBOT_DONE`.
7. MATLAB wysyła `ROBOT_MOVE_DONE` i pobiera aktualny FEN.
8. Następnie MATLAB automatycznie żąda kolejnego ruchu silnika.

W tym trybie robot nie musi wracać do pozycji domowej po każdym ruchu, ponieważ człowiek nie wykonuje ruchów między ruchami robota.

---

## 11. Ustawienie własnej pozycji FEN

1. Kliknij **Set Fen Position**.
2. Wprowadź poprawny ciąg FEN.
3. Aplikacja sprawdzi podstawową poprawność formatu.
4. Po zaakceptowaniu pozycji ustaw figury fizycznie zgodnie z wprowadzonym FEN.
5. Kliknij **READY**, aby rozpocząć grę z tej pozycji.

---

## 12. Obsługa promocji

W przypadku promocji pionka człowieka backend wysyła:

```text
PROMOTION_REQUIRED <uci_base>
```

Aplikacja MATLAB wyświetla okno wyboru figury:
- Queen,
- Rook,
- Bishop,
- Knight.

Po wyborze MATLAB wysyła komendę `PROMOTE`.

W przypadku ruchów robota promocje są wymuszane na hetmana. System śledzi dostępność zapasowych hetmanów osobno dla białych i czarnych.

---

## 13. Obsługa błędów i recovery

System może przejść do trybu recovery w przypadku:
- nielegalnego ruchu człowieka,
- niezgodności fizycznej planszy po ruchu robota,
- błędnej lub niejednoznacznej sekwencji DGT,
- problemu z wykonaniem ruchu robota.

W przypadku błędu:
1. GUI wyświetla komunikat.
2. System zatrzymuje dalsze automatyczne ruchy.
3. Na planszy GUI pokazywana jest ostatnia poprawna pozycja.
4. Użytkownik powinien poprawić fizyczne ustawienie figur.
5. Po poprawieniu pozycji należy kliknąć **READY**.
6. System kontynuuje grę od ostatniego poprawnego stanu.

---

## 14. Zakończenie gry

Gra może zakończyć się przez:
- mata,
- pata,
- remis,
- ręczne zamknięcie aplikacji.

Po komunikacie `GAME_OVER` aplikacja wyświetla okno z możliwością:
- rozpoczęcia nowej gry,
- zakończenia działania.

---

## 15. Bezpieczne zamykanie systemu

Aby zakończyć pracę:

1. Poczekaj, aż robot zakończy aktualny ruch.
2. Zamknij aplikację MATLAB.
3. GUI wysyła do backendu komendę:

   ```text
   QUIT
   ```

4. Backend odpowiada `BYE` i zamyka proces.
5. Połączenia TCP z backendem i robotem są zamykane.
6. W razie potrzeby zatrzymaj robota z panelu PolyScope.

---

## 16. Najczęstsze problemy

### DGT board is not connected

Możliwe przyczyny:
- zły port COM,
- DGT Live Chess blokuje port,
- kabel USB nie jest podłączony,
- backend nie ma dostępu do portu szeregowego.

### UR3 connection failed

Możliwe przyczyny:
- robot jest wyłączony,
- robot ma inny adres IP,
- komputer nie jest w tej samej sieci,
- komputer ma inny adres IP niż wpisany w parametrach,
- port `30002` jest niedostępny,
- robot nie jest gotowy do przyjmowania komend.

### Robot move failed

Oznacza, że fizyczny stan planszy po ruchu robota nie zgadza się z oczekiwanym stanem. Należy poprawić figury zgodnie z GUI i kliknąć **READY**.

---

## 17. Uwagi bezpieczeństwa

- Nie wkładaj rąk w obszar pracy robota podczas wykonywania ruchu.
- Przed kliknięciem **READY** upewnij się, że plansza jest ustawiona poprawnie.
- W czasie testów używaj małych prędkości i nadzoruj robota.
- W przypadku nieprawidłowego ruchu użyj zatrzymania awaryjnego lub zatrzymania na panelu robota.
