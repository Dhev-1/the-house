-- ~/.config/hypr/binds.lua

local mainMod = "SUPER"
local house   = "qs -p ~/.config/quickshell/house ipc call "

local function bind(keys, action, flags)
    hl.bind(keys, action, flags)
end

-- Pin the focused window to look exactly like an active one: fully opaque AND
-- exempt from dim_inactive (the dimming, not the alpha, is what darkens it here).
-- set_prop takes a value, not a toggle, so remember which windows are lit.
local lit = {}
bind(mainMod .. " + CTRL + O", function()
    local w = hl.get_active_window()
    if not w then
        return
    end
    local on = not lit[w.address]
    lit[w.address] = on or nil
    local value = on and "1" or "0"
    hl.dispatch(hl.dsp.window.set_prop({ prop = "opaque", value = value }))
    hl.dispatch(hl.dsp.window.set_prop({ prop = "no_dim", value = value }))
end)

-- Sidebar dock binds live in sidebar.lua (SUPER SHIFT D / SUPER ALT D / SUPER TAB)

-- Microphone Headphones Audio
bind("SUPER + M", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"))
bind("SUPER + N", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"))

bind(mainMod .. " + E",     hl.dsp.exec_cmd("thunar"))
bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("kitty"))

bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(house .. "notifications closeAll"), { description = "dismiss all notifications" })
bind(mainMod .. " + B", hl.dsp.exec_cmd("brave"))

-- Master Layout
bind(mainMod .. " + CTRL + D",      hl.dsp.layout("removemaster"))
bind(mainMod .. " + I",             hl.dsp.layout("addmaster"))
bind(mainMod .. " + J",             hl.dsp.layout("cyclenext"))
bind(mainMod .. " + K",             hl.dsp.layout("cycleprev"))
bind(mainMod .. " + CTRL + Return", hl.dsp.layout("swapwithmaster"))

-- Dwindle Layout
-- bind(mainMod .. " + SHIFT + I", hl.dsp.layout("togglesplit")) -- only works on dwindle layout
bind(mainMod .. " + P", hl.dsp.window.pseudo()) -- dwindle

-- Grouping
bind(mainMod .. " + G",            hl.dsp.group.toggle())
bind(mainMod .. " + CTRL + right", hl.dsp.group.next())
bind(mainMod .. " + CTRL + left",  hl.dsp.group.prev())

bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ into_group = "left" }))
bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ into_group = "up" }))
bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ into_group = "down" }))

bind(mainMod .. " + SHIFT + O", hl.dsp.window.move({ out_of_group = true }))

-- Cycle windows; if floating, bring to top
bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)

-- Resize windows
bind(mainMod .. " + SHIFT + left",  hl.dsp.window.resize({ x = -50, y = 0,   relative = true }), { repeating = true })
bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 50,  y = 0,   relative = true }), { repeating = true })
bind(mainMod .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0,   y = -50, relative = true }), { repeating = true })
bind(mainMod .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0,   y = 50,  relative = true }), { repeating = true })

-- Move windows
bind(mainMod .. " + CTRL + left",  hl.dsp.window.move({ direction = "left" }))
bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ direction = "right" }))
bind(mainMod .. " + CTRL + up",    hl.dsp.window.move({ direction = "up" }))
bind(mainMod .. " + CTRL + down",  hl.dsp.window.move({ direction = "down" }))

-- Swap windows
bind(mainMod .. " + ALT + left",  hl.dsp.window.swap({ direction = "left" }))
bind(mainMod .. " + ALT + right", hl.dsp.window.swap({ direction = "right" }))
bind(mainMod .. " + ALT + up",    hl.dsp.window.swap({ direction = "up" }))
bind(mainMod .. " + ALT + down",  hl.dsp.window.swap({ direction = "down" }))

-- Move focus with mainMod + arrow keys
bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Special workspace. The unnamed one is "special:special", which is what
-- toggle_special("special") adds its prefix to.
bind(mainMod .. " + SHIFT + W", hl.dsp.window.move({ workspace = "special" }))
bind(mainMod .. " + W",         hl.dsp.workspace.toggle_special("special"))

-- Keycodes rather than keysyms, for layout independence: code:10 is key 1 ...
-- code:19 is key 0.
--   mainMod + [0-9]         switch workspace
--   mainMod + SHIFT + [0-9] move the window there and follow
--   mainMod + CTRL + [0-9]  move the window there silently
for i = 1, 10 do
    local key = "code:" .. (i + 9)
    bind(mainMod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }))
    bind(mainMod .. " + CTRL + " .. key,    hl.dsp.window.move({ workspace = i, follow = false }))
end
bind(mainMod .. " + SHIFT + bracketleft",  hl.dsp.window.move({ workspace = "-1" }))
bind(mainMod .. " + SHIFT + bracketright", hl.dsp.window.move({ workspace = "+1" }))
bind(mainMod .. " + CTRL + bracketleft",   hl.dsp.window.move({ workspace = "-1", follow = false }))
bind(mainMod .. " + CTRL + bracketright",  hl.dsp.window.move({ workspace = "+1", follow = false }))

-- Scroll through existing workspaces with mainMod + scroll
bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
bind(mainMod .. " + period",     hl.dsp.focus({ workspace = "e+1" }))
bind(mainMod .. " + comma",      hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- The house launcher: a hand of apps, dealt (house/Launcher.qml).
bind(mainMod .. " + D", hl.dsp.exec_cmd(house .. "launcher toggle"), { description = "Main Menu (APP Launcher)" })
-- rofi is still installed and still themed - its run/filebrowser/window modes are
-- things the hand does not do. Uncomment to go back to it.
-- bind(mainMod .. " + D", hl.dsp.exec_cmd("pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window"))

bind(mainMod .. " + F",         hl.dsp.exec_cmd("zen-browser"))
bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("spotify"))

bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("hyprlock"))

bind(mainMod .. " + C", hl.dsp.exec_cmd("zen-browser --blank-window chatgpt.com"))

bind("SUPER + T", hl.dsp.exec_cmd(house .. "theme toggle"))

bind(mainMod .. " + Print", hl.dsp.exec_cmd([[grim -g "$(slurp)" ~/Captures/shot_$(date +%s).png]]))

-- Once bound to both killactive and closewindow; they are the same graceful close.
bind("SUPER + Q", hl.dsp.window.close())

bind("SUPER + O", hl.dsp.exec_cmd("obsidian"))

bind("CTRL + Print", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))

-- Satty only
bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd([[sh -c 'FILE="$HOME/Captures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"; grim -g "$(slurp)" -t ppm - | satty --filename - --output-filename "$FILE" --copy-command "wl-copy < \"$FILE\""']]))
-- Clipboard + Satty
bind("CTRL + SHIFT + Print", hl.dsp.exec_cmd([[sh -c 'TMP=$(mktemp --suffix=.png); grim -g "$(slurp)" -t ppm - | satty --filename - --output-filename "$TMP" --copy-command "wl-copy < \"$TMP\""']]))

-- Features / extras
bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" })) -- whole full screen
bind(mainMod .. " + CTRL + F",  hl.dsp.window.fullscreen({ mode = "maximized" }))  -- fake full screen
bind(mainMod .. " + V",         hl.dsp.window.float())                             -- float mode

-- All-float mode. There is no Lua workspaceopt, so this floats every window on
-- the workspace - or tiles them all back if they are already floating. Unlike
-- workspaceopt it does not also float windows opened afterwards.
bind(mainMod .. " + ALT + SPACE", function()
    local ws = hl.get_active_workspace()
    if not ws then
        return
    end
    local windows = hl.get_workspace_windows(ws.id)
    local anyTiled = false
    for _, w in ipairs(windows) do
        if not w.floating then
            anyTiled = true
            break
        end
    end
    local action = anyTiled and "enable" or "disable"
    for _, w in ipairs(windows) do
        hl.dispatch(hl.dsp.window.float({ window = w, action = action }))
    end
end)

-- Desktop zooming or magnifier
local function zoom(factor)
    local current = hl.get_config("cursor.zoom_factor")
    if type(current) ~= "number" or current < 1 then
        current = 1
    end
    hl.config({ ["cursor.zoom_factor"] = math.max(1, current * factor) })
end
bind(mainMod .. " + ALT + mouse_down", function() zoom(2.0) end)
bind(mainMod .. " + ALT + mouse_up",   function() zoom(0.5) end)

bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())

-- Brightness controls
bind("XF86Mail",       hl.dsp.exec_cmd("ddcutil --bus=12 setvcp 10 - 5"), { repeating = true, locked = true })
bind("XF86Calculator", hl.dsp.exec_cmd("ddcutil --bus=12 setvcp 10 + 5"), { repeating = true, locked = true })

-- Volume controls
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true, locked = true })
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true, locked = true })
bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true })
