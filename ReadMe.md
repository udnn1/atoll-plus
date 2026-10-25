<h1 align="center">Atoll Plus</h1>

<p align="center">
  Rozszerzona wersja <a href="https://github.com/Ebullioscopic/Atoll">Atolla</a> — „Dynamic Island” dla macOS — z wbudowanym licznikiem limitu Claude, gestami gładzika ze Slidr-Free, mapowaniem klawiszy i polskim interfejsem.
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-SwiftUI-orange?logo=swift">
  <img alt="Licencja" src="https://img.shields.io/badge/licencja-GPL--3.0-blue">
  <img alt="Język" src="https://img.shields.io/badge/interfejs-polski-red">
</p>

---

Atoll Plus zastępuje w jednej aplikacji kilka osobnych narzędzi: **claude-tray** (limit Claude na pasku menu), **Slidr-Free** (gesty na krawędziach gładzika), **Karabiner-Elements / keymapd** (zamiana klawiszy) i **MediaMate** (pionowy pasek głośności). Wszystko startuje razem z Atollem, bez dodatkowych wpisów w autostarcie.

## Spis treści
- [Co dodaje Atoll Plus](#co-dodaje-atoll-plus)
- [Licznik limitu Claude](#licznik-limitu-claude)
- [Gesty gładzika](#gesty-gładzika)
- [Mapowanie klawiszy](#mapowanie-klawiszy)
- [Poprawki względem oryginału](#poprawki-względem-oryginału)
- [Polski interfejs](#polski-interfejs)
- [Budowanie i instalacja](#budowanie-i-instalacja)
- [Uprawnienia i prywatność](#uprawnienia-i-prywatność)
- [Struktura zmian w kodzie](#struktura-zmian-w-kodzie)
- [Aktualizacje z oryginału](#aktualizacje-z-oryginału)
- [Licencja i podziękowania](#licencja-i-podziękowania)

## Co dodaje Atoll Plus

| Funkcja | Gdzie w Ustawieniach | Zastępuje |
|---|---|---|
| Pierścień z limitem Claude w zamkniętej wyspie + karta **Limity** | Statystyki → Licznik limitu Claude, menu na pasku → Limit Claude | claude-tray |
| Gesty na krawędziach, rogach i środkowe kliknięcie na gładziku, z haptyką | **Gładzik** | Slidr-Free |
| Zamiana klawiszy i Caps Lock bez opóźnienia | **Klawiatura** | Karabiner-Elements, keymapd |
| Pionowy pasek głośności i jasności przy prawej krawędzi | Sterowanie → Pionowy pasek (wbudowane w Atolla) | MediaMate |
| Polski interfejs | — (język systemu) | — |

## Licznik limitu Claude

**Skąd dane.** Logika przeniesiona 1:1 z `claude-tray`:
- token OAuth z aplikacji Claude Desktop (`~/Library/Application Support/Claude/config.json`), odszyfrowany kluczem „Claude Safe Storage” z Pęku kluczy (przez `/usr/bin/security`),
- zapytanie do `https://api.anthropic.com/api/oauth/usage`, przy wygasłym tokenie odświeżenie przez `refresh_token`,
- adaptacyjne tempo: start co 120 s, przedział 60–900 s, rzadziej po 5 min bezczynności, wolniej przy odpowiedzi 429 (limit API),
- dane starsze niż 20 min są traktowane jak brak danych i pierścień pokazuje „?”,
- stan i zaszyfrowany token w `~/Library/Application Support/ClaudeLimitTray/` (te same pliki co claude-tray).

**Wygląd.** Pierścień postępu z liczbą (SF Pro, wąska), kolor wg zużycia: zielony < 50%, bursztynowy 50–74%, pomarańczowy 75–89%, czerwony ≥ 90%. Liczba to limit 5h albo 7d (do wyboru), pierścień można wyłączyć (sama liczba).

**Zachowanie w wyspie.**
- Zamknięta wyspa jest stale wysunięta z pierścieniem, także na monitorze, na którym wyspa normalnie chowa się do najechania.
- Na ekranie z notchem pierścień stoi zawsze **2 pt od fizycznego notcha**. Jest po lewej, a przechodzi na prawą stronę, gdy menu aplikacji dochodzą do notcha; chowa się, gdy po obu stronach brakuje miejsca (sprawdzane menu aplikacji i ikony statusu).
- Gdy pojawia się inna stała aktywność — muzyka, Caps Lock, timer, przypomnienie, nagrywanie ekranu, pobieranie, LocalSend, skupienie, wskaźniki kamery/mikrofonu, aktywności rozszerzeń — pierścień **zostaje przy notchu**, a nowa rzecz pojawia się dalej na zewnątrz. Pierścień jest jednym stałym elementem nad wyspą, więc nie miga ani nie przesuwa się przy przejściach.
- Krótkie komunikaty (ładowarka, bateria, podgląd utworu, słuchawki Bluetooth, HUD-y) na chwilę zastępują zawartość wyspy; pierścień w tym czasie się chowa i wraca.
- Półka i animacja bezczynności mają niższy priorytet niż pierścień.

**Karta Limity.** Najechanie na pierścień otwiera notch na karcie **Limity** ze szczegółami jak w menu claude-tray: limit 5h i 7d, godzina resetu 5h („dziś o 17:20”), ostatni i następny odczyt, przycisk **Odśwież teraz**, wybór liczby (5h/7d) i przełącznik pierścienia.

## Gesty gładzika

Kod [Slidr-Free](https://github.com/YuriGao/slidr-free) (MIT) działa wewnątrz Atolla — to nie jest osobna aplikacja. Dotyk czytany jest z prywatnego frameworka Apple MultitouchSupport, więc gesty działają **tylko na fizycznym gładziku** (MacBook z otwartą klapą albo Magic Trackpad). Konfiguracja: **Ustawienia → Gładzik** (Przegląd, Krawędzie, Rogi, Środkowe kliknięcie, Diagnostyka).

| Gest | Działanie |
|---|---|
| Jeden palec w górę/dół przy lewej krawędzi | jasność (wysyła systemowy klawisz jasności → HUD Atolla) |
| Jeden palec w górę/dół przy prawej krawędzi | głośność (wysyła systemowy klawisz głośności → HUD Atolla) |
| Jeden palec w lewo/prawo przy górnej krawędzi | poprzednia/następna karta w Safari, Chrome i Edge, opcjonalnie z zawijaniem |
| Podwójne stuknięcie w róg | otwiera przypisaną aplikację; gdy jest na pierwszym planie, minimalizuje/przywraca jej okno |
| Stuknięcie lub dociśnięcie N palcami (3 lub 4) | środkowe kliknięcie |

- **Haptyka:** każdy krok głośności, jasności i karty to tyknięcie silniczka gładzika przez `MTActuator` (działa też, gdy Atoll jest w tle). Suwak **Siła haptyki** 1–6 (domyślnie 2) z przyciskiem **Wypróbuj**; otwarcie aplikacji z rogu tyka o 2 poziomy mocniej.
- **Parametry:** szerokość strefy krawędzi, odległość ruchu na jeden krok (osobno dla każdej krawędzi), wielkość strefy rogu, limit ruchu i odstęp podwójnego stuknięcia, 15-sekundowy bezpieczny test gestów bez wykonywania akcji.
- Konfiguracja ze Slidr-Free (`com.slidr.free`) została przeniesiona automatycznie przy pierwszym uruchomieniu.

## Mapowanie klawiszy

`KeyboardRemapper` ustawia zamiany przez systemowe `/usr/bin/hidutil` — bez przechwytywania klawiatury, więc nie spowalnia systemu jak Karabiner-Elements.

- **Ustawienia → Klawiatura**: lista zamian „klawisz → klawisz” (lewy/prawy Control, Shift, Option, Command, Caps Lock, Escape, Tab, Return, Delete, `, §, Fn), dodawanie, usuwanie, **Przywróć domyślne**.
- Domyślnie: lewy Command ↔ lewy Control, prawy Command ↔ prawy Option.
- **Caps Lock bez opóźnienia** (`CapsLockDelayOverride = 0`); po wyłączeniu systemowe opóźnienie wraca po ponownym zalogowaniu.
- Mapowanie jest ponawiane po podłączeniu klawiatury (np. ponowne połączenie przez Bluetooth), po wybudzeniu Maca i po powrocie do sesji. Zmiany działają od razu.

## Poprawki względem oryginału

- **Wysuwanie ukrytej wyspy** na monitorach bez notcha przy animacji ładowania, muzyce i innych animacjach (wcześniej animacja grała poza ekranem).
- **Rozmycie zawartości notcha** znika po przewijaniu kółkiem myszy — myszy bez fazy końca gestu (np. Logitech) zostawiały je na stałe.
- **Odsuwanie wyspy od menu aplikacji** przesuwa cały kształt wyspy (wcześniej tylko zawartość, przez co animacje były ucinane). Na ekranie z notchem wyspa zostaje na środku, a gdy menu dochodzą do notcha, jej lewe skrzydło jest ucinane na krawędzi fizycznego notcha (z zaokrąglonym rogiem), żeby nie zasłaniać menu.
- **Pomiar menu aplikacji** nie gubi i nie zaniża ostatniego wyniku dla tej samej aplikacji (Firefox bywał mierzony częściowo).
- **Ikona baterii** ma margines wewnętrzny — „100” z wtyczką nie dotyka krawędzi.
- **Brak regulatora głośności/jasności** wyskakującego przy starcie Atolla.
- **Restart Atolla nie zabiera fokusu** (przycisk „Uruchom ponownie Atolla” startuje go w tle).
- **Zakładka Gładzik** z tym samym tłem i układem co reszta Ustawień; przełącznik **Limit Claude** w menu na pasku menu.

## Polski interfejs

- `DynamicIsland/Localizable.xcstrings` (katalog, który trafia do aplikacji) zsynchronizowany z kodem i przetłumaczony — wcześniej polski miało tylko 174 z ok. 1600 tekstów.
- Teksty, które Ustawienia przekazywały jako zwykłe napisy (komunikaty o uprawnieniach, statusy BetterDisplay/Lunar, wyniki wyszukiwania, okna aktualizacji, nazwy trybów), wyświetlane są przez `LocalizedStringKey` i mają tłumaczenia dopisane ręcznie.
- Panel Gładzik ma własny słownik `DynamicIsland/TrackpadGestures/SlidrStrings.swift`.
- Nowe teksty: zbuduj z `SWIFT_EMIT_LOC_STRINGS=YES`, uruchom `xcrun xcstringstool sync DynamicIsland/Localizable.xcstrings --stringsdata …` i dopisz wartości `pl`.

## Budowanie i instalacja

Wymagania: macOS 14+, Xcode z pobranym Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`).

```bash
./scripts/build-local.sh
```

- Build przyrostowy (`SWIFT_COMPILATION_MODE=singlefile`): ok. 12–20 s po zmianie zamiast ok. 100 s przy kompilacji całego modułu. `caffeinate` pilnuje, żeby Mac nie zasnął w trakcie. Dane builda: `~/Library/Developer/Xcode/DerivedData/Atoll-local`. Opcja `--no-install` tylko buduje.
- `scripts/install-local.sh` podpisuje aplikację lokalnym certyfikatem „Atoll Local Signing” (osobny pęk kluczy `~/Library/Keychains/atoll-signing.keychain-db`), podmienia `/Applications/Atoll.app`, uruchamia ją w tle i przywraca poprzednią aplikację tylko wtedy, gdy fokus się zmienił. Stały podpis sprawia, że uprawnienie **Dostępność** nadane raz zostaje przy kolejnych wersjach.
- Workflow `.github/workflows/build-app.yml` buduje aplikację na GitHubie tylko na żądanie: `gh workflow run build-app.yml -R udnn1/atoll-plus --ref main`.

## Uprawnienia i prywatność

| Uprawnienie | Po co |
|---|---|
| Dostępność | przechwytywanie klawiszy głośności i jasności, odczyt menu i ikon statusu (położenie pierścienia), gesty i środkowe kliknięcie |
| Pęk kluczy (`/usr/bin/security`) | odczyt „Claude Safe Storage” do odszyfrowania tokenu Claude Desktop |
| Pozostałe (kalendarz, kamera, nagrywanie ekranu, muzyka) | tylko dla funkcji, które ich wymagają |

Token Claude trafia wyłącznie do `api.anthropic.com`. Repozytorium nie zawiera żadnych sekretów — certyfikat podpisu i jego hasło są tylko lokalnie (`~/.config/atoll-signing`).

## Struktura zmian w kodzie

| Ścieżka | Zawartość |
|---|---|
| `DynamicIsland/managers/ClaudeLimit/ClaudeLimitService.swift` | pobieranie limitu Claude (token, odświeżanie, tempo, stan) |
| `DynamicIsland/components/ClaudeLimit/` | pierścień, aktywność w wyspie, karta Limity, miejsce na pierścień w innych aktywnościach |
| `DynamicIsland/TrackpadGestures/` | kod Slidr-Free, `SlidrTrackpadController`, `TrackpadHaptics`, polski słownik |
| `DynamicIsland/managers/KeyboardRemapper.swift` | mapowanie klawiszy i zakładka Klawiatura |
| `scripts/build-local.sh`, `scripts/install-local.sh` | szybki build i instalacja z podpisem |

## Aktualizacje z oryginału

```bash
git fetch upstream
git merge upstream/dev
```

Wbudowany aktualizator (Sparkle) wskazuje na wydania oryginalnego Atolla — instalacja aktualizacji z poziomu aplikacji nadpisze Atoll Plus wersją oficjalną.

## Licencja i podziękowania

GPL-3.0, szczegóły w [LICENSE](LICENSE). Atoll Plus bazuje na [Ebullioscopic/Atoll](https://github.com/Ebullioscopic/Atoll) i projektach, z których korzysta oryginał: [Boring.Notch](https://github.com/TheBoredTeam/boring.notch), [Alcove](https://tryalcove.com), [Stats](https://github.com/exelban/stats), [Open Meteo](https://open-meteo.com), [SkyLightWindow](https://github.com/Lakr233/SkyLightWindow), [rtaudio](https://github.com/ZephyrCodesStuff/rtaudio), [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm), [DynamicNotch](https://github.com/jackson-storm/DynamicNotch), Wick i [OpenUsage](https://github.com/robinebers/openusage).

Gesty gładzika: [YuriGao/slidr-free](https://github.com/YuriGao/slidr-free) (MIT, licencja w `DynamicIsland/TrackpadGestures/LICENSE-slidr-free.txt`). Haptyka przez `MTActuator` wzorowana na [Glissé](https://github.com/helgafinn/glisse) (MIT).
