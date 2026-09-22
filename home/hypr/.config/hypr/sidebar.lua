-- ~/.config/hypr/sidebar.lua
-- Sidebar dock. The tab and all the docking logic live in the house shell
-- (~/.config/quickshell/house); this file only wires Hyprland up to it.
--
-- Docked windows are floating + pinned, so they sit on the left while you keep
-- working in whatever is focused. No special workspace.

-- Docked windows are parked here while hidden. Nothing should live here
-- otherwise; it is never switched to.
hl.workspace_rule({ workspace = "name:sidebar", gaps_out = 0, gaps_in = 0 })

-- --- Keybinds: one action each ---
local sidebar = "qs -p ~/.config/quickshell/house ipc call sidebar "

hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd(sidebar .. "dock"),   { description = "dock focused window" })
hl.bind("SUPER + SHIFT + U", hl.dsp.exec_cmd(sidebar .. "undock"), { description = "undock focused window" })
hl.bind("SUPER + ALT + D",   hl.dsp.exec_cmd(sidebar .. "toggle"), { description = "show/hide the dock" })
hl.bind("SUPER + TAB",       hl.dsp.exec_cmd(sidebar .. "cycle"),  { description = "cycle docked windows" })
