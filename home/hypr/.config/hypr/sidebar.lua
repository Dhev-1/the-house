-- ~/.config/hypr/sidebar.lua
-- Sidebar dock. The tab and all the docking logic live in the house shell
-- (~/cloon/newdot/house); this file only wires Hyprland up to it.
--
-- Docked windows are floating + pinned, so they sit on the left while you keep
-- working in whatever is focused. No special workspace.

local vars = require("vars")

-- Docked windows are parked here while hidden. Nothing should live here
-- otherwise; it is never switched to.
hl.workspace_rule({
    workspace = "name:sidebar",
    gaps_out = 0,
    gaps_in = 0,
})

-- --- Keybinds: one action each ---
local ipc = vars.qs .. " ipc call sidebar "

hl.bind(vars.mainMod .. " + SHIFT + D", hl.dsp.exec_cmd(ipc .. "dock"))   -- dock focused window
hl.bind(vars.mainMod .. " + ALT + D",   hl.dsp.exec_cmd(ipc .. "toggle")) -- show/hide the dock
hl.bind(vars.mainMod .. " + SHIFT + U", hl.dsp.exec_cmd(ipc .. "undock")) -- undock focused window
hl.bind(vars.mainMod .. " + TAB",       hl.dsp.exec_cmd(ipc .. "cycle"))  -- cycle docked windows
