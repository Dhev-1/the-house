-- ~/.config/hypr/hyprland.lua
-- Hyprland 0.55+ reads Lua. Split the way the config always was: binds, the
-- sidebar dock and the theme colours each live in their own file, pulled in with
-- require(). Each require is its own scope, so an error in one does not stop the
-- others loading. (hyprlock has its own format and keeps its .conf files.)

-----------------
---- SIDEBAR ----
-----------------

require("sidebar")

------------------
---- MONITORS ----
------------------

-- Catch-all first: whatever you have, at its preferred mode. Then monitors.lua
-- overrides it per output - nwg-displays writes that file, or write it by hand:
--   hl.monitor({ output = "DP-4", mode = "2560x1440@120.0", position = "0x0", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
require("monitors")
require("workspaces")

---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "thunar"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland")
    hl.exec_cmd("eval $(gnome-keyring-daemon --start --components=secrets)")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("qs -p ~/.config/quickshell/house")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("awww img ~/.config/quickshell/wallpapers/noir.png")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Qt apps have no reason to find the house on their own: this is what sends them
-- to qt6ct, which holds the palette (and the style) that scripts/apply-theme.sh
-- retints on every table change. The house's own shell overrides this for itself
-- in shell.qml - it wants the portal theme, for native tray menus.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.env("WLR_DRM_DEVICES", "/dev/dri/card2")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("LIBVA_DRIVER_NAME", "nvidia")

---------------------
---- PERMISSIONS ----
---------------------

-- Permission changes require a Hyprland restart, not a reload.
-- hl.config({ ecosystem = { enforce_permissions = true } })
-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        -- Card stock: windows want to read as cards laid out on felt rather than
        -- tiles butted up against each other, so the outer gap is wider than the
        -- inner one - the wallpaper showing around the edge is the table.
        gaps_in  = 6,
        gaps_out = 12,

        border_size = 2,

        -- A thin flat line of the accent. The focused window is picked out by
        -- the glow underneath it (decoration.shadow) rather than by the border.
        -- colors.lua, required last, is what actually paints; this is only the
        -- fallback for a machine that has never run the theme picker.
        col = {
            active_border   = "rgba(d4af5fee)",
            inactive_border = "rgba(2a232055)",
        },

        resize_on_border = false,
        allow_tearing    = true,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 13, -- the corner radius of an actual playing card
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        -- The spotlight. Only one table in the room is lit: the focused window
        -- keeps its colour and everything else sinks into the floor.
        -- dim_strength is set per table by colors.lua.
        dim_inactive = true,
        dim_strength = 0.25,

        shadow = {
            enabled      = true,
            -- A wide, soft, accent-tinted bloom instead of a tight black drop:
            -- a lamp hanging over the live table. Colours come from colors.lua.
            range          = 20,
            render_power   = 3,
            color          = "rgba(d4af5f33)",
            color_inactive = "rgba(00000088)",
        },

        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = true,
        vrr                     = 0,
    },

    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        accel_profile = "flat",
        follow_mouse  = 1,
        sensitivity   = 0,

        touchpad = {
            natural_scroll = false,
        },
    },

    cursor = {
        no_warps = true,
    },
})

--------------------
---- ANIMATIONS ----
--------------------

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- The house curves. `deal` ends above 1, so a window overshoots a hair and
-- settles back - a card skimmed across the felt catching as it stops. `muck` is
-- the opposite shape: slow to let go, then snatched away.
hl.curve("deal",           { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.04}  } })
hl.curve("muck",           { type = "bezier", points = { {0.6, 0},     {0.9, 0.2}   } })
hl.curve("rail",           { type = "bezier", points = { {0, 0},       {1, 1}       } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })

-- The gradient angle sweeps one full turn as a window opens, then stops.
-- Deliberately not `loop`: looping repaints the border every frame for as long
-- as the window is up. Once, on the deal, is the effect.
hl.animation({ leaf = "borderangle",   enabled = true, speed = 30,   bezier = "rail" })

hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
-- Dealt in from the top - the same corner the bar and the dealer live in.
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 5,    bezier = "deal",         style = "slide top" })
-- Swept into the muck: holds still a beat, then is dragged off to the right.
-- fadeOut below has to be at least this long or the effect is invisible - the
-- muck curve is back-loaded, so a shorter fade leaves the window transparent
-- before it goes anywhere.
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 2.8,  bezier = "muck",         style = "slide right" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
-- Matched to windowsOut, not left at the stock 1.46 - see the note there.
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 2.8,  bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
-- The shoe advancing: workspaces slide rather than crossfade in place.
hl.animation({ leaf = "workspaces",    enabled = true, speed = 3,    bezier = "deal",         style = "slidefade 15%" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 3,    bezier = "deal",         style = "slidefade 15%" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2.4,  bezier = "muck",         style = "slidefade 15%" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

-- The groupbar (SUPER+G) is deliberately left stock. Styling it as a chip rack
-- was tried and dropped: at any height that reads as a chip it competes with the
-- bottom bar's pit for the same "row of chips" idea.

---------------
---- INPUT ----
---------------

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------

require("binds")

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    -- Ignore maximize requests from all apps.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name  = "satty-float",
    match = { class = "^(com\\.gabm\\.satty)$" },

    float  = true,
    center = true,
    size   = { "monitor_w*0.7", "monitor_h*0.7" },
})

----------------
---- COLOURS ----
----------------

-- Written by the house bar's theme picker (cloon/newdot/house
-- scripts/apply-theme.sh). Required last so its general/decoration values win.
-- pcall: on a machine that has never run the picker the file is absent, and a
-- bare require of a missing module would abort the rest of this file.
pcall(require, "colors")
