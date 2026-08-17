-- Keybinds. Migrated from binds.conf.
--
-- Note on duplicates: Hyprland fires *every* bind that matches a key combo, not
-- just the last one declared. binds.conf relied on that deliberately in one
-- place (ALT+Tab does cyclenext *and* bringactivetotop) and, it turns out,
-- accidentally in three others. Those are kept as-is so this migration does not
-- change behaviour, and marked FIXME. See the migration notes in the PR.

local vars = require("vars")

local mainMod = vars.mainMod
local qs      = vars.qs

hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("firefox"))

-- Sidebar dock binds live in sidebar.lua (SUPER SHIFT D / SUPER ALT D / SUPER TAB)

-- Microphone / Headphones audio
-- FIXME: collides with the splitratio bind further down; both fire on SUPER+M.
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"))

hl.bind(mainMod .. " + E",     hl.dsp.exec_cmd(vars.fileManager))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(vars.terminal))

hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(qs .. " ipc call notifications closeAll")) -- dismiss all notifications
hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd("brave"))


-- Master Layout
--
-- MIGRATION NOTE: the desktop runs `layout = dwindle`, so every one of these
-- has been a silent no-op under hyprlang. Under Lua an unsupported layoutmsg
-- raises instead of being ignored, so they go through vars.if_layout, which
-- checks the active workspace's layout first. They will start working the
-- moment a workspace is actually on master, and stay quiet otherwise.
hl.bind(mainMod .. " + CTRL + D",      vars.if_layout("master", hl.dsp.layout("removemaster")))
hl.bind(mainMod .. " + I",             vars.if_layout("master", hl.dsp.layout("addmaster")))
hl.bind(mainMod .. " + J",             vars.if_layout("master", hl.dsp.layout("cyclenext")))
hl.bind(mainMod .. " + K",             vars.if_layout("master", hl.dsp.layout("cycleprev")))
hl.bind(mainMod .. " + CTRL + Return", vars.if_layout("master", hl.dsp.layout("swapwithmaster")))

-- Dwindle Layout
-- hl.bind(mainMod .. " + SHIFT + I", hl.dsp.layout("togglesplit")) -- only works on dwindle layout
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo()) -- dwindle

-- Works on either layout (Master or Dwindle)
-- FIXME: collides with the mic-mute bind above; both fire on SUPER+M.
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("hyprctl dispatch splitratio 0.3"))


-- Grouping / group windows
hl.bind(mainMod .. " + G", hl.dsp.group.toggle()) -- toggle group
-- hl.bind("CTRL + TAB", ...) -- change focus to another window
-- `changegroupactive, f` / `, b` -- forward and back are relative offsets now;
-- hl.dsp.group.active takes an absolute index or a signed string.
hl.bind(mainMod .. " + CTRL + right", hl.dsp.group.active({ index = "+1" }))
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.group.active({ index = "-1" }))

hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ into_group = "l" }))
-- FIXME: collides with the hyprlock bind further down; both fire on SUPER+SHIFT+L.
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ into_group = "r" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ into_group = "u" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ into_group = "d" }))

hl.bind(mainMod .. " + SHIFT + O", hl.dsp.window.move({ out_of_group = true }))

-- Cycle windows; if floating, bring to top.
-- Both of these are meant to fire on the same combo -- this one is deliberate.
hl.bind("ALT + TAB", hl.dsp.window.cycle_next())
hl.bind("ALT + TAB", hl.dsp.window.alter_zorder({ mode = "top" }))


-- Resize windows
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -50, y =   0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x =  50, y =   0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x =   0, y = -50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x =   0, y =  50, relative = true }), { repeating = true })

-- Move windows
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.move({ direction = "d" }))

-- Swap windows
hl.bind(mainMod .. " + ALT + left",  hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + ALT + up",    hl.dsp.window.swap({ direction = "u" }))
hl.bind(mainMod .. " + ALT + down",  hl.dsp.window.swap({ direction = "d" }))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "d" }))

-- Workspaces related
-- hl.bind(mainMod .. " + TAB",           hl.dsp.focus({ workspace = "m+1" }))
-- hl.bind(mainMod .. " + SHIFT + TAB",   hl.dsp.focus({ workspace = "m-1" }))

-- Special workspace
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + W",         hl.dsp.workspace.toggle_special())

-- The following mappings use the key codes to better support various keyboard
-- layouts. 1 is code:10, 2 is code:11, etc.
for i = 1, 10 do
    local code = "code:" .. (9 + i)

    -- Switch workspaces with mainMod + [0-9]
    hl.bind(mainMod .. " + " .. code, hl.dsp.focus({ workspace = i }))

    -- Move active window and follow, mainMod + SHIFT + [0-9]
    hl.bind(mainMod .. " + SHIFT + " .. code, hl.dsp.window.move({ workspace = i }))

    -- Move active window silently, mainMod + CTRL + [0-9]
    hl.bind(mainMod .. " + CTRL + " .. code, hl.dsp.window.move({ workspace = i, silent = true }))
end

hl.bind(mainMod .. " + SHIFT + bracketleft",  hl.dsp.window.move({ workspace = "-1" })) -- brackets [
hl.bind(mainMod .. " + SHIFT + bracketright", hl.dsp.window.move({ workspace = "+1" })) -- brackets ]

hl.bind(mainMod .. " + CTRL + bracketleft",  hl.dsp.window.move({ workspace = "-1", silent = true }))
hl.bind(mainMod .. " + CTRL + bracketright", hl.dsp.window.move({ workspace = "+1", silent = true }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + period",     hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + comma",      hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true }) -- left click
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true }) -- right click


-- Common shortcuts
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window")) -- Main Menu (app launcher)

hl.bind(mainMod .. " + F",         hl.dsp.exec_cmd("zen-browser"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("spotify"))

-- FIXME: collides with the "move into group, right" bind above; both fire on
-- SUPER+SHIFT+L, so grouping a window also locks the screen.
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("hyprlock"))

-- Was `exec, hyprctl dispatch setprop active opaque toggle` -- a shell round
-- trip through hyprctl to reach a dispatcher the config can now call directly.
hl.bind(mainMod .. " + CTRL + O", hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" }))

hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("zen-browser --blank-window chatgpt.com"))

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(qs .. " ipc call theme toggle"))

hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd('grim -g "$(slurp)" ~/Captures/shot_$(date +%s).png'))

-- FIXME: both of these point at /home/delta/, which is not this machine's home
-- directory -- they have been dead since the repo moved. Left verbatim so the
-- migration does not quietly change what they do; fix the path separately.
-- Snip -> OCR full text to clipboard
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("/home/delta/iwroteit/scripts/snip-ocr.sh"))
-- Snip -> OCR leading numbers -> clipboard
hl.bind(mainMod .. " + CTRL + PRINT", hl.dsp.exec_cmd("/home/delta/iwroteit/scripts/snip-ocr.sh eet"))

hl.bind(mainMod .. " + Q", hl.dsp.window.close())

-- FIXME: was `closewindow` with no window argument, which never selected
-- anything -- dead alongside the killactive bind directly above it, on the same
-- combo. Dropped rather than translated; restore with an explicit selector if
-- it was meant to do something.
-- hl.bind(mainMod .. " + Q", hl.dsp.window.close({ window = ... }))

-- FIXME: collides with the firefox bind at the top; both fire on SUPER+O.
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("obsidian"))

hl.bind("CTRL + PRINT", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))

-- Satty only
hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd(
    [[sh -c 'FILE="$HOME/Captures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"; grim -g "$(slurp)" -t ppm - | satty --filename - --output-filename "$FILE" --copy-command "wl-copy < \"$FILE\""']]
))
-- Clipboard + Satty
hl.bind("CTRL + SHIFT + PRINT", hl.dsp.exec_cmd(
    [[sh -c 'TMP=$(mktemp --suffix=.png); grim -g "$(slurp)" -t ppm - | satty --filename - --output-filename "$TMP" --copy-command "wl-copy < \"$TMP\""']]
))

-- FIXME: binds.conf pointed at ~/.config/hypr/save_session.sh, but the file
-- this repo actually stows is scripts/sesh_save.sh. Pointed at the real one.
hl.bind(mainMod .. " + F5", hl.dsp.exec_cmd("~/.config/hypr/scripts/sesh_save.sh"))


-- Features / extras
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen())                   -- whole full screen
hl.bind(mainMod .. " + CTRL + F",  hl.dsp.window.fullscreen({ mode = 1 }))       -- fake full screen
hl.bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }))   -- float mode

-- FIXME: `workspaceopt` is deprecated in Hyprland (the binary says so on
-- startup) and has no Lua binding. Left as a shell call so it keeps working for
-- as long as the dispatcher survives; expect it to go with hyprlang.
hl.bind(mainMod .. " + ALT + SPACE", hl.dsp.exec_cmd("hyprctl dispatch workspaceopt allfloat")) -- all float mode

-- Desktop zooming / magnifier
hl.bind(mainMod .. " + ALT + mouse_down", hl.dsp.exec_cmd(
    [[hyprctl keyword cursor:zoom_factor "$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor * 2.0}')"]]
))
hl.bind(mainMod .. " + ALT + mouse_up", hl.dsp.exec_cmd(
    [[hyprctl keyword cursor:zoom_factor "$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor / 2.0}')"]]
))

-- Features / extras (UserScripts)
-- FIXME: `pkill active` kills processes whose name contains "active", which is
-- almost certainly not what was meant. Left verbatim; worth deleting.
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("pkill active"))


-- Brightness controls
hl.bind("XF86Mail",       hl.dsp.exec_cmd("ddcutil --bus=12 setvcp 10 - 5"), { locked = true, repeating = true })
hl.bind("XF86Calculator", hl.dsp.exec_cmd("ddcutil --bus=12 setvcp 10 + 5"), { locked = true, repeating = true })

-- Volume controls
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true })
