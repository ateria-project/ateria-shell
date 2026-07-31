pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    enum Surface {
        None = 0,
        QuickSettings = 1
    }

    property int activeSurface: SurfaceController.Surface.None
    property var activeScreen: null
    readonly property bool quickSettingsOpen: root.activeSurface === SurfaceController.Surface.QuickSettings
    readonly property bool notificationsOpen: root.activeSurface === SurfaceController.Surface.Notifications
    readonly property bool launcherOpen: root.activeSurface === SurfaceController.Surface.Launcher
    readonly property bool powerMenuOpen: root.activeSurface === SurfaceController.Surface.PowerMenu

    function openSurface(surface: int, screen) {
        root.activeScreen = screen ?? null;
        root.activeSurface = surface;
    }

    function closeSurface() {
        root.activeSurface = SurfaceController.Surface.None;
    }

    function toggleSurface(surface: int, screen) {
        if (root.activeSurface === surface && root.activeScreen === screen)
            root.closeSurface();
        else
            root.openSurface(surface, screen);
    }

    // Start quick settings
    function toggleQuickSettings(screen) {
        root.toggleSurface(SurfaceController.Surface.QuickSettings, screen);
    }

    function openQuickSettings(screen) {
        root.openSurface(SurfaceController.Surface.QuickSettings, screen);
    }

    function closeQuickSettings() {
        if (root.quickSettingsOpen)
            root.closeSurface();
    }
    // End quick settings
}
