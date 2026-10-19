# Noctalia Tailscale

[English installation guide](README.en.md)

Widget paska i panel Tailscale dla **Noctalia 5.x**, plugin API ≥ 31. Dla użytkowników Arch Linux, Omarchy, innych pochodnych Archa oraz Fedory z DNF. Nie wymaga Omarchy ani konta autora. Sprawdzony z Noctalią 5.3.0. Starsza Noctalia Shell 4.x używa QML i nie jest obsługiwana.

Funkcje: połączenie i rozłączenie, logowanie przez link HTTPS (otwarcie lub skopiowanie), wybór exit node wraz ze statusem dostępności, dostęp do LAN przy użyciu exit node, akceptowanie tras podsieci, DNS Tailscale, blokowanie połączeń przychodzących, ogłaszanie tras IPv4/IPv6 i udostępnianie własnego exit node. Kliknięcie adresu kopiuje IP.

## Instalacja

Najpierw zainstaluj Noctalię 5.x zgodnie z [oficjalną instrukcją](https://docs.noctalia.dev/noctalia/getting-started/installation/). Ten instalator nie zastępuje powłoki pulpitu.

Pobierz repozytorium i uruchom instalator jako ten użytkownik, który uruchamia Noctalię (bez poprzedzania całego skryptu `sudo`):

```bash
git clone https://github.com/Jan-Bladek/noctalia-tailscale.git
cd noctalia-tailscale
./install.sh
```

Jedno polecenie automatycznie wykrywa Arch/Fedorę przez `ID` i `ID_LIKE`. Dostępne są również jawne warianty:

```bash
./installers/arch.sh       # Arch, Omarchy, EndeavourOS, CachyOS, Manjaro
./installers/fedora.sh     # Fedora z DNF 4 lub DNF 5
./install.sh --dry-run     # podgląd bez zmian
./install.sh --plugin-only # tylko pliki wtyczki, bez sudo i zmian systemowych
```

Aktualizacja istniejącej instalacji:

```bash
git pull --ff-only
./install.sh --plugin-only
```

Instalatory systemowe wymagają interaktywnego terminala i `sudo`. Instalują Tailscale, Python i xdg-utils, włączają usługę `tailscaled` oraz nadają bieżącemu użytkownikowi rolę operatora Tailscale. Arch wykonuje pełne `pacman -Syu`, unikając częściowej aktualizacji. Fedora używa [oficjalnego repozytorium Tailscale](https://pkgs.tailscale.com/stable/). Jeżeli plik repozytorium nie istnieje, pobiera go do pliku tymczasowego i instaluje po udanym pobraniu; doinstalowuje curl, jeśli go brakuje. Nie wymaga wtyczki `dnf config-manager`, dzięki czemu ta sama procedura działa z DNF 4 i DNF 5.

Instalator wyznacza użytkownika przez `id -un`, nie przez nazwę wpisaną w kodzie ani zmienną `$USER`. Domyślna ścieżka to `${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/tailscale`; `NOCTALIA_DATA_HOME` ma pierwszeństwo przed `XDG_DATA_HOME`, a `NOCTALIA_STATE_HOME` przed `XDG_STATE_HOME`, zgodnie z zachowaniem Noctalii. Ścieżki muszą być absolutne; katalogi ze spacjami są obsługiwane. Istniejący katalog jest kopiowany przed aktualizacją do `${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/plugin-backups`, poza katalogiem wykrywania pluginów. Starsze kopie `tailscale.backup.*` są tam automatycznie przenoszone, aby nie zastępowały nowego kodu. W Noctalii włącz **Settings → Plugins → Jan-Bladek/tailscale**, a następnie dodaj do paska **Jan-Bladek/tailscale:status**. Jeżeli plugin jeszcze nie pojawił się na liście, uruchom ponownie Noctalię.

Identyfikator `Jan-Bladek/tailscale` jest stałą nazwą autora/projektu w systemie pluginów. Nie oznacza konta użytkownika i nie należy go zmieniać przy instalacji. Logowanie, tailnet, adresy IP i exit nodes są odczytywane z lokalnego demona Tailscale.

Tailscale ma jedną rolę operatora na demon. Jeżeli należy już do innego użytkownika, instalator nie zastąpi jej bez jawnej opcji:

```bash
./install.sh --skip-operator     # zachowaj aktualnego operatora
./install.sh --replace-operator  # przekaż tę rolę bieżącemu użytkownikowi
```

`--skip-operator` nie nadaje nowych uprawnień: przyciski zarządzania wymagają istniejących uprawnień operatora. Wtyczka nie tworzy osobnego konta Tailscale dla każdego użytkownika systemowego.

Fedora Atomic (Silverblue, Kinoite i podobne) wymaga instalacji Tailscale na hoście przez `rpm-ostree`, ponownego uruchomienia i konfiguracji usługi/operatora przez administratora. Następnie działa `./install.sh --plugin-only`. Automatyczna instalacja systemowa obsługuje Fedorę z DNF, nie instalację wewnątrz Toolbox/Distrobox.

Plugin można też instalować jako źródło Git: katalog główny zawiera `catalog.toml`, a plugin znajduje się w `tailscale/`.

## Logowanie i sieć

Na pasku widoczna jest ikona Tailscale: zwykła po połączeniu, przekreślona po rozłączeniu. Lewy przycisk otwiera panel, prawy przełącza połączenie. Panel ma nagłówek z przełącznikiem, listę exit node i zwijane ustawienia zaawansowane, wzorowane na panelu Omarchy. Ikony SVG przejmują kolory bieżącego motywu.

Kliknij widget i włącz przełącznik albo wybierz **Sign in to Tailscale**. Po otrzymaniu adresu plugin otworzy przeglądarkę. Można też kliknąć sam adres lub **Open login link**, albo skopiować go przyciskiem **Copy link**. Dokończ logowanie w przeglądarce. Stan odświeża się co 3 sekundy. Połączenie i logowanie uruchamiają `tailscale up` bez flag, zachowując wszystkie zapisane preferencje. Czas oczekiwania ogranicza Python, a nie flaga CLI `--timeout` — jej dodanie uruchamia kontrolę niepełnych preferencji w Tailscale. Adres jest odczytywany z `AuthURL` demona. Oczekiwanie CLI może się zakończyć przed autoryzacją w przeglądarce. Jeżeli adres wygasł, ponownie pobierz link. Widget nie przechowuje kluczy uwierzytelniających ani adresu logowania na dysku.

**Disconnect** używa `tailscale down`: konto i preferencje pozostają zapisane. Zmiany preferencji korzystają z `tailscale set` i modyfikują tylko wybraną opcję.

Pole podsieci przyjmuje adresy sieci w CIDR, np. `192.168.1.0/24,fd00::/64`. Puste pole usuwa ogłaszane podsieci. Błędne adresy, adresy hostów z niezerowymi bitami sieci oraz trasy domyślne są odrzucane. Trasy domyślne obsługuje przełącznik exit node. Podsieci innych urządzeń są akceptowane wspólnie, zgodnie z flagą Tailscale `--accept-routes`; CLI nie oferuje wyboru pojedynczej zdalnej podsieci.

Ogłaszanie podsieci lub exit node wymaga osobnego włączenia przekazywania IP w systemie i zatwierdzenia w konsoli administratora tailnetu. Instalator nie zmienia routingu ani sysctl. Panel pokazuje ostrzeżenia demona i otwiera konsolę administracyjną.

Brak uprawnień operatora można naprawić w terminalu:

```bash
sudo systemctl enable --now tailscaled
sudo tailscale set --operator="$(id -un)"
```

## Konstrukcja

Analiza oparta na [dokumentacji pluginów Noctalii](https://docs.noctalia.dev/noctalia/plugins/development/), [runtime API](https://docs.noctalia.dev/noctalia/plugins/development/runtime-api/), [deklaratywnym UI](https://docs.noctalia.dev/noctalia/plugins/development/declarative-ui/) i [Tailscale CLI](https://tailscale.com/docs/reference/tailscale-cli).

- `plugin.toml` deklaruje trzy niezależne wpisy Luau: service, widget i panel.
- `service.luau` jest jedynym wykonawcą poleceń; okresowo odpytuje backend i publikuje stan przez `noctalia.state`. Blokuje nakładające się operacje.
- `widget.luau` pokazuje ikonę stanu na pasku i otwiera panel. `icons.luau` generuje wariant połączony/rozłączony zgodnie z paletą motywu w katalogu danych pluginu.
- `panel.luau` buduje natywne kontrolki `ui.*`, zachowujące paletę Noctalii. Wysyła żądania do usługi.
- `backend.py` wywołuje lokalny CLI przez tablice argumentów bez shella, waliduje adresy i zwraca JSON. Nie podnosi uprawnień. `tailscale debug prefs` służy do odczytu preferencji i może zmienić format w przyszłych wersjach; jego błąd blokuje odpowiednie przełączniki, ale nie ukrywa stanu połączenia.

## Weryfikacja

```bash
python3 -m unittest discover -s tests -v
lua tests/test_ui.lua
noctalia plugins lint tailscale
bash -n install.sh installers/arch.sh installers/fedora.sh
```

Testy obejmują walidację tras, ochronę przed wstrzyknięciem argumentów, odczyt exit nodes, błędy uprawnień, link logowania po timeout i interakcje panelu z atrapą API Noctalii. W wersji 1.1.0 sprawdzono połączenie i rozłączenie w działającej sesji Noctalii 5.3.0 na Omarchy, z zachowaniem istniejącego exit node i tras. Sprawdzono także wygląd panelu w sesji oraz aktualizację lokalnej instalacji. Logowanie nowego konta i otwarcie linku sprawdzono testami z atrapami; rzeczywistego konta nie wylogowywano. Testy instalatora wykonują rzeczywiste kopiowanie plików w katalogach tymczasowych, z atrapami poleceń administracyjnych i sieciowych, dla Arch i Fedory oraz użytkownika `alice`. Obejmują własne katalogi Noctalii, spacje w ścieżkach, pobieranie/ponowne użycie repozytorium Fedory i zachowanie istniejącego operatora. CI uruchamia testy również w kontenerach Arch Linux i Fedora. Instalacji systemowej na fizycznej Fedorze nie wykonano.

## Publikacja repozytorium

Repozytorium Git jest przygotowane lokalnie. Po `gh auth login` uruchom `./publish.sh`: utworzy publiczne repozytorium `noctalia-tailscale` na bieżącym koncie i wyśle gałąź `main`. Jeżeli istnieje już `origin`, wyśle kod do niego.

## Usunięcie

Wyłącz plugin i usuń widget w ustawieniach Noctalii, następnie usuń wyłącznie katalog pluginu `~/.local/share/noctalia/plugins/tailscale` (lub odpowiednik w `$XDG_DATA_HOME`). Tailscale i jego preferencje są niezależne od pluginu. Aby odebrać rolę operatora, wykonaj `sudo tailscale set --operator=`.

Licencja [PolyForm Noncommercial 1.0.0](LICENSE): korzystanie, modyfikowanie i udostępnianie kodu do dozwolonych celów niekomercyjnych. Użycie komercyjne wymaga osobnej zgody autora. Pełne warunki, w tym dozwolone zastosowania osobiste i zastosowania określonych organizacji, opisuje LICENSE. Dokumentacja projektu jest udostępniana na tych samych warunkach. Projekt niezależny od Noctalii i Tailscale.
