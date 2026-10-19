# Noctalia Tailscale

Widget paska i panel Tailscale dla **Noctalia 5.x**, plugin API ≥ 24. Przygotowany pod lokalnie zainstalowaną Noctalię 5.3.0. Starsza Noctalia Shell 4.x używa QML i nie jest obsługiwana.

Funkcje: połączenie i rozłączenie, logowanie przez link HTTPS (otwarcie lub skopiowanie), wybór exit node wraz ze statusem dostępności, dostęp do LAN przy użyciu exit node, akceptowanie tras podsieci, DNS Tailscale, blokowanie połączeń przychodzących, ogłaszanie tras IPv4/IPv6 i udostępnianie własnego exit node. Kliknięcie adresu kopiuje IP.

## Instalacja

Najpierw zainstaluj Noctalię 5.x zgodnie z [oficjalną instrukcją](https://docs.noctalia.dev/noctalia/getting-started/installation/). Ten instalator nie zastępuje powłoki pulpitu.

Z katalogu pobranego repozytorium uruchom jako zwykły użytkownik:

```bash
# Arch Linux i pochodne
./installers/arch.sh

# Fedora
./installers/fedora.sh

# Same pliki pluginu, jeżeli zależności i uprawnienia są już skonfigurowane
./install.sh

# Podgląd komend bez wykonywania zmian
./install.sh --setup-system --dry-run
```

Instalatory systemowe wymagają interaktywnego terminala i `sudo`. Instalują Tailscale, Python i xdg-utils, włączają usługę `tailscaled` oraz nadają bieżącemu użytkownikowi rolę operatora Tailscale. Arch wykonuje pełne `pacman -Syu`, unikając częściowej aktualizacji. Fedora pobiera plik repozytorium RPM z `pkgs.tailscale.com` tylko gdy Tailscale nie jest jeszcze zainstalowany.

Pliki trafiają do `${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/tailscale`. Istniejący katalog jest kopiowany do kopii zapasowej przed aktualizacją. W Noctalii włącz **Settings → Plugins → Jan-Bladek/tailscale**, a następnie dodaj do paska **Jan-Bladek/tailscale:status**. Jeżeli plugin jeszcze nie pojawił się na liście, uruchom ponownie Noctalię.

Plugin można też instalować jako źródło Git: katalog główny zawiera `catalog.toml`, a plugin znajduje się w `tailscale/`.

## Logowanie i sieć

Kliknij widget, potem **Sign in / Get login link**, a po otrzymaniu adresu **Open login link**. Dokończ logowanie w przeglądarce. Stan odświeża się co 3 sekundy. Logowanie uruchamia `tailscale up --timeout=5s`; adres jest odczytywany z `AuthURL` demona. Oczekiwanie CLI może się zakończyć przed autoryzacją w przeglądarce. Jeżeli adres wygasł, ponownie pobierz link. Widget nie przechowuje kluczy uwierzytelniających ani adresu logowania na dysku.

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
- `widget.luau` pokazuje stan na pasku i otwiera panel.
- `panel.luau` buduje natywne kontrolki `ui.*`, zachowujące paletę Noctalii. Wysyła żądania do usługi.
- `backend.py` wywołuje lokalny CLI przez tablice argumentów bez shella, waliduje adresy i zwraca JSON. Nie podnosi uprawnień. `tailscale debug prefs` służy do odczytu preferencji i może zmienić format w przyszłych wersjach; jego błąd blokuje odpowiednie przełączniki, ale nie ukrywa stanu połączenia.

## Weryfikacja

```bash
python3 -m unittest discover -s tests -v
lua tests/test_ui.lua
noctalia plugins lint tailscale
bash -n install.sh installers/arch.sh installers/fedora.sh
```

Testy obejmują walidację tras, ochronę przed wstrzyknięciem argumentów, odczyt exit nodes, błędy uprawnień, link logowania po timeout i interakcje panelu z atrapą API Noctalii. Przed wydaniem należy wykonać test w działającej sesji Noctalii z aktywnym `tailscaled`, a instalatory sprawdzić na Arch i Fedorze. W środowisku tworzenia dostęp do socketu demona był blokowany; testu rzeczywistego logowania i routingu nie wykonano.

## Publikacja repozytorium

Repozytorium Git jest przygotowane lokalnie. Po `gh auth login` uruchom `./publish.sh`: utworzy prywatne repozytorium `noctalia-tailscale` na bieżącym koncie i wyśle gałąź `main`. Jeżeli istnieje już `origin`, wyśle kod do niego.

## Usunięcie

Wyłącz plugin i usuń widget w ustawieniach Noctalii, następnie usuń wyłącznie katalog pluginu `~/.local/share/noctalia/plugins/tailscale` (lub odpowiednik w `$XDG_DATA_HOME`). Tailscale i jego preferencje są niezależne od pluginu. Aby odebrać rolę operatora, wykonaj `sudo tailscale set --operator=`.

Licencja MIT. Projekt niezależny od Noctalii i Tailscale.
