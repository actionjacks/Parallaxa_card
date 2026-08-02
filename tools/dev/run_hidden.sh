#!/usr/bin/env bash
# URUCHOMIENIE GRY W TLE — calkiem poza Twoim monitorem, zero okien i zero mrugania.
#
# Gra do testow MUSI miec okno: zrzuty i przeklik czekaja na RenderingServer.frame_post_draw, a dummy-renderer
# (--headless) tej klatki nigdy nie rysuje. Dajemy jej wiec WLASNY, NIEWIDZIALNY EKRAN:
#   Xvfb  — wirtualny serwer X bez zadnego okna (domyslny; nic sie nie pojawia na pulpicie),
#   Xephyr — zapas, gdy Xvfb nie ma w systemie (zagniezdzony ekran w oknie, parkowany pod inne okna).
# Ekran startuje RAZ i zyje miedzy uruchomieniami.
#
#   tools/dev/run_hidden.sh tools/capture.tscn
#   tools/dev/run_hidden.sh tools/przeklik.tscn -- --godmode
#   tools/dev/run_hidden.sh --peek   # zrzut tego, co WLASNIE widac na ukrytym ekranie -> screenshots/hidden_preview.png
#   tools/dev/run_hidden.sh --stop

set -u
EKRAN="${EKRAN_TLA:-:77}"
ROZDZ="1280x720x24"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"

# Wzorzec ZAKOTWICZONY: bez "^" pkill -f dopasowuje takze powloke, ktora ma ten napis w linii polecen,
# czyli zabija sam siebie. Kosztowalo mnie to dwa "niewyjasnione" wywalenia testu.
WZOR="^(Xvfb|Xephyr) ${EKRAN}"

_zyje() { pgrep -f "${WZOR}" >/dev/null; }

_park_xephyr() {   # tylko dla zapasowego Xephyr: okno na ostatnie biurko, pod spod, poza pasek zadan
	local win ostatnie
	ostatnie=$(($(wmctrl -d 2>/dev/null | wc -l) - 1))
	for _ in $(seq 50); do
		win=$(wmctrl -l 2>/dev/null | grep -F "Xephyr on ${EKRAN}" | head -1 | cut -d' ' -f1)
		if [ -n "${win:-}" ]; then
			[ "${ostatnie}" -gt 0 ] && wmctrl -i -r "${win}" -t "${ostatnie}" 2>/dev/null
			wmctrl -i -r "${win}" -b add,below,skip_taskbar,skip_pager 2>/dev/null
			return 0
		fi
		sleep 0.1
	done
	return 1
}

case "${1:-}" in
--stop)
	pkill -f "${WZOR}" && echo "ukryty ekran ${EKRAN}: zamkniety" || echo "ukryty ekran nie byl uruchomiony"
	exit 0
	;;
--peek|--podejrzyj)
	# Xvfb nie ma okna, wiec "zobaczyc, co sie dzieje" znaczy: zrob zrzut jego framebuffera.
	_zyje || { echo "ukryty ekran nie jest uruchomiony"; exit 1; }
	command -v import >/dev/null || { echo "brak ImageMagick (import) — nie mam czym zrobic zrzutu ekranu"; exit 1; }
	DISPLAY="${EKRAN}" import -window root "${REPO}/screenshots/hidden_preview.png" && echo "screenshots/hidden_preview.png"
	exit 0
	;;
esac

if ! _zyje; then
	if command -v Xvfb >/dev/null; then
		setsid Xvfb "${EKRAN}" -screen 0 "${ROZDZ}" -nolisten tcp >/dev/null 2>&1 < /dev/null &
	elif command -v Xephyr >/dev/null; then
		setsid Xephyr "${EKRAN}" -screen "${ROZDZ}" -ac >/dev/null 2>&1 < /dev/null &
	else
		echo "brak Xvfb i Xephyr — nie mam na czym uruchomic gry w tle"
		exit 1
	fi
	for _ in $(seq 60); do
		DISPLAY="${EKRAN}" xset q >/dev/null 2>&1 && break
		sleep 0.1
	done
	DISPLAY="${EKRAN}" xset q >/dev/null 2>&1 || { echo "nie udalo sie wystartowac ukrytego ekranu ${EKRAN}"; exit 1; }
	pgrep -f "^Xephyr ${EKRAN}" >/dev/null && _park_xephyr
fi

# URUCHOMIENIE + ODWROT NA PROGRAMOWY VULKAN.
# Xvfb nie ma DRI3, wiec sterownik GPU (u nas nvidia) potrafi ODMOWIC utworzenia urzadzenia Vulkan
# (VkResult -3) — objawia sie to zwlaszcza PO RESTARCIE maszyny, gdy przed nim wszystko dzialalo.
# Wtedy schodzimy na LAVAPIPE (programowy Vulkan z Mesy): wolniej, ale zrzuty i harness dzialaja bez GPU.
# Sprzet probujemy PIERWSZY, zeby nie placic wydajnoscia, gdy jest sprawny. Jesli ktos ustawil juz wlasny
# VK_ICD_FILENAMES — nie nadpisujemy go, to jego decyzja.
# --audio-driver Dummy: Xvfb ukrywa OBRAZ, ale dzwiek szedlby normalnie na glosniki (PulseAudio
# jest systemowe) — odkad gra ma muzyke w petli, zapomniana instancja testowa gralaby userowi
# w tle w nieskonczonosc. Ukryte testy nigdy nie potrzebuja slyszalnego audio.
_uruchom() { DISPLAY="${EKRAN}" "${GODOT}" --path "${REPO}" --audio-driver Dummy "$@"; }

LVP="/usr/share/vulkan/icd.d/lvp_icd.x86_64.json"
if [ -n "${VK_ICD_FILENAMES:-}" ] || [ ! -f "${LVP}" ]; then
	_uruchom "$@"
	exit $?
fi

# LAVAPIPE OD RAZU, bez proby sprzetowej. Probowanie GPU najpierw bylo sluszne, dopoki nieudana
# proba KONCZYLA SIE bledem: sterownik odmawial, skrypt czytal komunikat i powtarzal programowo.
# Teraz ta pierwsza proba nie pada, tylko WISI -- a `tee` czeka na nia w nieskonczonosc, wiec KAZDY
# harness zawieszal sie przed wypisaniem pierwszej linii. Zdiagnozowane trzylinijkowa sonda
# (tools/dev/probe_boot.gd), ktora tez wisiala: dowod, ze wina nigdy nie lezala w kodzie gry.
# Na tej maszynie Xvfb nie ma DRI3, wiec sprzetowa sciezka i tak nigdy nie dzialala.
# OPENGL, NIE VULKAN. Historia tego miejsca: sprzetowy Vulkan nie ma na Xvfb DRI3 i odmawia
# (VkResult -3), wiec skrypt schodzil na lavapipe -- i to dzialalo miesiacami. Programowy Vulkan
# na tej maszynie przestal padac i zaczal WISIEC przy inicjalizacji renderera, a `tee` czekalo na
# niego bez konca: KAZDY harness zawieszal sie, zanim wypisal pierwsza linie.
#
# Zdiagnozowane trzylinijkowa sonda (tools/dev/probe_boot.gd), ktora tez wisiala, a w zwyklym
# --headless konczyla sie natychmiast -- dowod, ze wina nie lezala ani w grze, ani w harnessach.
# Osiem hipotez po stronie kodu bylo obalonych zanim to wyszlo; sonda kosztowala trzy linie.
#
# opengl3 na llvmpipe startuje w kilka sekund i konczy czysto. Vulkan zostaje udokumentowany, bo
# gdy DRI3 wroci, sprzetowa sciezka bedzie znowu szybsza.
_uruchom --rendering-driver opengl3 "$@"
exit $?
