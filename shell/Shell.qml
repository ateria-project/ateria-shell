import QtQuick
import Quickshell
import Quickshell.Io
import qs.features.bar
import qs.features.bluetooth
import qs.features.calendar
import qs.features.clipboard
import qs.features.launcher
import qs.features.notifications
import qs.features.quicksettings
import qs.features.settings
import qs.features.wallpaper
import qs.platform.bluetooth
import qs.platform.clipboard
import qs.platform.notifications
import qs.platform.settings
import qs.platform.workspace
import qs.shell

Scope {
    id: root

    readonly property var ipcFallbackScreen: SurfaceController.preferredScreen(WorkspaceService.focusedOutputName)

    component DeferredPanelLoader: LazyLoader {
        id: panelLoader

        required property bool requested
        property bool retained: false
        property bool presented: false

        active: panelLoader.retained

        function presentAfterConstruction(): void {
            Qt.callLater(() => {
                if (panelLoader.requested && panelLoader.retained)
                    panelLoader.presented = true;
            });
        }

        Component.onCompleted: {
            if (panelLoader.requested) {
                panelLoader.retained = true;
                panelLoader.presentAfterConstruction();
            }
        }
        onRequestedChanged: {
            if (panelLoader.requested) {
                const constructing = !panelLoader.retained;
                panelLoader.retained = true;
                if (constructing)
                    panelLoader.presentAfterConstruction();
                else
                    panelLoader.presented = true;
            } else {
                const wasPresented = panelLoader.presented;
                panelLoader.presented = false;
                // A request can be cancelled before the deferred presentation
                // callback runs. In that case no exit transition (and thus no
                // fullyClosed signal) will occur, so release the panel here.
                if (!wasPresented || panelLoader.item === null)
                    panelLoader.retained = false;
            }
        }

        Connections {
            target: panelLoader.item
            ignoreUnknownSignals: true

            function onFullyClosed(): void {
                // Do not destroy the panel from inside its animation-finished
                // signal stack. Deferring one event-loop turn lets Qt finish
                // settling the animation driver cleanly.
                Qt.callLater(() => {
                    if (!panelLoader.requested)
                        panelLoader.retained = false;
                });
            }
        }
    }

    Component.onCompleted: {
        SettingsBootstrap.initialize();
        WallpaperController.initialize();
        NotificationService.initialize();
        BluetoothService.initialize();
        ClipboardService.initialize();
    }

    Variants {
        model: Quickshell.screens

        Wallpaper {
            required property var modelData

            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            id: bar

            required property var modelData

            screen: bar.modelData
        }
    }

    DeferredPanelLoader {
        id: quickSettingsLoader
        requested: SurfaceController.quickSettingsOpen

        QuickSettingsPanel {
            open: quickSettingsLoader.presented
        }
    }

    DeferredPanelLoader {
        id: calendarLoader
        requested: SurfaceController.calendarOpen

        CalendarPanel {
            open: calendarLoader.presented
        }
    }

    DeferredPanelLoader {
        id: notificationPanelLoader
        requested: SurfaceController.notificationPanelOpen

        NotificationPanel {
            open: notificationPanelLoader.presented
        }
    }

    DeferredPanelLoader {
        id: launcherLoader
        requested: SurfaceController.launcherOpen

        LauncherPanel {
            open: launcherLoader.presented
        }
    }

    DeferredPanelLoader {
        id: clipboardLoader
        requested: SurfaceController.clipboardOpen

        ClipboardPanel {
            open: clipboardLoader.presented
        }
    }

    DeferredPanelLoader {
        id: settingsLoader
        requested: SurfaceController.settingsOpen

        SettingsPanel {
            open: settingsLoader.presented
        }
    }

    DeferredPanelLoader {
        id: wallpaperSwitcherLoader
        requested: SurfaceController.wallpaperSwitcherOpen

        WallpaperSwitcherPanel {
            open: wallpaperSwitcherLoader.presented
        }
    }

    NotificationOverlay {
        id: notificationOverlay
    }

    BluetoothPairingOverlay {
        id: bluetoothPairingOverlay
    }

    // IPC entry points must remain available while their heavier panels are
    // unloaded. Bar buttons call SurfaceController directly.
    IpcHandler {
        target: "launcher"

        function open(): void {
            SurfaceController.openLauncher(root.ipcFallbackScreen);
        }

        function close(): void {
            SurfaceController.closeLauncher();
        }

        function toggle(): void {
            SurfaceController.toggleLauncher(root.ipcFallbackScreen);
        }
    }

    IpcHandler {
        target: "clipboard"

        function open(): void {
            SurfaceController.openClipboard(root.ipcFallbackScreen);
        }

        function close(): void {
            SurfaceController.closeClipboard();
        }

        function toggle(): void {
            SurfaceController.toggleClipboard(root.ipcFallbackScreen);
        }

        function clear(): void {
            ClipboardService.clear();
        }
    }

    IpcHandler {
        target: "settings"

        function open(): void {
            SurfaceController.openSettings(root.ipcFallbackScreen);
        }

        function close(): void {
            SurfaceController.closeSettings();
        }

        function toggle(): void {
            SurfaceController.toggleSettings(root.ipcFallbackScreen);
        }
    }

    IpcHandler {
        target: "wallpaper"

        function open(): void {
            SurfaceController.openWallpaperSwitcher(root.ipcFallbackScreen);
        }

        function close(): void {
            SurfaceController.closeWallpaperSwitcher();
        }

        function toggle(): void {
            SurfaceController.toggleWallpaperSwitcher(root.ipcFallbackScreen);
        }
    }
}
