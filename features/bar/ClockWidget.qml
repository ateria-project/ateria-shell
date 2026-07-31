import QtQuick
import Quickshell
import qs.components
import qs.theme

M3Text {
    text: Qt.formatDateTime(clock.date, "dddd, d MMMM   •   h:mm AP")
    color: Theme.scheme.onSurfaceVariant
    font.pixelSize: 14
    font.weight: Font.DemiBold

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
