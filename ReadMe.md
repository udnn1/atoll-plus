<div align="center">

# Atoll Plus

**Dynamic Island dla macOS — z licznikiem limitu Claude, gestami gładzika, klawiaturą w stylu Windows i polskim interfejsem.**

[![macOS](https://img.shields.io/badge/macOS-14%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](#budowanie-i-instalacja)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://developer.apple.com/swiftui/)
[![Xcode](https://img.shields.io/badge/Xcode-27-147EFB?style=for-the-badge&logo=xcode&logoColor=white)](#budowanie-i-instalacja)
[![License](https://img.shields.io/badge/licencja-GPL--3.0-3DA639?style=for-the-badge&logo=gnu&logoColor=white)](LICENSE)

[![Bazuje na Atoll](https://img.shields.io/badge/bazuje_na-Ebullioscopic%2FAtoll-6E40C9?style=flat-square&logo=github)](https://github.com/Ebullioscopic/Atoll)
[![Polski](https://img.shields.io/badge/interfejs-polski-DC143C?style=flat-square)](#-polski-interfejs)
[![Claude](https://img.shields.io/badge/limit-Claude-D97757?style=flat-square&logo=anthropic&logoColor=white)](#-licznik-limitu-claude)
[![Last commit](https://img.shields.io/github/last-commit/udnn1/atoll-plus?style=flat-square&label=ostatnia%20zmiana)](https://github.com/udnn1/atoll-plus/commits/main)
[![Repo size](https://img.shields.io/github/repo-size/udnn1/atoll-plus?style=flat-square&label=rozmiar)](https://github.com/udnn1/atoll-plus)

</div>

> [!NOTE]
> **Nieoficjalna wersja**, niezwiązana z twórcami Atolla. Nazwa „Atoll” należy do jej właścicieli (zob. [TRADEMARKS](TRADEMARKS)). Oryginał: [Ebullioscopic/Atoll](https://github.com/Ebullioscopic/Atoll).

## ✨ Co dodaje

Jedna aplikacja zamiast kilku — wszystko startuje razem z Atollem, bez osobnych wpisów w autostarcie.

| | Funkcja | Gdzie | Zastępuje |
|:-:|---|---|---|
| 🟠 | Pierścień z limitem Claude w wyspie + karta **Limity** | Ustawienia → Statystyki · menu na pasku → **Limit Claude** | claude-tray |
| 🖐️ | Gesty na krawędziach i rogach gładzika, środkowe kliknięcie, haptyka | Ustawienia → **Gładzik** | Slidr-Free |
| ⌨️ | Klawiatura w stylu Windows (Ctrl tam, gdzie w Windowsie), Caps Lock bez opóźnienia | Ustawienia → **Klawiatura** | Karabiner-Elements |
| 🔊 | Pionowy pasek głośności i jasności przy prawej krawędzi | Ustawienia → Sterowanie → **Pionowy pasek** | MediaMate |
| 🇵🇱 | Interfejs po polsku | język systemu | — |

---

## 🟠 Licznik limitu Claude

Zamknięta wyspa pokazuje pierścień z aktualnym zużyciem limitu Claude — tak jak ikona `claude-tray` na pasku menu.

- **Kolor wg zużycia:** 🟢 < 50% · 🟡 50–74% · 🟠 75–89% · 🔴 ≥ 90%
- **Liczba:** limit 5h albo 7d (do wyboru); pierścień można wyłączyć i zostawić samą liczbę.
- **Najechanie na pierścień** otwiera kartę **Limity**: limit 5h i 7d, godzina resetu („dziś o 17:20”), ostatni i następny odczyt, przycisk **Odśwież teraz**.
- **Zawsze przy notchu:** pierścień stoi 2 pt od fizycznego notcha. Gdy pojawia się inna aktywność (muzyka, Caps Lock, timer, nagrywanie, pobieranie…), zostaje na miejscu, a nowa rzecz dochodzi dalej na zewnątrz — bez migania i przesuwania.
- **Nie zasłania menu:** gdy menu aplikacji dochodzą do notcha, pierścień przechodzi na prawą stronę.
- Krótkie komunikaty (ładowarka, podgląd utworu, HUD-y) na chwilę go zastępują i znikają.

<details>
<summary><b>Skąd dane i jak często</b></summary>

- Token OAuth z aplikacji Claude Desktop (`~/Library/Application Support/Claude/config.json`), odszyfrowany kluczem „Claude Safe Storage” z Pęku kluczy.
- Zapytanie do `https://api.anthropic.com/api/oauth/usage`; wygasły token jest odświeżany przez `refresh_token`.
- Tempo: start co 120 s, przedział 60–900 s, rzadziej przy bezczynności, wolniej po odpowiedzi 429.
- Dane starsze niż 20 min → pierścień pokazuje „?”.
- Stan i zaszyfrowany token: `~/Library/Application Support/ClaudeLimitTray/` (zgodne z claude-tray).

</details>

---

## 🖐️ Gesty gładzika

Wbudowany [Slidr-Free](https://github.com/YuriGao/slidr-free) — działa w procesie Atolla, **tylko na fizycznym gładziku** (MacBook z otwartą klapą lub Magic Trackpad).

| Gest | Działanie |
|---|---|
| ↕️ Palec przy **lewej** krawędzi | jasność |
| ↕️ Palec przy **prawej** krawędzi | głośność |
| ↔️ Palec przy **górnej** krawędzi | poprzednia / następna karta (Safari, Chrome, Edge) |
| 👆👆 Podwójne stuknięcie w **róg** | otwiera przypisaną aplikację (lub minimalizuje jej okno) |
| 🤏 Stuknięcie 3 lub 4 palcami | środkowe kliknięcie |

- **Haptyka** przez silniczek gładzika — suwak **Siła haptyki** 1–6 z przyciskiem **Wypróbuj**.
- Głośność i jasność z gestów pokazują HUD Atolla (pionowy pasek).
- Pełna konfiguracja: szerokość strefy krawędzi, odległość na krok, strefy rogów, 15-sekundowy bezpieczny test gestów.

---

## ⌨️ Klawiatura w stylu Windows

Skróty pod palcami tak jak w Windowsie: **kopiuj, wklej, zapisz** wciskasz lewym klawiszem w rogu (Ctrl+C, Ctrl+V, Ctrl+S), a nie kciukiem na ⌘. Zamiana działa przez systemowe `hidutil` — **bez przechwytywania klawiatury**, więc nie spowalnia systemu jak Karabiner.

| Wciskasz | Mac dostaje | Po co |
|---|---|---|
| lewy **Ctrl** | ⌘ Command | Ctrl+C / Ctrl+V / Ctrl+Z jak w Windowsie |
| lewy **⌘** | ⌃ Control | Control nadal dostępny, tylko w innym miejscu |
| prawy **⌘** | ⌥ Option | polskie znaki (ą, ę, ś…) prawym klawiszem obok spacji, jak AltGr |
| prawy **⌥** | ⌘ Command | Command po prawej stronie |
| **Caps Lock** | bez opóźnienia | reaguje od razu, bez przytrzymania |

- Własne zamiany: lista **klawisz → klawisz** w Ustawienia → **Klawiatura** (Control, Shift, Option, Command, Caps Lock, Escape, Tab, Return, Delete, `, §, Fn — lewe i prawe osobno), dodawanie, usuwanie i **Przywróć domyślne** (powrót do układu w stylu Windows).
- **Caps Lock bez opóźnienia.**
- Ponawiane automatycznie po podłączeniu klawiatury (np. Bluetooth) i wybudzeniu Maca. Zmiany działają od razu.

---

## 🛠️ Poprawki względem oryginału

| Problem w Atollu | W Atoll Plus |
|---|---|
| Na monitorze bez notcha animacje (ładowanie, muzyka) grały za krawędzią ekranu | ukryta wyspa wysuwa się na czas animacji |
| Po przewinięciu kółkiem myszy (np. Logitech) zawartość notcha zostawała rozmyta | rozmycie znika po 0,3 s bez przewijania |
| Odsuwanie wyspy od menu przesuwało tylko zawartość — animacje były ucinane | przesuwa się cały kształt; na ekranie z notchem lewe skrzydło chowa się przy krawędzi notcha |
| Pomiar menu (np. Firefox) czasem się gubił | ostatni wynik dla tej samej aplikacji nie jest gubiony |
| „100” z wtyczką dotykało krawędzi ikony baterii | margines wewnątrz ikony |
| Przy starcie wyskakiwał regulator głośności | brak |
| Restart Atolla zabierał fokus aktywnej aplikacji | start w tle |

---

## 🇵🇱 Polski interfejs

- Wszystkie tłumaczalne teksty Atolla mają wersję polską (wcześniej ok. 10%).
- Teksty, które oryginał wyświetlał z pominięciem tłumaczeń (komunikaty o uprawnieniach, statusy integracji, nazwy trybów, wyniki wyszukiwania), też są przetłumaczone.
- Panele Gładzik, Klawiatura i Limity są po polsku.

---

## 📦 Budowanie i instalacja

**Wymagania:** macOS 14+, Xcode z Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`).

```bash
git clone https://github.com/udnn1/atoll-plus.git
cd atoll-plus
./scripts/build-local.sh
```

| Skrypt | Co robi |
|---|---|
| `scripts/build-local.sh` | build przyrostowy (~15 s po zmianie zamiast ~100 s), potem instalacja; `--no-install` tylko buduje |
| `scripts/install-local.sh` | podpisuje stałym lokalnym certyfikatem, podmienia `/Applications/Atoll.app`, uruchamia w tle |

> [!TIP]
> Stały lokalny podpis sprawia, że uprawnienie **Dostępność** nadane raz zostaje przy kolejnych wersjach. Certyfikat „Atoll Local Signing” trzeba utworzyć u siebie — skrypt korzysta z pęku kluczy `~/Library/Keychains/atoll-signing.keychain-db`.

---

## 🔐 Uprawnienia i prywatność

| Uprawnienie | Po co |
|---|---|
| **Dostępność** | klawisze głośności i jasności, odczyt menu i ikon statusu, gesty, środkowe kliknięcie |
| **Pęk kluczy** | odczyt „Claude Safe Storage” do odszyfrowania tokenu Claude Desktop |
| Kalendarz, kamera, nagrywanie ekranu, muzyka | tylko dla funkcji, które ich wymagają |

Token Claude trafia wyłącznie do `api.anthropic.com`. Repozytorium nie zawiera żadnych kluczy ani tokenów.

---

<details>
<summary><b>🗂️ Gdzie są zmiany w kodzie</b></summary>

| Ścieżka | Zawartość |
|---|---|
| `DynamicIsland/managers/ClaudeLimit/` | pobieranie limitu Claude |
| `DynamicIsland/components/ClaudeLimit/` | pierścień, karta Limity, miejsce na pierścień w aktywnościach |
| `DynamicIsland/TrackpadGestures/` | Slidr-Free, haptyka, polski słownik panelu |
| `DynamicIsland/managers/KeyboardRemapper.swift` | mapowanie klawiszy i zakładka Klawiatura |
| `DynamicIsland/Localizable.xcstrings` | tłumaczenia |
| `scripts/` | build i instalacja |

</details>

<details>
<summary><b>🔄 Aktualizacje</b></summary>

Atoll Plus **nie ma automatycznych aktualizacji** — każdy buduje aplikację sam ze źródeł. Wbudowany w oryginał aktualizator (Sparkle) jest wyłączony: nie sprawdza nowych wersji, a z menu i Ustawień zniknęły „Sprawdź aktualizacje” i wybór kanału. Gdyby działał, zainstalowałby oficjalny Atoll w miejsce Atoll Plus.

Nowa wersja:

```bash
git pull
./scripts/build-local.sh
```

Zmiany z oryginalnego Atolla można dociągnąć ręcznie:

```bash
git remote add upstream https://github.com/Ebullioscopic/Atoll.git
git fetch upstream
git merge upstream/dev
```

</details>

---

## 📜 Licencja i podziękowania

[GPL-3.0](LICENSE) — tak jak oryginał.

- [**Ebullioscopic/Atoll**](https://github.com/Ebullioscopic/Atoll) — podstawa projektu, wraz z projektami, z których korzysta: [Boring.Notch](https://github.com/TheBoredTeam/boring.notch), [Alcove](https://tryalcove.com), [Stats](https://github.com/exelban/stats), [Open Meteo](https://open-meteo.com), [SkyLightWindow](https://github.com/Lakr233/SkyLightWindow), [rtaudio](https://github.com/ZephyrCodesStuff/rtaudio), [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm), [DynamicNotch](https://github.com/jackson-storm/DynamicNotch), Wick, [OpenUsage](https://github.com/robinebers/openusage)
- [**YuriGao/slidr-free**](https://github.com/YuriGao/slidr-free) — gesty gładzika (MIT, [licencja](DynamicIsland/TrackpadGestures/LICENSE-slidr-free.txt))
- [**Glissé**](https://github.com/helgafinn/glisse) — wzór haptyki przez `MTActuator` (MIT)
