<h1 align="center">Atoll (wersja udnn1)</h1>

<p align="center">Prywatna wersja <a href="https://github.com/Ebullioscopic/Atoll">Atolla</a>, czyli „Dynamic Island” dla macOS, dopasowana do mojego MacBooka Air M4 i zewnętrznego monitora bez notcha.</p>

## Co zmieniliśmy względem oryginału

### Licznik limitu Claude (zamiast claude-tray)
- Logika przeniesiona 1:1 z mojego `claude-tray`: token z aplikacji Claude Desktop (`~/Library/Application Support/Claude/config.json`, odszyfrowany kluczem „Claude Safe Storage” z Pęku kluczy), automatyczne odświeżanie tokenu, adaptacyjne tempo odpytywania (60–900 s, wolniej przy bezczynności, cofanie się przy limicie API), dane starsze niż 20 minut traktowane jak brak danych („?”).
- Stan i zaszyfrowany token w tych samych plikach co claude-tray: `~/Library/Application Support/ClaudeLimitTray/`.
- Wygląd jak ikona claude-tray: pierścień postępu z liczbą, kolory zielony (< 50%), bursztynowy (50–74%), pomarańczowy (75–89%), czerwony (≥ 90%).
- Zamknięta wyspa jest stale wysunięta z pierścieniem. Na ekranie z notchem pierścień stoi obok fizycznego notcha, przeskakuje na prawą stronę, gdy menu aplikacji dochodzą do notcha, i chowa się, gdy po obu stronach brakuje miejsca. Notch wyspy zawsze trafia w fizyczny notch.
- Wskaźnik Caps Lock (bez napisu) używa tego samego jednostronnego skrzydła co pierścień: ikona po lewej (albo po prawej, gdy menu dochodzą do notcha), wyspa wystaje tylko z tej strony i o tyle samo co pierścień.
- Najechanie na pierścień otwiera notch na karcie **Usage** ze szczegółami jak w menu claude-tray: limit 5h i 7d, reset, ostatni i następny odczyt, „Odśwież teraz”, wybór liczby (5h/7d) i pierścienia.
- Włączanie i wyłączanie: **Ustawienia → Stats → Licznik limitu Claude** albo przełącznik **Limit Claude** w menu Atolla na pasku menu.
- Gdy pojawia się inna stała aktywność (muzyka, Caps Lock, timer, przypomnienie, nagrywanie, pobieranie, LocalSend, skupienie, wskaźniki kamery/mikrofonu, aktywności rozszerzeń), pierścień zostaje, a wyspa poszerza się o tę aktywność. Przy Caps Lock pierścień stoi przy notchu, a ikona Caps Lock obok niego na zewnątrz. Przy aktywnościach z dwoma skrzydłami pierścień jest dodatkowym, zewnętrznym skrzydłem po lewej, a po prawej, gdy menu aplikacji dochodzą do notcha. Krótkie komunikaty (ładowarka, bateria, podgląd utworu, HUD-y) na chwilę zastępują zawartość wyspy jak dotąd.

### Gesty gładzika (wbudowany Slidr-Free)
Kod [Slidr-Free](https://github.com/YuriGao/slidr-free) (MIT, licencja w `DynamicIsland/TrackpadGestures/LICENSE-slidr-free.txt`) działa wewnątrz Atolla, nie jako osobna aplikacja ani wpis w autostarcie. Startuje i kończy się razem z Atollem. Konfiguracja jest w **Ustawienia → Gładzik** i zawiera te same opcje co Slidr-Free: Overview, Edge Gestures, Corner Shortcuts, Middle Click i Diagnostics.

Działa tylko na fizycznym gładziku (MacBook z otwartą klapą albo Magic Trackpad). Dotyk czyta prywatny framework Apple MultitouchSupport.

- **Krawędzie:** przesunięcie jednym palcem w górę lub w dół przy lewej albo prawej krawędzi zmienia przypisaną wartość: jasność, głośność albo nic. Gest wysyła systemowy klawisz głośności lub jasności, więc wartość zmienia się o krok Atolla i pokazuje się HUD Atolla (Vertical Bar). Górna krawędź przy przesunięciu w prawo lub w lewo przełącza kartę w Safari, Chrome i Edge. Opcja „Cycle between first and last tabs” zawija z ostatniej karty na pierwszą.
- **Haptyka:** każdy krok głośności, jasności i karty daje tyknięcie silniczkiem gładzika (`MTActuator`, działa też w tle), a otwarcie aplikacji z rogu tyknięcie o 2 poziomy mocniejsze. Siłę (1–6, domyślnie 2) ustawia suwak „Siła haptyki” w Gładzik → Przegląd, z przyciskiem „Wypróbuj”.
- **Rogi:** podwójne stuknięcie w róg gładzika otwiera przypisaną aplikację. Jeśli jest już na pierwszym planie, jej okno się minimalizuje albo przywraca.
- **Środkowe kliknięcie:** stuknięcie albo dociśnięcie dokładnie N palcami (3 lub 4).
- **Parametry:** szerokość strefy krawędzi, odległość ruchu na jeden krok osobno dla każdej krawędzi, strefa i czas podwójnego stuknięcia w rogu, bezpieczny 15-sekundowy test gestów bez wykonywania akcji.
- **Moja konfiguracja** przeniosła się automatycznie z `com.slidr.free` przy pierwszym uruchomieniu: lewa krawędź = jasność, prawa = głośność, górna wyłączona, środkowe kliknięcie wyłączone.

### Mapowanie klawiszy (zamiast Karabiner-Elements i keymapd)
- `managers/KeyboardRemapper.swift` przy starcie Atolla ustawia przez `/usr/bin/hidutil`: lewy Cmd ↔ lewy Ctrl, prawy Cmd ↔ prawy Option oraz `CapsLockDelayOverride = 0` (Caps Lock bez opóźnienia).
- Mapowanie jest ponawiane po podłączeniu każdej klawiatury (powiadomienie IOKit o nowym `IOHIDEventService`, np. ponowne połączenie MX Keys przez Bluetooth), po wybudzeniu i po powrocie do sesji.
- Konfiguracja: **Ustawienia → Klawiatura**. Lista zamian „klawisz → klawisz” z wyborem z listy (lewy/prawy Control, Shift, Option, Command, Caps Lock, Escape, Tab, Return, Delete, ` , § i Fn), dodawanie i usuwanie zamian, „Przywróć domyślne” oraz przełączniki „Mapowanie klawiszy” i „Caps Lock bez opóźnienia”. Zmiany działają od razu. Zamiany są zapisane w ustawieniach Atolla (`keyboardRemapPairs`).
- Działa bez przechwytywania klawiatury, więc nie hamuje systemu jak Karabiner.

### Poprawki błędów
- Na monitorze bez notcha schowana wyspa wysuwa się przy animacji ładowania, włączaniu muzyki i innych animacjach (wcześniej animacja grała poza ekranem).
- Rozmycie zawartości notcha znika po przewijaniu kółkiem myszy. Wcześniej myszy bez fazy końca gestu (np. Logitech) zostawiały rozmycie na stałe.
- Ikona baterii ma margines wewnętrzny, więc „100” z wtyczką nie dotyka krawędzi.
- Przełącznik **Limit Claude** w menu na pasku menu.
- Regulator głośności i jasności nie wyskakuje przy starcie Atolla.
- Odsuwanie wyspy od menu aplikacji przesuwa cały kształt wyspy (wcześniej przesuwała się tylko zawartość i animacje były ucinane). Na ekranie z notchem wyspa zostaje na środku, a gdy menu dochodzą do notcha, jej lewe skrzydło się chowa, żeby nie zasłaniać menu.

### Polski interfejs
- `DynamicIsland/Localizable.xcstrings` (katalog, który faktycznie trafia do aplikacji) zsynchronizowany z kodem przez `xcstringstool sync`, wszystkie tłumaczalne teksty mają wersję polską (wcześniej polski miało tylko 174 z 1601). Dodatkowo 116 tekstów, które Ustawienia przekazywały jako zwykłe napisy (komunikaty o uprawnieniach, statusy BetterDisplay/Lunar, wyniki wyszukiwania, aktualizacje), dopisano ręcznie, a widoki w `components/Settings` wyświetlają je przez `LocalizedStringKey`, więc też są tłumaczone.
- Panel **Gładzik** ma własny słownik `DynamicIsland/TrackpadGestures/SlidrStrings.swift` (191 tekstów), przetłumaczony na polski.
- Teksty pokazują się po polsku, gdy macOS ma polski jako język główny. Przy dodawaniu nowych tekstów: zbuduj z `SWIFT_EMIT_LOC_STRINGS=YES`, uruchom `xcrun xcstringstool sync DynamicIsland/Localizable.xcstrings --stringsdata …` i dopisz tłumaczenia `pl`.

### Ustawienia, których używam
- HUD głośności i jasności: **Vertical Bar** po prawej (styl jak w MediaMate).
- Monitor zewnętrzny: styl Dynamic Island, chowanie do najechania, wysokość jak pasek menu, ukrywanie w pełnym ekranie.
- Keep Awake wyłączone.

## Budowanie i instalacja (lokalnie)

Wymagania: macOS 14+, Xcode (u mnie 27.1) z pobranym Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`).

```bash
./scripts/build-local.sh
```

Skrypt buduje w trybie przyrostowym (`SWIFT_COMPILATION_MODE=singlefile`, ok. 12–20 s po zmianie zamiast ~100 s przy kompilacji całego modułu), pilnuje, żeby Mac nie zasnął w trakcie (`caffeinate`), i od razu instaluje wynik. Opcja `--no-install` tylko buduje. Dane builda: `~/Library/Developer/Xcode/DerivedData/Atoll-local`.

`scripts/install-local.sh` podpisuje aplikację lokalnym certyfikatem „Atoll Local Signing” (osobny pęk kluczy `~/Library/Keychains/atoll-signing.keychain-db`), podmienia `/Applications/Atoll.app` i uruchamia ją ponownie. Stały podpis sprawia, że uprawnienie **Dostępność** nadane raz zostaje przy kolejnych wersjach.

Workflow `.github/workflows/build-app.yml` buduje aplikację na GitHubie, ale tylko na żądanie (`gh workflow run build-app.yml -R udnn1/atoll-private --ref main`), żeby nie zużywać minut na macOS.

## Uprawnienia
- **Dostępność:** przechwytywanie klawiszy głośności i jasności, odczyt menu i ikon statusu (pozycja pierścienia).
- **Pęk kluczy:** odczyt hasła „Claude Safe Storage” przez `/usr/bin/security` (licznik Claude).
- Pozostałe (kalendarz, aparat, nagrywanie ekranu, muzyka) tylko dla funkcji, które ich wymagają.

## Aktualizacje z oryginału

```bash
git fetch upstream
git merge upstream/dev
```

Uwaga: wbudowany aktualizator (Sparkle) wskazuje na wydania oryginalnego Atolla. Instalacja aktualizacji z poziomu aplikacji nadpisze tę wersję oficjalną.

## Licencja i podziękowania

Atoll jest na licencji GPL v3, szczegóły w pliku [LICENSE](LICENSE). Ta wersja bazuje na [Ebullioscopic/Atoll](https://github.com/Ebullioscopic/Atoll) i projektach, z których korzysta oryginał: [Boring.Notch](https://github.com/TheBoredTeam/boring.notch), [Alcove](https://tryalcove.com), [Stats](https://github.com/exelban/stats), [Open Meteo](https://open-meteo.com), [SkyLightWindow](https://github.com/Lakr233/SkyLightWindow), [rtaudio](https://github.com/ZephyrCodesStuff/rtaudio), [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm), [DynamicNotch](https://github.com/jackson-storm/DynamicNotch), Wick i [OpenUsage](https://github.com/robinebers/openusage).
