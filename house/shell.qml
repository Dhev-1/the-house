//@ pragma UseQApplication
// Tray menus are native QMenus. Without a platform theme Qt ignores the
// portal's colour scheme and paints them light, so point it at the portal.
//@ pragma Env QT_QPA_PLATFORMTHEME=xdgdesktopportal
// The threaded render loop steps animations off the actual vblank; the basic
// loop Qt falls back to on some drivers steps them off a 16ms timer, capping
// every animation at 60fps on a 120Hz screen. Ask rather than hope.
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1

import Quickshell
import Quickshell.Io
import qs.services

ShellRoot {
    settings.watchFiles: true

    // Hyprland keybinds call in here:
    //   qs -p ~/cloon/newdot/house ipc call sidebar dock
    IpcHandler {
        target: "sidebar"

        // One action per keybind, no overloading.
        function dock(): void {
            Dock.dock();
        }

        // The focused window, or the last docked one if focus is elsewhere.
        function undock(): void {
            Dock.undockCurrent();
        }

        // Not named show/hide: "show" collides with the `qs ipc show` subcommand,
        // so `ipc call sidebar show` never reaches us.
        function open(): void {
            Dock.show();
        }

        function close(): void {
            Dock.hide();
        }

        function toggle(): void {
            Dock.toggle();
        }

        function cycle(): void {
            Dock.cycle();
        }
    }

    // Dunst's ctrl+space / ctrl+shift+space, kept working.
    IpcHandler {
        target: "notifications"

        // The newest toast, which is what "close current" means with no pointer.
        function close(): void {
            Notifications.dismissLatest();
        }

        function closeAll(): void {
            Notifications.dismissAll();
        }
    }

    // The power menu popout.
    IpcHandler {
        target: "power"

        function toggle(): void {
            PowerPanel.toggle();
        }

        function open(): void {
            PowerPanel.open = true;
        }

        function close(): void {
            PowerPanel.close();
        }
    }

    // The launcher overlay.
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            LauncherPanel.toggle();
        }

        // Not named show/hide: "show" collides with the `qs ipc show`
        // subcommand, the same trap the sidebar handler documents.
        function open(): void {
            LauncherPanel.open = true;
        }

        function close(): void {
            LauncherPanel.close();
        }
    }

    // The theme picker overlay.
    IpcHandler {
        target: "theme"

        function toggle(): void {
            ThemePanel.toggle();
        }

        function open(): void {
            ThemePanel.open = true;
        }

        function close(): void {
            ThemePanel.close();
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: scope

            required property ShellScreen modelData

            Border {
                screen: scope.modelData
            }

            Popups {
                monitor: scope.modelData
            }

            ClockPopout {
                monitor: scope.modelData
            }

            ThemePicker {
                monitor: scope.modelData
            }

            Launcher {
                monitor: scope.modelData
            }

            PowerMenu {
                monitor: scope.modelData
            }

            Bar {
                screen: scope.modelData
            }

            Sidebar {
                screen: scope.modelData
            }

            Music {
                screen: scope.modelData
            }

            ServiceTray {
                screen: scope.modelData
            }

            BottomBar {
                screen: scope.modelData
            }

            Exclusions {
                screen: scope.modelData
            }
        }
    }
}
