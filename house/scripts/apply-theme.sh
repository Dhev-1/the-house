#!/bin/sh
# apply-theme.sh — mirror the house bar's active table onto the rest of the
# desktop: Hyprland borders, the wallpaper, kitty, rofi, btop and starship.
#
# The theme picker (Config.setTheme in the house shell) calls this with the
# table's name and its six role colours. It is the single place system-wide
# theming is spelled out: to also drive another app, add a block here rather
# than teaching the shell about it.
#
# Args, in Config.themes order: name surface text subtext accent idle urgent
# Colours are "#rrggbb" hex strings; the leading # is optional.
#
# Per-table palettes that need more than the six roles (kitty's 16-colour deck,
# starship's segments) live pre-baked in tables/ next to this script; things the
# six roles can express (hypr, rofi) are generated right here.

set -eu

if [ "$#" -lt 7 ]; then
    echo "usage: $0 name surface text subtext accent idle urgent" >&2
    exit 2
fi

name=$1

# Strip a leading '#', if any, so the values slot straight into rgb()/rgba().
surface=${2#\#}
text=${3#\#}
subtext=${4#\#}
accent=${5#\#}
idle=${6#\#}
urgent=${7#\#}

here=$(dirname "$(readlink -f "$0")")
tables="$here/tables"
repo=$(readlink -f "$here/../..")
config="${XDG_CONFIG_HOME:-$HOME/.config}"

# --- colour helpers -----------------------------------------------------------
# Up here rather than beside the first block that happens to use them: Hyprland
# is generated first and needs mix() for the middle stop of the border gradient.

# dec RRGGBB -> "r, g, b", for the decimal rgba() hyprlock wants.
dec() {
    awk -v h="$1" 'BEGIN {
        printf "%d, %d, %d", strtonum("0x" substr(h,1,2)), strtonum("0x" substr(h,3,2)), strtonum("0x" substr(h,5,2));
    }'
}

# mix AABBCC DDEEFF t -> the two colours blended, t from first (0) to second (1).
mix() {
    awk -v a="$1" -v b="$2" -v t="$3" 'BEGIN {
        for (i = 0; i < 3; i++) {
            x = strtonum("0x" substr(a, 1 + i * 2, 2));
            y = strtonum("0x" substr(b, 1 + i * 2, 2));
            printf "%02x", int(x + (y - x) * t + 0.5);
        }
    }'
}

# lift AABBCC n -> every channel raised by n, clamped. Brightening a colour by
# mixing it toward white desaturates it on the way; adding a flat step keeps the
# hue where it was, which is what the games' brighter reds and golds want.
lift() {
    awk -v h="$1" -v n="$2" 'BEGIN {
        for (i = 0; i < 3; i++) {
            v = strtonum("0x" substr(h, 1 + i * 2, 2)) + n;
            printf "%02x", (v > 255) ? 255 : (v < 0 ? 0 : v);
        }
    }'
}

# Is this a light table? Daylight Robbery is the only one today, but nothing
# below hardcodes that - several derivations have to run the other way round on
# a light surface, and getting it from the colour is more honest than getting it
# from the name.
light=$(awk -v h="$surface" 'BEGIN {
    r = strtonum("0x" substr(h,1,2)); g = strtonum("0x" substr(h,3,2)); b = strtonum("0x" substr(h,5,2));
    print (0.2126 * r + 0.7152 * g + 0.0722 * b > 140) ? 1 : 0;
}')

# --- Hyprland -----------------------------------------------------------------
# The whole window style, not just the border colour: the rail (the line round
# the focused window) and the spotlight (how hard everything else is dimmed, and
# what colour the glow over the live one is). hyprland.lua holds the geometry
# and the motion; everything with a colour in it is here, so switching tables
# restyles the windows and not just the bar.
#
# Most of it falls out of the six roles. The exceptions get a case below, the
# same way kitty's 16-colour deck and starship's segments are pre-baked: the
# rail wants a third stop the roles do not name, and the dim wants a different
# weight on a light table, where 0.25 reads as muddy rather than as unlit.

# The default rail is a flat line of the accent, kept thin. The highlight on the
# focused window is meant to come from the glow underneath it, not from the
# border shouting - a multi-stop gradient round every window reads as busy once
# it is on screen all day rather than in a screenshot.
# The default rail is a flat line of the accent, kept thin. A gradient is a
# table in Lua rather than a space-separated string, so `rail` now holds a Lua
# expression - a quoted colour on most tables, a { colors = {...}, angle = N }
# literal on vegas - and is interpolated straight into the hl.config() call.
rail='"rgba('"${accent}"'ee)"'
bordersize=2
dim=0.25
glow=33      # alpha on the accent-tinted bloom under the focused window
unlit=88     # alpha on the flat black shadow under everything else

case "$name" in
    noir) ;;                       # the defaults are noir's
    felt)
        dim=0.22 ;;                # green is already dark; a full 0.25 buries it
    vegas)
        # The one table that keeps the gradient. Vegas is the strip at midnight
        # and is supposed to be loud, so it gets the full rail - pink, through
        # cyan bulbs, through the warm marquee orange and back - on a thicker
        # border, and the borderangle sweep on open actually has something to
        # move. Everywhere else that animation is a no-op, which is fine.
        rail='{ colors = { "rgba('"${accent}"'ee)", "rgba(2ee5ffee)", "rgba('"${urgent}"'ee)", "rgba('"${accent}"'ee)" }, angle = 115 }'
        bordersize=3
        dim=0.28 ;;
    daylight)
        dim=0.08                   # a light table. more than this and unfocused windows go grey, not dim
        glow=4d                    # gold on cream needs more of itself to show at all
        unlit=40 ;;                # and a full-strength black drop shadow looks like a bruise
esac

cat > "$config/hypr/colors.lua" <<EOF
-- AUTOGENERATED by cloon/newdot/house scripts/apply-theme.sh -- do not edit by hand.
-- Rewritten whenever a table is chosen in the house bar's picker; required from
-- hyprland.lua so the choice sticks across a restart. The returned table is here
-- for reuse (e.g. from binds or window rules, via require("colors")); the
-- hl.config() call below is what paints.

local M = {}

M.surface = "rgb($surface)"
M.text    = "rgb($text)"
M.subtext = "rgb($subtext)"
M.accent  = "rgb($accent)"
M.idle    = "rgb($idle)"
M.urgent  = "rgb($urgent)"

hl.config({
    general = {
        -- The rail. Flat accent on every table but vegas, which keeps the gradient.
        border_size = $bordersize,
        col = {
            active_border   = $rail,
            inactive_border = "rgba(${idle}55)",
        },
    },

    decoration = {
        -- The spotlight.
        dim_strength = $dim,
        shadow = {
            color          = "rgba(${accent}${glow})",
            color_inactive = "rgba(000000${unlit})",
        },
    },
})

return M
EOF

# --- hyprlock -----------------------------------------------------------------
# hyprlock.conf is static structure sourcing these $-variables, so the lock
# screen wears the active table. hyprlock reads its config each time it starts,
# so the next lock is already on the new table. Decimal rgba(), matching the
# format the shipped config used - dec() is up with the other colour helpers.

cat > "$config/hypr/lock-colours.conf" <<EOF
# AUTOGENERATED by cloon/newdot/house scripts/apply-theme.sh — do not edit by
# hand. The active table's palette, sourced from hyprlock.conf.

\$lockBackground = rgba($(dec "$surface"), 1.0)
\$lockOuter = rgba($(dec "$accent"), 0.55)
\$lockInner = rgba($(dec "$idle"), 0.75)
\$lockFont = rgba($(dec "$text"), 1.0)
\$lockCaps = rgba($(dec "$urgent"), 1.0)
\$lockClock = rgba($(dec "$accent"), 1.0)
\$lockSuits = rgba($(dec "$subtext"), 1.0)
\$lockPlaceholder = <span foreground="##$subtext">place your bets</span>
EOF

# --- Wallpaper ----------------------------------------------------------------
# One generated wallpaper per table, shipped in the repo. awww is the daemon the
# hypr config autostarts; fall back to swww for setups that use that instead.

wall="$repo/wallpapers/$name.png"
if [ -f "$wall" ]; then
    if command -v awww >/dev/null 2>&1; then
        awww img "$wall" >/dev/null 2>&1 || true
    elif command -v swww >/dev/null 2>&1; then
        swww img "$wall" >/dev/null 2>&1 || true
    fi
fi

# --- kitty --------------------------------------------------------------------
# The 16-colour deck can't be derived from six roles, so each table ships a
# pre-baked palette. kitty.conf includes current-table.conf; SIGUSR1 makes every
# running kitty re-read its config, so open terminals retint immediately.

if [ -f "$tables/kitty-$name.conf" ]; then
    cp "$tables/kitty-$name.conf" "$config/kitty/current-table.conf"
    pkill -USR1 -x kitty 2>/dev/null || true
fi

# --- rofi ---------------------------------------------------------------------
# house.rasi imports table-colours.rasi for its palette; everything rofi needs
# fits in the six roles, so generate it. rofi starts fresh per launch, so the
# next Super+D is already on the new table.

cat > "$config/rofi/themes/table-colours.rasi" <<EOF
/* AUTOGENERATED by cloon/newdot/house scripts/apply-theme.sh — do not edit.
 * The active table's palette, imported by house.rasi. */
* {
    surface:                 #${surface}E6;
    lacquer:                 #${idle};
    gold:                    #${accent};
    ivory:                   #${text};
    smoke:                   #${subtext};
    crimson:                 #${urgent};
    onaccent:                #${surface};
}
EOF

# --- btop ---------------------------------------------------------------------
# One pre-baked .theme per table (they ship in the btop stow package). Running
# btop instances pick it up on restart.

if [ -f "$config/btop/themes/house-$name.theme" ]; then
    sed -i "s/^color_theme = .*/color_theme = \"house-$name\"/" "$config/btop/btop.conf" 2>/dev/null || true
fi

# --- GTK ----------------------------------------------------------------------
# gtk-3.0/gtk.css and gtk-4.0/gtk.css are static structure referencing named
# colours; the palettes below are generated from the six roles. GTK apps read
# CSS once at startup, so open windows keep the old table until relaunched
# (thunar daemonises - `thunar -q` makes the next window pick it up).

# "Brighter" means further from the background, not closer to white. On a dark
# table those are the same thing, so this read as `mix text -> white` and nobody
# noticed; on the light table it pushed the text *toward* the page and
# button:checked ended up at 2.38:1, which is unreadable. Pick the pole the
# surface is furthest from and head for that instead.
[ "$light" = 1 ] && pole=000000 || pole=ffffff

window=$(mix "$surface" "$idle" 0.20)
raised=$(mix "$surface" "$idle" 0.40)
sunken=$(mix "$surface" "000000" 0.15)
hover=$(mix "$idle" "$text" 0.10)
active=$(mix "$idle" "$accent" 0.35)
bright=$(mix "$text" "$pole" 0.30)
borderdim=$(mix "$surface" "$idle" 0.50)
disabled=$(mix "$subtext" "$surface" 0.35)

roles="/* AUTOGENERATED by cloon/newdot/house scripts/apply-theme.sh — do not edit.
 * The active table's palette, imported by gtk.css. */

@define-color house_surface #$surface;
@define-color house_window #$window;
@define-color house_raised #$raised;
@define-color house_sunken #$sunken;
@define-color house_text #$text;
@define-color house_subtext #$subtext;
@define-color house_accent #$accent;
@define-color house_onaccent #$surface;
@define-color house_idle #$idle;
@define-color house_hover #$hover;
@define-color house_active #$active;
@define-color house_bright #$bright;
@define-color house_border_dim #$borderdim;
@define-color house_disabled #$disabled;
@define-color house_urgent #$urgent;"

printf '%s\n' "$roles" > "$config/gtk-3.0/table-colours.css"

cat > "$config/gtk-4.0/table-colours.css" <<EOF
$roles

/* libadwaita's own names, same values. */
@define-color window_bg_color #$window;
@define-color window_fg_color #$text;
@define-color view_bg_color #$surface;
@define-color view_fg_color #$text;
@define-color headerbar_bg_color #$surface;
@define-color headerbar_fg_color #$text;
@define-color headerbar_border_color #$idle;
@define-color headerbar_backdrop_color #$sunken;
@define-color card_bg_color #$raised;
@define-color card_fg_color #$text;
@define-color popover_bg_color #$raised;
@define-color popover_fg_color #$text;
@define-color dialog_bg_color #$window;
@define-color dialog_fg_color #$text;
@define-color sidebar_bg_color #$sunken;
@define-color sidebar_fg_color #$text;
@define-color sidebar_backdrop_color #$surface;
@define-color accent_bg_color #$accent;
@define-color accent_fg_color #$surface;
@define-color accent_color #$accent;
@define-color destructive_bg_color #$urgent;
@define-color destructive_fg_color #$text;
@define-color destructive_color #$urgent;
@define-color error_bg_color #$urgent;
@define-color error_fg_color #$text;
@define-color error_color #$urgent;
@define-color warning_bg_color #$accent;
@define-color warning_fg_color #$surface;
@define-color warning_color #$accent;
EOF

# --- folder icons -------------------------------------------------------------
# One House-<Table> icon theme per table (gold, brass, neon pink, old gold
# folders over stock Adwaita). GTK on Wayland takes the icon theme from
# gsettings, and running GTK apps re-resolve icons live when it changes.

icons="House-$(printf '%s' "$name" | awk '{ print toupper(substr($0,1,1)) substr($0,2) }')"
if [ -d "$HOME/.local/share/icons/$icons" ] && command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface icon-theme "$icons" 2>/dev/null || true
fi

# --- the games ----------------------------------------------------------------
# The five widgets in ../games are their own repo and their own quickshell
# processes, so they cannot import the house's Config. They read this file
# instead, and fall back to their own hardcoded block when it is absent - which
# is what happens when the games repo is cloned on its own, with no house at all.
#
# One JSON with every colour the five of them name between them (blackjack,
# poker and ride the bus share a set; bones adds tiles, roulette adds a wheel).
# The derivation lives here rather than in five theme blocks so there is one
# place to argue with.
#
# Two things do not come from the six roles and are pinned per table below:
#
#   green  is a verdict, not decoration - it is what says you won. Like a
#          terminal's green it keeps its hue on every table and only moves
#          enough to stay legible against that table's chrome.
#   felt   is the baize. Green by tradition, but each room has its own cloth,
#          and vegas is not a room that owns any green at all.
#
# On a light table almost every relationship inverts. Elevation goes darker
# rather than lighter (following the GTK roles above, which already do this),
# `gold` has to deepen rather than brighten or it vanishes into cream, and
# `inactive` recedes by going lighter. The card faces stay near-white and read
# against light chrome because PlayingCard outlines them with a 1px 35% black
# border, which is theme-independent and works either way round.

if [ "$light" = 1 ]; then
    g_bg=$surface
    g_surface=$(mix "$surface" "$idle" 0.55)
    g_raised=$(mix "$idle" "$subtext" 0.25)
    g_fg=$text
    g_muted=$(mix "$subtext" "$text" 0.35)
    # Inactive is meant to be faint, but not fainter here than everywhere else:
    # 0.30 toward the page put it at 2.2:1 where the dark tables sit at 3.2:1,
    # and a disabled control you cannot see at all is not disabled, it is gone.
    g_inactive=$(mix "$subtext" "$surface" 0.06)
    g_gold=$(mix "$accent" "$text" 0.35)
    g_red=$urgent
    g_cardface=$(mix "$surface" "ffffff" 0.75)
    g_cardink=$text
    g_cardback=$(mix "$accent" "$idle" 0.35)
    g_numblack=$(mix "$text" "000000" 0.25)
    g_wheelrim=$(mix "$accent" "$idle" 0.25)
    g_wheelhub=$(mix "$idle" "$subtext" 0.35)
    g_fret=$(mix "$accent" "$text" 0.20)
else
    g_bg=$surface
    g_surface=$(mix "$surface" "$idle" 0.45)
    g_raised=$idle
    g_fg=$text
    g_muted=$subtext
    g_inactive=$(mix "$subtext" "$surface" 0.25)
    # Warm white rather than plain white: a gold lifted straight toward #fff
    # goes chalky, and this is the colour on the winning figures.
    g_gold=$(mix "$accent" "fff0c0" 0.55)
    g_red=$(lift "$urgent" 32)
    g_cardface=$(mix "$text" "ffffff" 0.35)
    g_cardink=$surface
    g_cardback=$(mix "$idle" "$accent" 0.24)
    g_numblack=$(mix "$surface" "$idle" 0.20)
    g_wheelrim=$(mix "$idle" "$accent" 0.12)
    g_wheelhub=$(mix "$surface" "$idle" 0.60)
    g_fret=$(mix "$idle" "$accent" 0.38)
fi

# feltLine is the cloth's printing - "DEALER", "BLACKJACK PAYS 3 TO 2" - and
# also every hairline drawn on the cloth: the bet circle, the felt panel's own
# edge, the tile borders. It sat around 1.3:1 against the baize, which is what
# real printing on real cloth looks like and is also, at 9px with 2.4 of letter
# spacing, unreadable. Lifted to 2.4:1 - still ink soaked into cloth rather than
# UI text, but legible, and the outlines stop being invisible along with it.
#
# tileBack is deliberately NOT this value any more. It is a fill - the back of a
# domino - so carrying it up with the printing would repaint every tile in
# bones. It keeps the old, quieter step off the cloth.
case "$name" in
    noir)
        # Oxblood, not green: this room is black lacquer and deep crimson, and a
        # green cloth in it was the one thing still wearing another table's
        # colours. Pitched at the luminance the green had, so the cloth keeps
        # exactly the separation it always had from the chrome around it (1.30)
        # and from its own printing (1.43) - only the hue moves.
        #
        # Charcoal was the other candidate and lost: at this luminance it lands
        # on #2a2825, which is `raised` to within a hair, and the cloth stops
        # reading as a surface of its own.
        g_green=7fb069; g_felt=441720; g_feltline=934957; g_tileback=642e39; g_numgreen=12684a ;;
    felt)
        # The one table that owns the baize, which is the problem: the cloth was
        # a shade off the desktop green and the two blended into each other.
        # Deeper and more saturated - velvet rather than baize - so the widget
        # reads as sitting on the table instead of dissolving into it.
        # The printing is pinned to the house ratio (~1.32:1) rather than scaled
        # down with the cloth - taking the felt this dark drags it to 1.19:1 if
        # you let it follow, and the table stops saying what game it is.
        g_green=8fc47a; g_felt=04140c; g_feltline=255b40; g_tileback=123021; g_numgreen=157a56 ;;
    vegas)
        # No green in this room at all, so the cloth goes deep violet - the
        # marquee's own dark - and the win colour is the neon the tray uses.
        g_green=2de2e6; g_felt=141034; g_feltline=5045a9; g_tileback=2a1f5c; g_numgreen=1b8f7a ;;
    daylight)
        # A light cloth, and a green dark enough to read on it.
        g_green=15703a; g_felt=dcd7c2; g_feltline=958a5b; g_tileback=c3bda4; g_numgreen=0f6b4a ;;
esac

mkdir -p "$config/house"
cat > "$config/house/table.json" <<EOF
{
  "_comment": "AUTOGENERATED by the house's scripts/apply-theme.sh - do not edit. Rewritten on every table change; the games watch this file and retint live.",
  "table":    "$name",
  "light":    $([ "$light" = 1 ] && echo true || echo false),

  "bg":       "#$g_bg",
  "surface":  "#$g_surface",
  "raised":   "#$g_raised",
  "fg":       "#$g_fg",
  "muted":    "#$g_muted",
  "inactive": "#$g_inactive",
  "blue":     "#$accent",
  "red":      "#$g_red",
  "green":    "#$g_green",
  "gold":     "#$g_gold",

  "felt":     "#$g_felt",
  "feltLine": "#$g_feltline",

  "cardFace": "#$g_cardface",
  "cardInk":  "#$g_cardink",
  "cardRed":  "#$urgent",
  "cardBack": "#$g_cardback",

  "tileBack": "#$g_tileback",
  "tileFace": "#$g_felt",

  "numRed":   "#$(mix "$urgent" "$g_bg" 0.15)",
  "numBlack": "#$g_numblack",
  "numGreen": "#$g_numgreen",
  "wheelRim": "#$g_wheelrim",
  "wheelHub": "#$g_wheelhub",
  "fret":     "#$g_fret"
}
EOF

# --- starship -----------------------------------------------------------------
# Same story as kitty: segment palettes are pre-baked per table. starship
# re-reads its config every prompt, so the very next Enter is on the new table.

if [ -f "$tables/starship-$name.toml" ]; then
    cp "$tables/starship-$name.toml" "$config/starship.toml"
fi

# --- Hyprland, live -----------------------------------------------------------
# `keyword` alone updates the stored value but doesn't redraw borders already on
# screen until the window is refocused - so a theme switch wouldn't visibly land.
# A reload re-runs hyprland.lua (hence colors.lua, just written above) and
# repaints every border. It re-executes the config from scratch on a fresh Lua
# state, so the require() cache is not a problem here - the newly written
# colors.lua is what gets loaded. It does not re-fire hl.on("hyprland.start"),
# so the autostarts stay put and this is still cheap and safe.
if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
fi
