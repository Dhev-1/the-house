# the house

A casino-themed [Quickshell](https://quickshell.org) config for Hyprland: a
border around the screen, a bar on the right, and a window dock on the left.
The house always wins — and it also draws your notifications, replacing dunst.

Pure QML — no C++ plugin, no build step. Clone it, point `qs` at it, done.

There is deliberately no launcher, dashboard, power menu or OSD, and no
notification centre — notifications are popups and nothing else. Once one leaves
the screen it is gone.

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
restart, and `scripts/apply-theme.sh` mirrors it onto Hyprland's window borders.
Add a table by dropping another entry in the `themes` array in `Config.qml` —
each entry fills six roles (`surface`, `text`, `subtext`, `accent`, `idle`,
`urgent`); notification palettes, the progress gradient and the tray dots are
derived from those unless the theme pins its own (Noir and Vegas do).

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
Exclusions.qml       reserves the other three edges
components/          Workspaces, Tray, StatusIcons, Clock, ThemeButton, Toast
services/Dock.qml    docking logic
services/Notifications.qml  the notification server (replaces dunst)
services/Player.qml  the MPRIS player the music tab drives
services/ThemePanel.qml     open-state for the table picker overlay
scripts/apply-theme.sh      mirrors the active table onto Hyprland
```

## Notes

- `shell.qml` sets `QT_QPA_PLATFORMTHEME=xdgdesktopportal` so native tray menus
  follow the portal's colour scheme. Without it Qt ignores it and paints them
  light.
- `//@ pragma UseQApplication` is required for tray menus to open at all.
- Electron apps (Discord) register their tray icon once, against whatever
  StatusNotifierWatcher exists when they launch. If you restart the shell and an
  icon is missing, restart that app.
