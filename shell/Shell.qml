import QtQuick
import Quickshell
import qs.features.bar
import qs.features.calendar
import qs.features.quicksettings
import qs.shell

Scope {
    id: root

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
