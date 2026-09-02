#!/bin/sh
# capture.sh — take the repo's screenshots.
#
# Stages a clean workspace, drives the house shell over its IPC, cycles the four
# tables, and grims the lot into this directory. Your real windows stay on the
# workspace you were on and never enter frame.
#
#   ./assets/screenshots/capture.sh              # everything
#   ./assets/screenshots/capture.sh desktop      # just the hero shot
#   ./assets/screenshots/capture.sh tables games # a couple of groups
#
# Groups: desktop tables launcher picker notifications games
#
# Needs: grim, hyprctl, qs, kitty, btop, notify-send. Nothing else.

set -eu

here=$(dirname "$(readlink -f "$0")")
repo=$(readlink -f "$here/../..")
house="$repo/house"
out="$here"

# How long to let things land before the shutter: theme changes animate, windows
# fade in, hyprctl reload repaints. Bump it if a shot catches a transition.
settle=${SETTLE:-1.2}

# Workspace to stage on. Named, so it can't collide with a numbered one you use.
stage=${STAGE:-name:shots}

# Padding around per-window shots (the games), in pixels.
pad=${PAD:-24}

for t in grim hyprctl qs kitty notify-send; do
    command -v "$t" >/dev/null 2>&1 || { echo "capture: missing $t" >&2; exit 1; }
done

mkdir -p "$out"

# --- the desktop, as the compositor sees it ----------------------------------

# Everything below frames against one monitor. Override with MON=DP-4.
mon=${MON:-$(hyprctl -j monitors | python3 -c 'import json,sys
print(next(m["name"] for m in json.load(sys.stdin) if m["focused"]))')}

monrect=$(hyprctl -j monitors | python3 -c 'import json,sys
m = next(m for m in json.load(sys.stdin) if m["name"] == sys.argv[1])
print(m["x"], m["y"], m["width"], m["height"])' "$mon")

# addr <tab> class <tab> x y w h, one line per window.
clients() {
    hyprctl -j clients | python3 -c 'import json,sys
for c in json.load(sys.stdin):
    print(c["address"], c["class"], c["at"][0], c["at"][1], c["size"][0], c["size"][1], sep="\t")'
}

# The whole monitor.
shot() {
    sleep "$settle"
    grim -o "$mon" "$out/$1.png"
    echo "  → $1.png"
}

# One window, padded, clamped to the monitor. shot_window <addr> <name>
shot_window() {
    sleep "$settle"
    geo=$(clients | awk -v a="$1" -F'\t' '$1 == a { print $3, $4, $5, $6 }')
    [ -n "$geo" ] || { echo "capture: window $1 vanished, skipping $2" >&2; return; }
    # shellcheck disable=SC2086
    set -- $geo $monrect "$pad" "$2"
    g=$(python3 -c 'import sys
x, y, w, h, mx, my, mw, mh, p = map(int, sys.argv[1:10])
l, t = max(mx, x - p), max(my, y - p)
r, b = min(mx + mw, x + w + p), min(my + mh, y + h + p)
print(f"{l},{t} {r - l}x{b - t}")' "$@")
    grim -g "$g" "$out/${10}.png"
    echo "  → ${10}.png"
}

ipc() { qs -p "$house" ipc call "$@" >/dev/null 2>&1 || true; }

# --- tables -------------------------------------------------------------------
# The six roles per table, mirroring house/Config.qml's `themes`. Kept here
# rather than parsed out of the QML: this is the one place a fifth table would
# need adding, and a regex over Config.qml is a worse thing to own.
#
# Order: surface text subtext accent idle urgent

roles() {
    case "$1" in
        noir)     echo "#0e0b0d #e8ddc4 #8a7f6d #d4af5f #2a2320 #c13a4e" ;;
        felt)     echo "#0e2b1c #eae3cd #7fa08c #c9a227 #1d4030 #c0392f" ;;
        vegas)    echo "#0a0a14 #eaeaf2 #6b6f92 #ff2e88 #1c1c30 #ff6247" ;;
        daylight) echo "#f5efe2 #46392c #8c7f6a #9c7a1e #e6dcc6 #b3372f" ;;
        *)        echo "capture: unknown table $1" >&2; return 1 ;;
    esac
}

# The shell's persisted choice. It's a FileView with watchChanges, so writing
# this retints the bar live; apply-theme.sh is what carries the table out to
# Hyprland, kitty, GTK/Qt, the wallpaper and the games. Config.setTheme() does
# both, and there's no IPC for it, so we do both too.
prefs=$(find "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell" -name theme.json 2>/dev/null | head -1)

set_table() {
    roles=$(roles "$1") || exit 1
    if [ -n "$prefs" ]; then
        printf '{\n    "theme": "%s"\n}\n' "$1" > "$prefs"
    fi
    # shellcheck disable=SC2086
    sh "$house/scripts/apply-theme.sh" "$1" $roles
    sleep "$settle"
}

# --- staging ------------------------------------------------------------------

was_ws=$(hyprctl -j activeworkspace | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])')
was_table=noir
if [ -n "$prefs" ]; then
    was_table=$(python3 -c 'import json,sys
print(json.load(open(sys.argv[1])).get("theme", "noir"))' "$prefs" 2>/dev/null || echo noir)
fi

cleanup() {
    hyprctl -j clients | python3 -c 'import json,sys
for c in json.load(sys.stdin):
    if c["class"].startswith("shots-"): print(c["address"])' | while read -r a; do
        hyprctl dispatch closewindow "address:$a" >/dev/null 2>&1 || true
    done
    ipc launcher close
    ipc theme close
    ipc notifications closeAll
    if [ "$was_table" != "$current_table" ]; then
        set_table "$was_table" >/dev/null 2>&1 || true
    fi
    hyprctl dispatch workspace "$was_ws" >/dev/null 2>&1 || true
}
current_table=$was_table
trap cleanup EXIT INT TERM

# Two windows to fill the frame: the system monitor, and a terminal sitting in
# the repo so the prompt and the table's kitty palette are both in shot.
stage_windows() {
    if clients | cut -f2 | grep -q '^shots-'; then return 0; fi
    kitty --class shots-btop -e btop >/dev/null 2>&1 &
    sleep 1
    kitty --class shots-term -d "$repo" >/dev/null 2>&1 &
    sleep 2
}

# No arguments means every group.
groups=${*:-}
want_group() {
    if [ -z "$groups" ]; then return 0; fi
    for g in $groups; do
        if [ "$g" = "$1" ]; then return 0; fi
    done
    return 1
}

echo "capture: monitor $mon, staging on $stage"
hyprctl dispatch workspace "$stage" >/dev/null

# --- desktop + tables ---------------------------------------------------------

if want_group desktop || want_group tables; then
    stage_windows
fi

if want_group desktop; then
    echo "desktop:"
    set_table noir; current_table=noir
    shot desktop
fi

if want_group tables; then
    echo "tables:"
    for t in noir felt vegas daylight; do
        set_table "$t"; current_table=$t
        shot "table-$t"
    done
    set_table noir; current_table=noir
fi

# --- the overlays -------------------------------------------------------------

if want_group launcher; then
    echo "launcher:"
    ipc launcher open
    shot launcher
    ipc launcher close
fi

if want_group picker; then
    echo "picker:"
    ipc theme open
    shot table-picker
    ipc theme close
fi

if want_group notifications; then
    echo "notifications:"
    notify-send -u low   "Table swept" "The dealer takes the pot."
    notify-send -u normal "♠ the house" "Noir table. The house always wins."
    notify-send -u critical "Bust" "Twenty-three. The house hits you."
    shot notifications
    ipc notifications closeAll
fi

# --- the games ----------------------------------------------------------------
# Each one is its own qs process. Launch it, wait for the window to exist, centre
# it, shoot it alone, then close it — the games' READMEs want the widget, not the
# desktop behind it.

game() {
    slug=$1; entry=$2
    before=$(clients | cut -f1)
    setsid qs -p "$repo/games/$entry" >/dev/null 2>&1 &
    addr=""
    n=0
    while [ "$n" -lt 40 ]; do
        sleep 0.25
        addr=$(clients | cut -f1 | grep -vxF "$before" | head -1 || true)
        [ -n "$addr" ] && break
        n=$((n + 1))
    done
    [ -n "$addr" ] || { echo "capture: $slug never opened, skipping" >&2; return; }
    hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 || true
    hyprctl dispatch centerwindow >/dev/null 2>&1 || true
    shot_window "$addr" "game-$slug"
    hyprctl dispatch closewindow "address:$addr" >/dev/null 2>&1 || true
    sleep 0.5
}

if want_group games; then
    echo "games:"
    game blackjack  bjak/blackjack.qml
    game roulette   rolt/roulette.qml
    game poker      pokr/poker.qml
    game bones      bons/bns.qml
    game ridethebus busride/ridethebus.qml
fi

echo "capture: done — $out"
