-- Shared values for the house's Hyprland config.
--
-- Hyprlang's `$mainMod` was global across every sourced file. Lua locals are
-- file-scoped, so anything used in more than one file lives here and is pulled
-- in with `local vars = require("vars")`. This is the one structural thing the
-- migration forced; everything else is a rename.

local M = {}

M.mainMod = "SUPER"

M.terminal    = "kitty"
M.fileManager = "thunar"

-- The house shell (quickshell). The hypr config launches and talks to it by
-- absolute path -- see the Post-install note in the README if this repo is not
-- at ~/cloon/newdot.
M.houseDir = "~/cloon/newdot/house"
M.qs       = "qs -p " .. M.houseDir

-- Guard for layout-specific dispatchers.
--
-- Under hyprlang a `layoutmsg` aimed at a layout that was not active got
-- silently dropped. Under Lua it raises instead, which turns the master-layout
-- binds below into errors on a dwindle desktop. This checks the active
-- workspace's layout first and does nothing if it does not match.
--
-- Pattern is the maintainer's, from hyprwm/Hyprland discussion #14237.
function M.if_layout(layout, dsp)
    return function()
        local ws = hl.get_active_workspace()
        if ws == nil then return end
        if ws.tiled_layout == layout then
            return hl.dispatch(dsp)
        end
    end
end

return M
