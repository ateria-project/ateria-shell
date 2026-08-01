import QtQuick
import Quickshell
import qs.features.bar
import qs.features.calendar
import qs.features.quicksettings
import qs.features.wallpaper
import qs.platform.settings
import qs.shell

Scope {
    id: root

    Component.onCompleted: SettingsBootstrap.initialize()

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

    QuickSettingsPanel {
        id: quickSettingsPanel

        screen: SurfaceController.activeScreen
    }

    CalendarPanel {
        id: calendarPanel

        screen: SurfaceController.activeScreen
    }
}
