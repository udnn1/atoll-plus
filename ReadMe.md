<h1 align="center">Atoll (wersja udnn1)</h1>

<p align="center">Prywatna wersja <a href="https://github.com/Ebullioscopic/Atoll">Atolla</a>, czyli „Dynamic Island” dla macOS, dopasowana do mojego MacBooka Air M4 i zewnętrznego monitora bez notcha.</p>

## Co zmieniliśmy względem oryginału

### Licznik limitu Claude (zamiast claude-tray)
- Logika przeniesiona 1:1 z mojego `claude-tray`: token z aplikacji Claude Desktop (`~/Library/Application Support/Claude/config.json`, odszyfrowany kluczem „Claude Safe Storage” z Pęku kluczy), automatyczne odświeżanie tokenu, adaptacyjne tempo odpytywania (60–900 s, wolniej przy bezczynności, cofanie się przy limicie API), dane starsze niż 20 minut traktowane jak brak danych („?”).
- Stan i zaszyfrowany token w tych samych plikach co claude-tray: `~/Library/Application Support/ClaudeLimitTray/`.
- Wygląd jak ikona claude-tray: pierścień postępu z liczbą, kolory zielony (< 50%), bursztynowy (50–74%), pomarańczowy (75–89%), czerwony (≥ 90%).
- Zamknięta wyspa jest stale wysunięta z pierścieniem. Na ekranie z notchem pierścień stoi obok fizycznego notcha, przeskakuje na prawą stronę, gdy menu aplikacji dochodzą do notcha, i chowa się, gdy po obu stronach brakuje miejsca. Notch wyspy zawsze trafia w fizyczny notch.
- Najechanie na pierścień otwiera notch na karcie **Usage** ze szczegółami jak w menu claude-tray: limit 5h i 7d, reset, ostatni i następny odczyt, „Odśwież teraz”, wybór liczby (5h/7d) i pierścienia.
- Włączanie i wyłączanie: **Ustawienia → Stats → Licznik limitu Claude** albo przełącznik **Limit Claude** w menu Atolla na pasku menu.
- Gdy działa muzyka, timer albo inna aktywność, ma ona pierwszeństwo, a pierścień wraca po niej.

### Poprawki błędów
- Na monitorze bez notcha schowana wyspa wysuwa się przy animacji ładowania, włączaniu muzyki i innych animacjach (wcześniej animacja grała poza ekranem).
- Rozmycie zawartości notcha znika po przewijaniu kółkiem myszy. Wcześniej myszy bez fazy końca gestu (np. Logitech) zostawiały rozmycie na stałe.
- Ikona baterii ma margines wewnętrzny, więc „100” z wtyczką nie dotyka krawędzi.
- Przełącznik **Limit Claude** w menu na pasku menu.

### Ustawienia, których używam
- HUD głośności i jasności: **Vertical Bar** po prawej (styl jak w MediaMate).
- Monitor zewnętrzny: styl Dynamic Island, chowanie do najechania, wysokość jak pasek menu, ukrywanie w pełnym ekranie.
- Keep Awake wyłączone.

## Budowanie i instalacja (lokalnie)

Wymagania: macOS 14+, Xcode (u mnie 27.1) z pobranym Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`).

```bash
xcodebuild build -project DynamicIsland.xcodeproj -scheme DynamicIsland -configuration Release \
  -destination "platform=macOS" -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=YES
./scripts/install-local.sh build/Build/Products/Release/Atoll.app
```

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
