pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

// The sidebar dock. Docked windows are floating + pinned, so they stay put on
// the left while you work in whatever else is focused, and follow you across
// workspaces. Hiding parks them on a holding workspace instead.
//
// No special workspace: that made the dock an overlay you were either inside
// or not, so focusing another window necessarily dismissed it.
Singleton {
    id: root

    // Hyprland addresses, without the 0x prefix (that's how Quickshell reports
    // them; dispatch wants it back on).
    property var addresses: []

    property bool shown: false

    // Docked windows that still exist, in dock order.
    readonly property var windows: root.addresses.map(a => Hyprland.toplevels.values.find(t => t.address === a)).filter(t => t)

    readonly property ShellScreen screen: Quickshell.screens[0]

    function target(addr: string): string {
        return `address:0x${addr}`;
    }

    // Float it, size it to the sidebar, park it on the left inside the border,
    // and pin it so it survives workspace switches.
    function place(addr: string): void {
        const gap = Config.borderThickness;
        const w = Config.sidebarWidth;
        const h = root.screen.height - gap * 2;
        const x = root.screen.x + gap;
        const y = root.screen.y + gap;
        const t = target(addr);

        Hyprland.dispatch(`setfloating ${t}`);
        Hyprland.dispatch(`resizewindowpixel exact ${w} ${h},${t}`);
        Hyprland.dispatch(`movewindowpixel exact ${x} ${y},${t}`);
        Hyprland.dispatch(`pin ${t}`);
    }

    function dock(): void {
        const addr = Hyprland.activeToplevel?.address;
        if (!addr || root.addresses.includes(addr))
            return;

        prune();
        root.addresses = [...root.addresses, addr];

        // Docking always shows the dock, otherwise the window just vanishes.
        if (!root.shown)
            root.shown = true;

        place(addr);
    }

    function undock(addr: string): void {
        if (!root.addresses.includes(addr))
            return;

        root.addresses = root.addresses.filter(a => a !== addr);

        const t = target(addr);
        if (root.shown)
            Hyprland.dispatch(`pin ${t}`); // pin toggles; drop it before re-tiling
        Hyprland.dispatch(`movetoworkspacesilent ${Hyprland.focusedWorkspace?.id ?? 1},${t}`);
        Hyprland.dispatch(`settiled ${t}`);
    }

    // Undocks the focused window, or the last docked one if focus is elsewhere.
    function undockCurrent(): void {
        prune();

        const live = root.windows;
        if (live.length === 0)
            return;

        const current = Hyprland.activeToplevel?.address;
        undock(live.some(t => t.address === current) ? current : live[live.length - 1].address);
    }

    function show(): void {
        if (root.shown)
            return;

        prune();
        root.shown = true;

        const ws = Hyprland.focusedWorkspace?.id ?? 1;
        for (const w of root.windows) {
            Hyprland.dispatch(`movetoworkspacesilent ${ws},${target(w.address)}`);
            place(w.address);
        }
    }

    function hide(): void {
        if (!root.shown)
            return;

        prune();
        root.shown = false;

        for (const w of root.windows) {
            Hyprland.dispatch(`pin ${target(w.address)}`); // toggles pin off
            Hyprland.dispatch(`movetoworkspacesilent name:${Config.sidebarWorkspace},${target(w.address)}`);
        }
    }

    function toggle(): void {
        if (root.shown)
            hide();
        else
            show();
    }

    // Raise and focus the next docked window. They stack in the same spot.
    function cycle(): void {
        prune();

        const live = root.windows;
        if (live.length === 0)
            return;

        if (!root.shown)
            show();

        const current = Hyprland.activeToplevel?.address;
        const index = live.findIndex(t => t.address === current);
        focus(live[(index + 1) % live.length].address);
    }

    function focus(addr: string): void {
        if (!root.shown)
            show();

        Hyprland.dispatch(`alterzorder top,${target(addr)}`);
        Hyprland.dispatch(`focuswindow ${target(addr)}`);
    }

    function prune(): void {
        Hyprland.refreshToplevels();
        root.addresses = root.addresses.filter(a => Hyprland.toplevels.values.some(t => t.address === a));
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            // A docked window was closed: drop it, or its icon lingers on the tab.
            if (event.name === "closewindow")
                root.addresses = root.addresses.filter(a => a !== event.data.trim());
        }
    }

    Component.onCompleted: Hyprland.refreshToplevels()
}
