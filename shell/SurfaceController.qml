pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    enum Surface {
        None = 0,
        QuickSettings = 1,
        Calendar = 2,
        NotificationPanel = 3,
        Launcher = 4,
        Clipboard = 5
    }

    property int activeSurface: SurfaceController.None
    property var activeScreen: null
    // A surface keeps its own screen assignment. Changing the active surface
    // must not move a still-mounted outgoing surface to the incoming screen.
    property var quickSettingsScreen: null
    property var calendarScreen: null
    property var notificationPanelScreen: null
    property var launcherScreen: null
    property var clipboardScreen: null
    readonly property bool quickSettingsOpen: root.activeSurface === SurfaceController.QuickSettings
    readonly property bool calendarOpen: root.activeSurface === SurfaceController.Calendar
    readonly property bool notificationPanelOpen: root.activeSurface === SurfaceController.NotificationPanel
    readonly property bool launcherOpen: root.activeSurface === SurfaceController.Launcher
    readonly property bool clipboardOpen: root.activeSurface === SurfaceController.Clipboard

    function preferredScreen(outputName: string): var {
        const screens = Quickshell.screens;
        const matchingScreen = screens.find(screen => screen.name === outputName);
        return matchingScreen ?? root.activeScreen ?? (screens.length > 0 ? screens[0] : null);
    }

    function openSurface(surface: int, screen) {
        const requestedScreen = screen ?? null;
        switch (surface) {
        case SurfaceController.QuickSettings:
            root.quickSettingsScreen = requestedScreen;
            break;
        case SurfaceController.Calendar:
            root.calendarScreen = requestedScreen;
            break;
        case SurfaceController.NotificationPanel:
            root.notificationPanelScreen = requestedScreen;
            break;
        case SurfaceController.Launcher:
            root.launcherScreen = requestedScreen;
            break;
        case SurfaceController.Clipboard:
            root.clipboardScreen = requestedScreen;
            break;
        }
        root.activeScreen = requestedScreen;
        root.activeSurface = surface;
    }

    function closeSurface() {
        root.activeSurface = SurfaceController.None;
    }

    function toggleSurface(surface: int, screen) {
        if (root.activeSurface === surface && root.activeScreen === screen)
            root.closeSurface();
        else
            root.openSurface(surface, screen);
    }

    function toggleQuickSettings(screen) {
        root.toggleSurface(SurfaceController.QuickSettings, screen);
    }

    function openQuickSettings(screen) {
        root.openSurface(SurfaceController.QuickSettings, screen);
    }

    function closeQuickSettings() {
        if (root.quickSettingsOpen)
            root.closeSurface();
    }
    function toggleCalendar(screen) {
        root.toggleSurface(SurfaceController.Calendar, screen);
    }

    function openCalendar(screen) {
        root.openSurface(SurfaceController.Calendar, screen);
    }

    function closeCalendar() {
        if (root.calendarOpen)
            root.closeSurface();
    }
    function toggleNotificationPanel(screen) {
        root.toggleSurface(SurfaceController.NotificationPanel, screen);
    }

    function openNotificationPanel(screen) {
        root.openSurface(SurfaceController.NotificationPanel, screen);
    }

    function closeNotificationPanel() {
        if (root.notificationPanelOpen)
            root.closeSurface();
    }
    function toggleLauncher(screen) {
        root.toggleSurface(SurfaceController.Launcher, screen);
    }

    function openLauncher(screen) {
        root.openSurface(SurfaceController.Launcher, screen);
    }

    function closeLauncher() {
        if (root.launcherOpen)
            root.closeSurface();
    }
    function toggleClipboard(screen) {
        root.toggleSurface(SurfaceController.Clipboard, screen);
    }

    function openClipboard(screen) {
        root.openSurface(SurfaceController.Clipboard, screen);
    }

    function closeClipboard() {
        if (root.clipboardOpen)
            root.closeSurface();
    }
}
