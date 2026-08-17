-- #######################################################################################
-- THE HOUSE -- Hyprland config, Lua edition.
-- Migrated from hyprland.conf; hyprlang is dropped in Hyprland 0.57.
-- #######################################################################################

local vars = require("vars")

require("sidebar")

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland")
    hl.exec_cmd("eval $(gnome-keyring-daemon --start --components=secrets)")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd(vars.qs)
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("awww img ~/cloon/newdot/wallpapers/noir.png")
end)

require("monitors")
require("workspaces")


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- monitors.lua (nwg-displays, required above) is the real source of truth for
-- the desktop's two heads. This is the fallback for anything else.
hl.monitor({
    output   = "DP-4",
    mode     = "2560x1440@59.95",
    position = "0x0",
    scale    = 1,
})


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("WLR_DRM_DEVICES", "/dev/dri/card2")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("LIBVA_DRIVER_NAME", "nvidia")


-----------------------
----- PERMISSIONS -----
-----------------------

-- Please note permission changes here require a Hyprland restart and are not
-- applied on-the-fly for security reasons.

-- hl.config({ ecosystem = { enforce_permissions = true } })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        -- Card stock: windows want to read as cards laid out on felt rather
        -- than tiles butted up against each other, so the outer gap is wider
        -- than the inner one -- the wallpaper showing around the edge is the
        -- table.
        gaps_in  = 6,   -- was 5
        gaps_out = 12,  -- was 5

        border_size = 2,

        -- A thin flat line of the accent. The focused window is meant to be
        -- picked out by the glow underneath it (decoration.shadow, below)
        -- rather than by the border, so this stays quiet. Vegas is the
        -- exception and swaps in a gradient rail; that lives in colors.lua,
        -- which is required last and is what actually paints. This is only the
        -- fallback for a checkout that has never run the theme picker.
        col = {
            active_border   = "rgba(d4af5fee)",
            inactive_border = "rgba(2a232055)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on
        -- borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/
        -- before you turn this on
        allow_tearing = true,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 13,  -- was 10; the corner radius of an actual playing card
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        -- The spotlight. Only one table in the room is lit: the focused window
        -- keeps its colour and everything else sinks into the floor.
        -- dim_strength is set per table by colors.lua -- the light table needs
        -- far less of it than the dark ones, where 0.25 reads as dimmed and on
        -- cream reads as muddy.
        dim_inactive = true,
        dim_strength = 0.25,

        shadow = {
            enabled = true,
            -- A wide, soft, accent-tinted bloom instead of a tight black drop:
            -- a lamp hanging over the live table. Both colours come from
            -- colors.lua.
            range          = 20,  -- was 4
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
})

-- Default curves, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })

-- The house curves. `deal` ends above 1, so a window overshoots a hair and
-- settles back -- a card skimmed across the felt catching as it stops. `muck`
-- is the opposite shape: slow to let go, then snatched away.
hl.curve("deal",           { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.04} } })
hl.curve("muck",           { type = "bezier", points = { {0.6, 0},     {0.9, 0.2}  } })
hl.curve("rail",           { type = "bezier", points = { {0, 0},       {1, 1}      } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })

-- The gradient angle sweeps one full turn as a window opens, then stops.
-- Deliberately not `loop`: looping repaints the border every frame for as long
-- as the window is up, which on this box means holding the GPU awake forever
-- for a sheen nobody is looking at. Once, on the deal, is the effect.
hl.animation({ leaf = "borderangle",   enabled = true, speed = 30,   bezier = "rail" })

hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
-- Dealt in from the top -- the same corner the bar and the dealer live in.
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 5,    bezier = "deal", style = "slide top" })
-- Swept into the muck: holds still a beat, then is dragged off to the right,
-- which is the corner the bar and the dealer are in. Dealt in from the top,
-- swept off to the side.
--
-- fadeOut below has to be at least this long or the effect is invisible. The
-- muck curve is back-loaded on purpose -- two thirds of the way through the
-- window has barely moved, and all the travel is in the last instant. Leave the
-- fade shorter than this and the window is fully transparent before it goes
-- anywhere, so all you see is a fade.
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 2.8,  bezier = "muck", style = "slide right" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
-- Matched to windowsOut, not left at the stock 1.46 -- see the note there.
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 2.8,  bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
-- The shoe advancing: workspaces slide rather than crossfade in place.
hl.animation({ leaf = "workspaces",    enabled = true, speed = 3,    bezier = "deal", style = "slidefade 15%" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 3,    bezier = "deal", style = "slidefade 15%" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2.4,  bezier = "muck", style = "slidefade 15%" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

-- "Smart gaps" / "No gaps when only" -- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

hl.config({
    dwindle = {
        -- pseudotile is bound to mainMod + P in binds.lua
        preserve_split = true, -- You probably want this
    },

    master = {
        new_status = "master",
    },
})

-- The groupbar (SUPER+G) is deliberately left stock. Styling it as a chip rack
-- was tried and dropped: at any height that reads as a chip it competes with
-- the bottom bar's pit for the same "row of chips" idea, and at a subtle height
-- the fill disappears into a dark wallpaper and leaves floating text.


----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = -1,   -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true, -- If true disables the random hyprland logo / anime girl background. :(
        vrr                     = 0,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        accel_profile = "flat",
        follow_mouse  = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },

    cursor = {
        no_warps = true,
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- Example per-device config
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
    -- Ignore maximize requests from all apps. You'll probably like this.
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

-- Hyprland-run windowrule
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
    size   = "70% 70%",
})

-- Theme colours written by the house bar's theme picker (cloon/newdot/house
-- scripts/apply-theme.sh). Required last so its general/decoration overrides
-- win.
require("colors")
