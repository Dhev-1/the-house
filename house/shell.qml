//@ pragma UseQApplication
// Tray menus are native QMenus. Without a platform theme Qt ignores the
// portal's colour scheme and paints them light, so point it at the portal.
//@ pragma Env QT_QPA_PLATFORMTHEME=xdgdesktopportal
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

    // Dunst's ctrl+space / ctrl+shift+space, kept working:
    //   qs -p ~/cloon/newdot/house ipc call notifications close
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

    // The power menu popout, for a keybind:
    //   qs -p ~/cloon/newdot/house ipc call power toggle
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

    // The theme picker overlay, for a keybind:
    //   qs -p ~/cloon/newdot/house ipc call theme toggle
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

            Exclusions {
                screen: scope.modelData
            }
        }
    }
}
