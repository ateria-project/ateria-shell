pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    enum Surface {
        None = 0,
        QuickSettings = 1,
        Calendar = 2
    }

    property int activeSurface: 0
    property var activeScreen: null
    readonly property bool quickSettingsOpen: root.activeSurface === 1
    readonly property bool calendarOpen: root.activeSurface === 2

    function openSurface(surface: int, screen) {
        root.activeScreen = screen ?? null;
        root.activeSurface = surface;
    }

    function closeSurface() {
        root.activeSurface = 0;
    }

    function toggleSurface(surface: int, screen) {
        if (root.activeSurface === surface && root.activeScreen === screen)
            root.closeSurface();
        else
            root.openSurface(surface, screen);
    }

    // Start quick settings
    function toggleQuickSettings(screen) {
        root.toggleSurface(1, screen);
    }

    function openQuickSettings(screen) {
        root.openSurface(1, screen);
    }

    function closeQuickSettings() {
        if (root.quickSettingsOpen)
            root.closeSurface();
    }
    // End quick settings

    // Start calendar
    function toggleCalendar(screen) {
        root.toggleSurface(2, screen);
    }

    function openCalendar(screen) {
        root.openSurface(2, screen);
    }

    function closeCalendar() {
        if (root.calendarOpen)
            root.closeSurface();
    }
    // End calendar
}
