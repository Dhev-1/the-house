pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    readonly property int barWidth: 44
    readonly property int bottomBarWidth: 22 // the bottom leg of the L, half the bar
    readonly property int borderThickness: 10
    readonly property int borderRounding: 24

    // Workspaces 1..shown are always drawn, empty or not
    readonly property int workspacesShown: 10

    // Tray items whose id matches any of these are not drawn. nm-applet is
    // hidden because the status icons already show the network; it stays
    // running as NetworkManager's secret agent for wifi password prompts.
    readonly property var trayHiddenIds: ["nm-applet"]

    // Sidebar dock (opposite the bar). Docked windows are floating + pinned;
    // this is the holding workspace they are parked on while hidden.
    readonly property string sidebarWorkspace: "sidebar"
    readonly property int sidebarWidth: 420   // width docked windows are resized to
    readonly property int sidebarTabWidth: 20 // the clickable tab on the left edge
    readonly property int sidebarIconSize: 18

    // Music tab (right edge, against the bar). Only exists while this player is
    // running. Matched case-insensitively against the MPRIS bus name and
    // identity, so "spotify" catches org.mpris.MediaPlayer2.spotify too.
    readonly property string musicPlayer: "spotify"

    // The tab carrying the transport controls. Its top and bottom edges curve
    // away over musicTabFlare pixels so it grows out of the bar rather than
    // being stuck onto it; the flare is part of the height, so it can't exceed
    // half of it.
    readonly property int musicTabWidth: 32
    readonly property int musicTabHeight: 280
    readonly property int musicTabFlare: 40

    // The panel it slides out. As tall as the tab so the two make one rectangle,
    // rounded only on the far side.
    readonly property int musicWidth: 380
    readonly property int musicRounding: 12
    readonly property int musicPadding: 14
    readonly property int musicArtSize: 110

    // Notification toasts, ported from the dunstrc this shell replaced - the
    // geometry and timings below are dunst's. Popups only, no history.

    readonly property int notifWidth: 300
    readonly property int notifOffsetX: 20     // from the bar, not the screen
    readonly property int notifOffsetY: 40     // edge - see Popups.
    readonly property int notifPadding: 10     // padding, horizontal_padding
    readonly property int notifIconSize: 44    // min_icon_size (bumped from dunst's 32)

    // Not dunst's: it drew the stack as one flat slab. Separate rounded cards
    // with a thin frame instead.
    readonly property int notifRadius: 10
    readonly property int notifFrameWidth: 1
    readonly property int notifSpacing: 8
    readonly property int notifProgressHeight: 10 // progress_bar_height
    readonly property int notifProgressFrame: 1   // progress_bar_frame_width

    // show_age_threshold: seconds before a notification starts showing its age.
    readonly property int notifAgeThreshold: 60

    // notification_limit = 0 in dunst, meaning no limit. 0 keeps that.
    readonly property int notifMaxVisible: 0

    // timeout, in seconds. Critical has no entry because dunst set it to 0:
    // critical notifications never expire. Only used when the app doesn't ask
    // for a timeout of its own.
    readonly property int notifTimeoutLow: 10
    readonly property int notifTimeoutNormal: 10

    // dunst defaulted word_wrap off. Not copied: without wrapping, overflow is
    // cut mid-word rather than ellipsized.
    readonly property bool notifWordWrap: true
    readonly property int notifBodyLines: 6

    // The dunstrc asked for "Mononoki Nerd Font Mono 11.5", which isn't
    // installed - it had been quietly falling back. Install ttf-mononoki-nerd
    // and swap this over for the real thing.
    readonly property string notifFont: font
    readonly property real notifFontSize: 11.5

    // The progress bar fill (highlight): a gradient climbing from a deep tint to a
    // bright one. Pinned by Noir/Vegas, derived from the theme's accent elsewhere.
    readonly property QtObject notifProgress: QtObject {
        readonly property color low: activeProgress.low
        readonly property color mid: activeProgress.mid
        readonly property color high: activeProgress.high
    }

    // One palette per urgency. Held as stable QtObjects because a toast compares
    // the reference by identity to pick its expiry behaviour, so the object has
    // to stay put while its colours track the theme underneath.
    readonly property QtObject notifLow: QtObject {
        readonly property color background: activeNotif.low.background
        readonly property color frame: activeNotif.low.frame
        readonly property color title: activeNotif.low.title
        readonly property color body: activeNotif.low.body
        readonly property color accent: activeNotif.low.accent
    }

    readonly property QtObject notifNormal: QtObject {
        readonly property color background: activeNotif.normal.background
        readonly property color frame: activeNotif.normal.frame
        readonly property color title: activeNotif.normal.title
        readonly property color body: activeNotif.normal.body
        readonly property color accent: activeNotif.normal.accent
    }

    readonly property QtObject notifCritical: QtObject {
        readonly property color background: activeNotif.critical.background
        readonly property color frame: activeNotif.critical.frame
        readonly property color title: activeNotif.critical.title
        readonly property color body: activeNotif.critical.body
        readonly property color accent: activeNotif.critical.accent
    }

    // The clock popout: left-click on the clock shows time + date, right-click
    // shows a month calendar. ClockPopout.qml.
    readonly property int clockPanelWidth: 250
    readonly property int clockPanelRadius: 12
    readonly property int clockPanelPadding: 16

    // The theme picker: one tile per entry in `themes`. Arrow or hover previews
    // live, enter keeps, escape reverts. ThemePicker.qml.
    readonly property int themePanelWidth: 360
    readonly property int themePanelRadius: 16
    readonly property int themePanelPadding: 16

    // The launcher's hand - Launcher.qml, off the Apps service. Five seats, a
    // poker hand; anything past the fifth is reported as a count still in the
    // shoe rather than scrolled.
    readonly property int launcherSeats: 5
    readonly property int launcherCardWidth: 120
    readonly property int launcherCardHeight: 170
    readonly property int launcherCardGap: 16
    readonly property int launcherIconSize: 44

    // Whether the cards wear the apps' own icons; off, every card shows its suit
    // pip instead. The pip is also the fallback while this is on - an app whose
    // .desktop has no Icon= (Xwayland, zenity) or names one the icon theme
    // lacks gets it rather than Qt's magenta checkerboard.
    readonly property bool launcherIcons: true

    // The fan: degrees of tilt per seat off-centre, and how far a card travels
    // from the dealer's hand on its way to the table.
    readonly property real launcherFan: 4
    readonly property int launcherPitch: 260

    // How long one card takes to cross the table, and how far behind the card
    // before it. Kept short: the whole animation runs again on every keystroke.
    // DealFade is how much of the flight the card spends fading up - 1 the whole
    // way, 0 fully opaque the moment it leaves the shoe.
    readonly property int launcherDealDuration: 190
    readonly property int launcherDealStagger: 38
    readonly property real launcherDealFade: 0.45

    // The bet line above the hand.
    readonly property int launcherBetHeight: 48
    readonly property int launcherBetRadius: 12

    // The tray: your own five, tucked into the bottom-left edge of the launcher.
    // Full card size - place and posture keep it apart from the hand, not scale.
    // Everything inside a tray card derives off this, so 0.55 gives the small
    // tucked version back.
    readonly property real launcherTrayScale: 1
    readonly property int launcherTrayGap: 10
    readonly property int launcherTrayMargin: 28

    // How much of a card stands above the screen edge at rest - enough to clear
    // the corner index and the icon, leaving the name below the fold. Raise it
    // with the scale: at full size the icon alone is 44 tall and starts 22 down.
    readonly property int launcherTrayPeek: 76

    // Nudge is the small rise when the pointer nears the edge or a card is
    // dragged toward it; lift is the clearance when the whole tray comes up
    // (alt held) or one card is hovered.
    readonly property int launcherTrayNudge: 15
    readonly property int launcherTrayLift: 14

    // How close to the bottom edge the pointer has to be for the nudge.
    readonly property int launcherTrayProximity: 140

    // The service tray: a handle under the top edge dropping a column of icon
    // buttons, each starting/stopping a systemd --user unit. The units are
    // machine-local, not stowed; on a box without one the button reads stopped.
    // ButtonTray is generic, ServiceTray wires it to the units below.
    readonly property int trayWidth: 50        // breadth of the strip
    readonly property int trayTabHeight: 24    // the always-visible handle
    readonly property int trayInset: 12        // gap from the bar
    readonly property int trayButtonSize: 38
    readonly property int trayButtonSpacing: 8
    readonly property int trayPadding: 6
    readonly property int trayRounding: 14

    // The service-tray dots: running vs stopped. Noir/Vegas pin their own;
    // other themes light "running" with their accent and "stopped" with urgent.
    readonly property color trayOn: colours.trayOn ?? colours.accent
    readonly property color trayOff: colours.trayOff ?? colours.urgent

    // One entry per button: the unit it toggles, and its running/stopped glyphs.
    // Units that do not exist on this machine are dropped rather than drawn
    // dead, so this list is yours to edit - voice-bridge is a personal one.
    readonly property var trayServices: [
        {
            unit: "voice-bridge.service",
            iconOn: "󰢴",
            iconOff: "󰢳"
        }
    ]

    // The pit: the games on the bottom bar. Each entry is the wrapper qml
    // `qs -p` launches, the game's IPC target, and its glyph. Pit.qml lights a
    // button while that game's process is up, and only draws games it can find -
    // a checkout without the `games` submodule gets a bare bottom bar.
    //
    // shellPath(), not Qt.resolvedUrl(): singletons are compiled into
    // quickshell's qrc, so a relative url from in here resolves against
    // qrc:/qs-blackhole and never touches the disk. Two candidates because
    // shellPath is only the clone when the house is *run* from it; copied into
    // ~/.config/quickshell it points at a games dir that does not exist.
    readonly property var pitRepos: [Quickshell.shellPath("../games"), `${Quickshell.env("HOME")}/cloon/newdot/games`]
    readonly property var pitGames: [
        {
            dir: "bjak",
            file: "blackjack.qml",
            target: "blackjack",
            icon: "󰇊" // nf-md-dice, face 1
        },
        {
            dir: "pokr",
            file: "poker.qml",
            target: "poker",
            icon: "󰇋" // nf-md-dice, face 2
        },
        {
            dir: "rolt",
            file: "roulette.qml",
            target: "roulette",
            icon: "󰇌" // nf-md-dice, face 3
        },
        {
            dir: "bons",
            file: "bns.qml",
            target: "bones",
            icon: "󰇍" // nf-md-dice, face 4
        },
        {
            dir: "busride",
            file: "ridethebus.qml",
            target: "ridethebus",
            icon: "󰇎" // nf-md-dice, face 5
        }
    ]

    readonly property string font: "JetBrainsMono Nerd Font"

    // --- Theming -------------------------------------------------------------
    //
    // Every widget reads its colours through Config.colours, so switching theme
    // re-tints the shell live. Each theme fills the same six roles:
    //
    //   surface  the bar/card background
    //   text     primary foreground
    //   subtext  dimmed foreground - inactive icons, secondary lines
    //   accent   the highlight - active workspace, hovers, today's date
    //   idle     hover/fill wash, hairline borders
    //   urgent   errors, critical battery, the urgent status colour
    //
    // Notification cards and tray dots need more colours than those six, so they
    // are derived from them - see deriveNotif / deriveProgress. Noir and Vegas
    // pin some of their own; Felt and Daylight derive everything.
    //
    // The picker writes the chosen name to theme.json below, so it survives a
    // restart. To add a theme, drop another entry in here.
    readonly property var themes: [
        {
            name: "noir",
            label: "Noir",
            // The high-roller room: black lacquer, champagne gold, deep crimson.
            surface: "#0e0b0d",
            text: "#e8ddc4",
            subtext: "#8a7f6d",
            accent: "#d4af5f",
            idle: "#2a2320",
            urgent: "#c13a4e",

            // Pinned so the default table is exact; the others derive.
            notif: {
                low: {
                    background: "#1a1512",
                    frame: "#3a301f",
                    title: "#b0a184",
                    body: "#8a7f6d",
                    accent: "#9a7d45"
                },
                normal: {
                    background: "#1e1813",
                    frame: "#55432a",
                    title: "#e8ddc4",
                    body: "#a89878",
                    accent: "#d4af5f"
                },
                critical: {
                    background: "#26121a",
                    frame: "#7a2a3a",
                    title: "#f0a9b4",
                    body: "#c9aeae",
                    accent: "#c13a4e"
                }
            },
            progress: {
                low: "#55432a",
                mid: "#d4af5f",
                high: "#f0e0b8"
            },
            trayOn: "#d4af5f",
            trayOff: "#c13a4e"
        },
        {
            name: "felt",
            label: "Felt",
            // The poker table: green baize, brass rail, ivory chips, card red.
            surface: "#0e2b1c",
            text: "#eae3cd",
            subtext: "#7fa08c",
            accent: "#c9a227",
            idle: "#1d4030",
            urgent: "#c0392f",

            // Pinned: deriveNotif blends in straight RGB, and on a saturated
            // green every mix toward accent or urgent lands in olive - a
            // derived *critical* card came out khaki (#2e2e1f).
            notif: {
                low: {
                    background: "#143224",
                    frame: "#2e4636",
                    title: "#b5b39a",
                    body: "#7fa08c",
                    accent: "#8a7a45"
                },
                normal: {
                    background: "#17392a",
                    frame: "#7a6524",
                    title: "#eae3cd",
                    body: "#b5b79c",
                    accent: "#c9a227"
                },
                critical: {
                    background: "#2d1518",
                    frame: "#8a3330",
                    title: "#f0b0a4",
                    body: "#d6b8ae",
                    accent: "#c0392f"
                }
            },
            // Brass, flanked by a dark step and an ivory one. Derived, the low
            // step was olive again (#756c22).
            progress: {
                low: "#5f5220",
                mid: "#c9a227",
                high: "#e4d296"
            }
        },
        {
            name: "vegas",
            label: "Vegas",
            // The strip at midnight: neon pink marquee on black, cyan tray
            // bulbs, a pink-to-gold progress glow.
            surface: "#0a0a14",
            text: "#eaeaf2",
            subtext: "#6b6f92",
            accent: "#ff2e88",
            idle: "#1c1c30",
            urgent: "#ff6247",
            progress: {
                low: "#7a1c48",
                mid: "#ff2e88",
                high: "#ffd166"
            },
            trayOn: "#2de2e6",
            trayOff: "#ff6247"
        },
        {
            name: "daylight",
            label: "Daylight Robbery",
            // The one light table: cream carpet, old gold, the same card red.
            surface: "#f5efe2",
            text: "#46392c",
            subtext: "#8c7f6a",
            accent: "#9c7a1e",
            idle: "#e6dcc6",
            urgent: "#b3372f",

            // Pinned: deriveNotif is written for a dark table and this is the
            // only light one - "surface lifted toward idle" comes out *darker*
            // than cream and subtext bodies land at 3.1:1, under the 4.5 needed.
            notif: {
                low: {
                    background: "#faf5ea",
                    frame: "#d8cdb8",
                    title: "#5a4c3c",
                    body: "#6f6252",
                    accent: "#8a7440"
                },
                normal: {
                    background: "#fdfaf2",
                    frame: "#b8933a",
                    title: "#46392c",
                    body: "#665847",
                    accent: "#9c7a1e"
                },
                critical: {
                    background: "#f9e6e0",
                    frame: "#b3372f",
                    title: "#8a2b22",
                    body: "#6d4a42",
                    accent: "#a33028"
                }
            },
            // low/mid/high are gradient stops, not thresholds: the ramp gains
            // presence left to right, which on cream means deeper, not
            // brighter. Derived, it topped out at 4.66:1 against the card.
            progress: {
                low: "#c9ad64",
                mid: "#9c7a1e",
                high: "#6b5214"
            }
        }
    ]

    // themeName is the persisted choice, changed only through setTheme() so the
    // write to disk follows; previewName is the picker's transient override,
    // resolved first. An unknown name falls back to the first entry.
    readonly property string themeName: prefs.theme
    property string previewName: ""
    readonly property string activeName: previewName !== "" ? previewName : themeName
    readonly property var colours: themes.find(t => t.name === activeName) ?? themes[0]

    // The theme's own pinned block if it has one, otherwise derived from its six
    // roles so the cards and dots follow whatever theme is on.
    readonly property var activeNotif: colours.notif ?? deriveNotif(colours)
    readonly property var activeProgress: colours.progress ?? deriveProgress(colours)

    // Linear blend of two "#rrggbb" strings, t from a (0) to b (1).
    function _mix(a: string, b: string, t: real): color {
        const x = _hex(a);
        const y = _hex(b);
        return Qt.rgba((x.r + (y.r - x.r) * t) / 255, (x.g + (y.g - x.g) * t) / 255, (x.b + (y.b - x.b) * t) / 255, 1);
    }

    function _hex(h: string): var {
        const s = h.charAt(0) === "#" ? h.substring(1) : h;
        return {
            r: parseInt(s.substring(0, 2), 16),
            g: parseInt(s.substring(2, 4), 16),
            b: parseInt(s.substring(4, 6), 16)
        };
    }

    // The three urgency palettes off the six roles: cards are surface lifted
    // toward idle, frames carry the accent, critical carries urgent.
    function deriveNotif(c: var): var {
        return {
            low: {
                background: _mix(c.surface, c.idle, 0.45),
                frame: _mix(c.surface, c.subtext, 0.30),
                title: _mix(c.subtext, c.text, 0.45),
                body: c.subtext,
                accent: _mix(c.subtext, c.accent, 0.50)
            },
            normal: {
                background: _mix(c.surface, c.idle, 0.65),
                frame: _mix(c.idle, c.accent, 0.45),
                title: c.text,
                body: c.subtext,
                accent: c.accent
            },
            critical: {
                background: _mix(c.surface, c.urgent, 0.18),
                frame: _mix(c.surface, c.urgent, 0.55),
                title: _mix(c.text, c.urgent, 0.35),
                body: _mix(c.subtext, c.text, 0.40),
                accent: c.urgent
            }
        };
    }

    // The progress fill: accent, flanked by a darker step toward surface and a
    // lighter one toward text.
    function deriveProgress(c: var): var {
        return {
            low: _mix(c.surface, c.accent, 0.55),
            mid: c.accent,
            high: _mix(c.accent, c.text, 0.40)
        };
    }

    // Flick to a theme without committing, as the picker's selection moves.
    // "" clears back to the saved one.
    function preview(name: string): void {
        if (name === "" || themes.some(t => t.name === name))
            previewName = name;
    }

    // Drop the preview, snapping back to the saved theme - the picker's cancel path.
    function clearPreview(): void {
        previewName = "";
    }

    // Commit a theme: persist it, drop the preview, and mirror it out to the
    // rest of the system.
    function setTheme(name: string): void {
        if (!themes.some(t => t.name === name))
            return;
        previewName = "";
        prefs.theme = name;
        prefsFile.writeAdapter();
        applyToSystem(name);
    }

    // Push a theme out past the shell: scripts/apply-theme.sh writes
    // ~/.config/hypr/colors.conf and retints Hyprland's borders live. Only
    // commits call here, so arrow-keying the picker doesn't spawn a script per
    // keystroke.
    function applyToSystem(name: string): void {
        const c = themes.find(t => t.name === name);
        if (!c)
            return;
        // execDetached wants a plain path, so drop the url's file:// prefix.
        const script = Qt.resolvedUrl("scripts/apply-theme.sh").toString().replace("file://", "");
        Quickshell.execDetached(["sh", script, c.name, c.surface, c.text, c.subtext, c.accent, c.idle, c.urgent]);
    }

    // Sync Hyprland once at startup, so the compositor matches theme.json even
    // if colors.conf was never written or was edited while the shell was down.
    Component.onCompleted: applyToSystem(themeName)

    // Persisted in Quickshell's per-shell state dir. watchChanges means an
    // external edit re-themes live too. The file is absent on first run, hence
    // printErrors: false.
    FileView {
        id: prefsFile

        path: Quickshell.statePath("theme.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: prefs

            property string theme: "noir"
        }
    }
}
