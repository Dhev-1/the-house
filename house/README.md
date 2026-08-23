# the house

A casino-themed [Quickshell](https://quickshell.org) config for Hyprland: a
border around the screen, a bar on the right, and a window dock on the left.
The house always wins — and it also draws your notifications, replacing dunst.

Pure QML — no C++ plugin, no build step. Clone it, point `qs` at it, done.

There is deliberately no dashboard, no OSD and no notification centre —
notifications are popups and nothing else. Once one leaves the screen it is
gone.

## Requirements

- `quickshell` (built against Qt 6.8+, for `PathRectangle`)
- Hyprland
- A Nerd Font (the status icons are Nerd Font glyphs — set `font` in `Config.qml`)
- Optional: `nm-connection-editor` and `blueman-manager`, opened by clicking the
  network and Bluetooth icons

## Run

```bash
qs -p ~/cloon/newdot/house
```

Autostart it from `hyprland.conf`:

```
exec-once = qs -p ~/cloon/newdot/house
```

> If `~/.config/quickshell/shell.qml` exists, Quickshell registers it as the
> `default` config and **ignores every subdirectory**, so named configs are
> unreachable. Move that file aside if you want `-c` to work.

## Layout

```
┌────────────────────────────────┬──┐
│ ┃                              │  │  border   — a full-screen surface with a
│ ┃                              │  │             rounded cutout; click-through
│ ┃          your windows        │  │  bar      — right edge, 44px
│ ┃                              │  │  dock tab — left edge, click to show/hide
│ ┃                              │  │
└────────────────────────────────┴──┘
```

Exclusion zones on all four sides keep tiled windows inside the border.

## The bar (right edge)

Top to bottom: workspaces, spacer, tray, status icons, clock.

- **Workspaces** — dealt as card suits: `♠ ♥ ♦ ♣ ★`. Click to switch, scroll to
  cycle. The active suit lights up in the table's accent and grows.
- **Tray** — left-click activates, right-click opens the app's menu. Items
  listed in `trayHiddenIds` are not drawn (`nm-applet` by default, since the
  status icons already show the network).
- **Status icons** — network (click → `nm-connection-editor`), Bluetooth
  (click → `blueman-manager`), battery. The battery hides itself when there
  isn't one.
- **Clock** — hours over minutes.

## Notifications

The shell owns `org.freedesktop.Notifications`, so **no other notification daemon
can be running**. That name is exclusive: whoever claims it first wins, and the
loser silently never sees a notification. Dunst also ships a D-Bus activation
file, so it can be started on demand by anything that sends a notification —
uninstalling it is the only way to be sure it stays gone.

Toasts stack down from the top right, inside the border and clear of the bar,
styled per table — candle-lit gold cards on Noir.

| Action | Mouse |
| --- | --- |
| Close this one | left-click |
| Run its default action, then close | middle-click |
| Close all of them | right-click, or `Super+Shift+N` |

- **Urgency** decides the colours. Critical notifications never expire and sort
  to the top of the stack; everything else expires after 10s unless the app asks
  for something different.
- **Hovering pauses the timer**, so a toast can't vanish mid-read.
- **Actions** are drawn as buttons.
- **A progress hint** (`notify-send -h int:value:50`) draws the bar.
- **Duplicates** collapse into one card with a count.

## The dock (left edge)

The tab on the left edge shows one icon per docked window.

| Action | Keybind | Also |
| --- | --- | --- |
| Dock focused window | `Super+Shift+D` | |
| Undock focused window | `Super+Shift+U` | middle-click its icon |
| Show / hide the dock | `Super+Alt+D` | click the tab |
| Cycle docked windows | `Super+Tab` | click an icon to jump to it |

**The dock does not persist.** If the shell restarts while windows are hidden,
they stay parked on the `sidebar` workspace and the tab forgets them. Get them
back with `hyprctl dispatch workspace name:sidebar`.

## The music tab (right edge)

The dock tab's mirror image, on the other side: a tab on the right edge tucked
against the bar. Click it and the player controls slide out to the left — album
art, track, artist, position, and previous / play-pause / next.

It only exists while Spotify is running. Point `musicPlayer` in `Config.qml` at
something else to control something else — it is matched against the MPRIS bus
name and identity, case-insensitively.

## The tables (theme picker)

The `♠` glyph near the foot of the bar — or the `theme` keybind — opens a
centred overlay of table tiles, each painted in its own colours as a live
preview. Move the highlight and the whole shell re-tints in real time; commit or
cancel to keep or drop it.

Four tables ship:

| Table | The room |
| --- | --- |
| **Noir** *(default)* | The high-roller room. Black lacquer, champagne gold, deep crimson. |
| **Felt** | The poker table. Green baize, brass rail, ivory chips. |
| **Vegas** | The strip at midnight. Neon pink marquee, cyan bulbs, gold glow. |
| **Daylight Robbery** | The one light table. Cream carpet, old gold, card red. |

| Action | Keybind | Also |
| --- | --- | --- |
| Open / close the picker | `Super+T` | click the `♠` button in the bar |
| Preview a table | `↑ ↓ ← →` / `hjkl` / `1`–`9` | hover a tile |
| Keep the highlighted table | `Enter` / `Space` | click a tile |
| Cancel, revert to current | `Esc` | click outside the card |

The choice is written to `theme.json` in Quickshell's state dir, so it survives a
restart, and `scripts/apply-theme.sh` mirrors it onto everything that is not the
shell: Hyprland's borders and hyprlock, the wallpaper, kitty, rofi, btop,
starship, GTK 3/4, Qt (qt6ct's palette and the Kvantum style), the folder icons
and the games' `table.json`.
Add a table by dropping another entry in the `themes` array in `Config.qml` —
each entry fills six roles (`surface`, `text`, `subtext`, `accent`, `idle`,
`urgent`); notification palettes, the progress gradient and the tray dots are
derived from those unless the theme pins its own (Noir and Vegas do).

## The deal (launcher)

`Super+D` deals a hand of apps: a bet line, and five cards pitched out of the
shoe one at a time, left to right. Type and the hand re-deals; the highlighted
card squares up out of the fan and lifts.

With nothing typed the hand is the house regulars — the five apps you have
launched most from here — so it opens on what you actually run rather than on
whatever sorts first.

| Action | Keybind | Also |
| --- | --- | --- |
| Open / close | `Super+D` | click outside to fold |
| Place a bet | type | — |
| Walk the hand | `← →` / `Tab` | hover a card |
| Turn to the next / previous hand | `↓ ↑` / `PgDn PgUp` | walk off either end with `← →` |
| First / last hand | `Home` / `End` | — |
| Deal the highlighted app in | `Enter` | click a card |
| Fold | `Esc` | — |

The hand is a page into the matches, not the first five of them. Walk off the
right-hand end and the table is swept and the next five are pitched in from the
right; off the end of the shoe it comes back round to the top, so holding an
arrow down walks every match and wraps. The bet line reads `hand 2/7` while
there is more than one, and says nothing when the hand is the whole answer.

`← →` walk the hand rather than the caret — the bet is two or three characters
and the cards are what the arrows are obviously for. Backspace still edits.

Matching is a coarse ladder (exact name, prefix, word start, substring, then
generic name, binary, keywords, comment), ties broken by how often you have
played that app. Deliberately not fuzzy: with five seats on the table, loose
matching mostly costs you the card you meant to be looking at.

Play counts live in `plays.json` in Quickshell's state dir, next to `theme.json`.
Delete it to forget the regulars. `launcherSeats` and the card geometry are in
`Config.qml`.

Set `launcherIcons: false` in `Config.qml` and the cards drop the apps' icons
and wear their suit pips instead — the hand reads as a deck rather than as a
menu. With it on, the pip is still what an app gets when its `.desktop` has no
`Icon=` (Xwayland, zenity) or names one the icon theme does not carry.

rofi is still installed and still themed per table (`home/rofi`) — its `run`,
`filebrowser` and `window` modes are things the hand does not do. The old bind
sits commented under the new one in `binds.conf`.

## Configuring

Everything is in `Config.qml` — sizes, the table palettes, how many workspaces
to draw, dock width, hidden tray ids.

`settings.watchFiles` is on, so edits hot-reload. Only `//@ pragma` lines need a
restart.

## Files

```
shell.qml            root; pragmas, IPC handlers, one set of windows per screen
Config.qml           all the knobs, and the four tables
Border.qml           the frame (QtQuick.Shapes, click-through)
Bar.qml              the right-edge bar
Sidebar.qml          the left-edge dock tab
Music.qml            the right-edge music tab (only while the player runs)
Popups.qml           the notification stack (top right)
ThemePicker.qml      the table picker overlay (Super+T or the bar's ♠ button)
Launcher.qml         the launcher: a hand of apps, dealt (Super+D)
Exclusions.qml       reserves the other three edges
components/          Workspaces, Tray, StatusIcons, Clock, ThemeButton, Toast
services/Dock.qml    docking logic
services/Notifications.qml  the notification server (replaces dunst)
services/Player.qml  the MPRIS player the music tab drives
services/ThemePanel.qml     open-state for the table picker overlay
services/LauncherPanel.qml  open-state for the launcher overlay
services/Apps.qml           the shoe: desktop entries, matching, play counts
scripts/apply-theme.sh      mirrors the active table onto the rest of the desktop
scripts/tables/             what six roles can't express: kitty's 16-colour deck,
                            starship's segments, and Kvantum's chassis
```

## Notes

- `shell.qml` sets `QT_QPA_PLATFORMTHEME=xdgdesktopportal` so native tray menus
  follow the portal's colour scheme. Without it Qt ignores it and paints them
  light. Everything else Qt goes to qt6ct instead (`hyprland.conf` sets that
  globally); the shell's pragma only rebinds it for the shell's own process.
- Qt is themed in two layers. qt6ct holds the palette, which every Qt app obeys
  whatever draws it — that layer works with nothing else installed. Kvantum is
  the style, and it draws the widgets properly rather than colouring Fusion's;
  `apply-theme.sh` writes a theme for it and points qt6ct at it when the plugin
  is present, and falls back to Fusion plus the palette when it is not.
- `//@ pragma UseQApplication` is required for tray menus to open at all.
- Electron apps (Discord) register their tray icon once, against whatever
  StatusNotifierWatcher exists when they launch. If you restart the shell and an
  icon is missing, restart that app.
