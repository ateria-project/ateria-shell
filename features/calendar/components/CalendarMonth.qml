import QtQuick
import QtQuick.Controls.Basic
import qs.components
import qs.theme

Item {
    id: root

    property date monthDate: new Date()
    property date selectedDate: new Date()
    property date today: new Date()
    property var eventDates: []

    signal dateClicked(date value)

    function sameDate(a, b) {
        return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    readonly property var daysModel: {
        const d = root.monthDate || new Date();
        const year = d.getFullYear();
        const month = d.getMonth();
        const firstDay = new Date(year, month, 1);
        const startDayOfWeek = firstDay.getDay(); // 0 (Sun) to 6 (Sat)
        const arr = [];
        for (let i = 0; i < 42; ++i) {
            arr.push(new Date(year, month, 1 - startDayOfWeek + i));
        }
        return arr;
    }

    Grid {
        anchors.fill: parent
        columns: 7
        rows: 6

        Repeater {
            model: root.daysModel
            delegate: AbstractButton {
                id: dayCell

                required property var modelData
                required property int index

                width: root.width / 7
                height: root.height / 6
                onClicked: root.dateClicked(dayCell.modelData)

                readonly property bool isToday: root.sameDate(dayCell.modelData, root.today)
                readonly property bool isSelected: root.sameDate(dayCell.modelData, root.selectedDate)
                readonly property bool isCurrentMonth: dayCell.modelData && dayCell.modelData.getMonth() === root.monthDate.getMonth()

                background: Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(32, dayCell.width - 4)
                    height: Math.min(36, dayCell.height - 4)
                    radius: width / 2
                    color: {
                        if (dayCell.isToday)
                            return dayCell.isCurrentMonth ? Theme.scheme.primaryContainer : "transparent";
                        if (dayCell.isSelected)
                            return Theme.scheme.surfaceContainerHighest;
                        if (dayCell.down)
                            return Theme.scheme.surfaceContainerHigh;
                        if (dayCell.hovered)
                            return Theme.scheme.surfaceContainer;
                        return "transparent";
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                contentItem: Item {
                    M3Text {
                        anchors.centerIn: parent
                        text: dayCell.modelData ? dayCell.modelData.getDate() : ""
                        font.pixelSize: 14
                        font.weight: dayCell.isToday || dayCell.isSelected ? Font.Medium : Font.Normal
                        opacity: dayCell.isCurrentMonth ? 1.0 : 0.28
                        color: {
                            if (dayCell.isToday)
                                return dayCell.isCurrentMonth ? Theme.scheme.onPrimaryContainer : Theme.scheme.onSurface;
                            if (!dayCell.isCurrentMonth)
                                return Theme.scheme.onSurfaceVariant;
                            return Theme.scheme.onSurface;
                        }
                    }
                }
            }
        }
    }
}
