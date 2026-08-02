pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    readonly property int barWidth: 44
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

    // Music tab (right edge, tucked against the bar). The tab only exists while
    // the player below is running; clicking it slides the controls out.
    //
    // Matched against the MPRIS bus name and identity, case-insensitively, so
    // "spotify" catches both org.mpris.MediaPlayer2.spotify and "Spotify".
    readonly property string musicPlayer: "spotify"

    // The tab: a tall strip carrying the transport controls, so previous, pause
    // and next are one click away without opening anything. It doesn't meet the
    // bar at a corner - its top and bottom edges curve away over musicTabFlare
    // pixels, so it grows out of the bar instead of being stuck onto it. The
    // flare is part of the height, so it can't exceed half of it.
    readonly property int musicTabWidth: 32
    readonly property int musicTabHeight: 280
    readonly property int musicTabFlare: 40

    // The panel it slides out: album art, the track, and how far through it is.
    // It is as tall as the tab, so the two make one rectangle, and only rounded on
    // the far side - the edge where they meet is not an outside edge.
    readonly property int musicWidth: 380
    readonly property int musicRounding: 12
    readonly property int musicPadding: 14
    readonly property int musicArtSize: 110

    // Notification toasts. These are a port of the dunstrc this shell replaced,
    // so the geometry, palette and timings below are dunst's rather than the
    // bar's: square corners, a 3px frame, and the teal urgency palette.
    //
    // Popups only. There is no history, so a dismissed notification is gone.

    readonly property int notifWidth: 300      // width
    readonly property int notifOffsetX: 20     // offset, x. From the bar, not the
    readonly property int notifOffsetY: 40     // offset, y. screen edge - see Popups.
    readonly property int notifPadding: 10     // padding, horizontal_padding
    readonly property int notifIconSize: 44    // min_icon_size (bumped from dunst's 32)

    // Not dunst's: it drew the stack as one flat slab (corner_radius = 0,
    // gap_size = 0, a 3px frame around the lot). Separate rounded cards with a
    // thin, dimmed frame instead.
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

    // word_wrap was never set in the dunstrc, so it took dunst's default of off.
    // Not copied: markup means the body is rich text, and Qt ignores elide on rich
    // text, so not wrapping doesn't ellipsize the overflow - it just cuts it off
    // mid-word. Wrapping instead, up to notifBodyLines.
    readonly property bool notifWordWrap: true
    readonly property int notifBodyLines: 6

    // The dunstrc asked for "Mononoki Nerd Font Mono 11.5", which isn't installed
    // - dunst had been quietly falling back for who knows how long. Install
    // ttf-mononoki-nerd and swap this over if you want the real thing.
    readonly property string notifFont: font
    readonly property real notifFontSize: 11.5

    // The progress bar fill (highlight): a gradient climbing from a deep tint to a
    // bright one. Pinned by Noir/Vegas, derived from the theme's accent elsewhere.
    readonly property QtObject notifProgress: QtObject {
        readonly property color low: activeProgress.low
        readonly property color mid: activeProgress.mid
        readonly property color high: activeProgress.high
    }

    // One palette per urgency: background, frame, title, body, accent. Held as
    // stable QtObjects because Notifications.palette() hands the reference to a
    // toast, which compares it by identity to pick expiry behaviour - the object
    // stays put while its colours track the active theme underneath. Noir pins
    // its own candle-lit golds; derived (deriveNotif) otherwise.
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

    // The theme picker: a centred overlay of theme tiles, one per entry in
    // `themes`, opened by the palette button in the bar or the `theme` keybind.
    // Arrow / hover to preview a theme live, enter or click to keep it, escape to
    // revert. ThemePicker.qml.
    readonly property int themePanelWidth: 360
    readonly property int themePanelRadius: 16
    readonly property int themePanelPadding: 16

    // The service tray: a handle under the top edge, near the top-right corner,
    // that drops a little column of icon buttons down beneath it. Each button
    // starts, stops and reflects a systemd --user unit - the hermes-gateway and
    // voice-bridge toggles carried over from the waybar config this replaced.
    //
    // The widget (ButtonTray) is generic: it only shows icons and reports clicks.
    // ServiceTray wires those to the units below, and the Systemd service does
    // the polling and toggling.
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

    // Each entry is one button: the unit it toggles and the glyphs for its running
    // and stopped states. Hermes shows the same one either way, voice-bridge swaps.
    readonly property var trayServices: [
        {
            unit: "hermes-gateway.service",
            iconOn: "⚕",
            iconOff: "⚕"
        },
        {
            unit: "voice-bridge.service",
            iconOn: "󰢴",
            iconOff: "󰢳"
        }
    ]

    readonly property string font: "JetBrainsMono Nerd Font"

    // Table sounds: a card flick when a table is committed. One switch to mute.
    readonly property bool sounds: true

    function playSound(name: string): void {
        if (!sounds)
            return;
        const wav = Qt.resolvedUrl("sounds/" + name).toString().replace("file://", "");
        Quickshell.execDetached(["paplay", wav]);
    }

    // --- Theming -------------------------------------------------------------
    //
    // Every widget reads its colours through Config.colours, so swapping the
    // active theme re-tints the whole shell live - the ColorAnimation Behaviors
    // dotted around the widgets animate the crossfade for free.
    //
    // Each theme fills the same six roles:
    //   surface  the bar/card background
    //   text     primary foreground
    //   subtext  dimmed foreground - inactive icons, secondary lines
    //   accent   the highlight - active workspace, hovers, today's date
    //   idle     hover/fill wash, hairline borders
    //   urgent   errors, critical battery, the urgent status colour
    //
    // The notification cards and the service-tray dots follow the theme too, but
    // through more colours than the six above (a background/frame/title/body/accent
    // per urgency, a progress gradient, a running/stopped pair). Rather than spell
    // all of those out per theme, they are derived from the six roles - see
    // deriveNotif / deriveProgress below. Noir and Vegas pin some of
    // their own; Felt and Daylight Robbery derive everything.
    //
    // The picker (ThemeButton in the bar, opening the ThemePicker overlay) writes
    // the chosen name to theme.json below, so it survives a restart. To add one,
    // drop another entry in here - the picker lists whatever is in this array.
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

            // Pinned so the default table is exact: candle-lit cards with gold
            // frames, a champagne progress climb, gold/crimson tray dots. The
            // other tables leave these out and derive from their six roles.
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
            urgent: "#c0392f"
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
            urgent: "#b3372f"
        }
    ]

    // The active theme's name, and the palette every widget binds to. themeName
    // is the persisted choice - the single source of truth, changed through
    // setTheme() so the write to disk follows.
    //
    // previewName is a transient override the picker paints with while you flick
    // through themes: colours resolves it first, so the whole shell re-tints live
    // without touching the file - arrow-keying the picker doesn't hammer the disk.
    // An unknown active name (a hand-edited file, a theme since removed) falls back
    // to the first entry.
    readonly property string themeName: prefs.theme
    property string previewName: ""
    readonly property string activeName: previewName !== "" ? previewName : themeName
    readonly property var colours: themes.find(t => t.name === activeName) ?? themes[0]

    // The notification and tray colours for the active theme: the theme's own
    // pinned block if it has one (Noir does; Vegas pins progress/tray), otherwise derived from its
    // six roles so the cards and dots follow whatever theme is on. The QtObjects
    // further down bind through these.
    readonly property var activeNotif: colours.notif ?? deriveNotif(colours)
    readonly property var activeProgress: colours.progress ?? deriveProgress(colours)

    // Linear blend of two "#rrggbb" strings, t from a (0) to b (1). The building
    // block the derivations lean on - most roles are a role colour nudged toward
    // surface, accent or urgent.
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

    // Build the three urgency palettes out of the six roles: cards are surface
    // lifted toward idle, text stays text/subtext, and the accent/frame carry the
    // theme's accent - urgent for critical, so a critical toast reads red-hot.
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

    // Flick to a theme without committing - the picker calls this as the selection
    // moves, so the whole shell previews it live. "" clears back to the saved one.
    function preview(name: string): void {
        if (name === "" || themes.some(t => t.name === name))
            previewName = name;
    }

    // Drop the preview, snapping back to the saved theme - the picker's cancel path.
    function clearPreview(): void {
        previewName = "";
    }

    // Commit a theme: persist it, clear any preview so colours reads the file,
    // and mirror it onto the rest of the system (Hyprland) so the choice is
    // shell-wide, not just the bar.
    function setTheme(name: string): void {
        if (!themes.some(t => t.name === name))
            return;
        previewName = "";
        prefs.theme = name;
        prefsFile.writeAdapter();
        applyToSystem(name);
    }

    // Push a theme out to the rest of the desktop. Today that is Hyprland:
    // scripts/apply-theme.sh writes ~/.config/hypr/colors.conf (sourced from
    // hyprland.conf so it survives a restart) and retints the window borders live
    // via hyprctl. The shell already previews live off Config.colours; this is the
    // bit that reaches beyond it. Only commits call here - preview stays in-process
    // so arrow-keying the picker doesn't spawn a script per keystroke.
    function applyToSystem(name: string): void {
        const c = themes.find(t => t.name === name);
        if (!c)
            return;
        // scripts/apply-theme.sh, resolved next to this file. execDetached wants a
        // plain path, so drop the file:// the url carries.
        const script = Qt.resolvedUrl("scripts/apply-theme.sh").toString().replace("file://", "");
        Quickshell.execDetached(["sh", script, c.name, c.surface, c.text, c.subtext, c.accent, c.idle, c.urgent]);
    }

    // Sync Hyprland to the saved theme once at startup, so the compositor matches
    // theme.json even if colors.conf was never written (first run) or the file was
    // hand-edited while the shell was down. Cheap: one detached script.
    Component.onCompleted: applyToSystem(themeName)

    // Persisted in Quickshell's per-shell state dir. watchChanges means an
    // external edit re-themes live too; on first run the file is absent, which is
    // expected rather than an error, so the read failure is silenced. We only
    // write from setTheme(), so our own write doesn't loop back through reload().
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
