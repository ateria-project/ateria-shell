import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs.components
import qs.features.calendar.components
import qs.shell
import qs.theme

TransientPanelWindow {
    id: root

    property date today: new Date()
    property bool autoUpdateToday: true
    property date selectedDate: new Date(today.getFullYear(), today.getMonth(), today.getDate())
    property date displayedMonth: new Date(today.getFullYear(), today.getMonth(), 1)
    property var eventDates: []

    signal settingsRequested()
    signal dateActivated(date value)

    function sameMonth(a, b) {
        return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth();
    }

    function canonicalMonth(value) {
        return new Date(value.getFullYear(), value.getMonth(), 1);
    }

    function navigateMonth(delta) {
        const base = root.canonicalMonth(root.displayedMonth);
        root.displayedMonth = new Date(base.getFullYear(), base.getMonth() + delta, 1);
    }

    function navigateToMonth(value) {
        root.displayedMonth = root.canonicalMonth(value);
    }

    function goToday() {
        const value = new Date(root.today.getFullYear(), root.today.getMonth(), root.today.getDate());
        root.selectedDate = value;
        root.navigateToMonth(value);
        root.dateActivated(value);
    }

    open: SurfaceController.calendarOpen
    targetScreen: SurfaceController.calendarScreen
    transitionsEnabled: true
    implicitWidth: 370
    implicitHeight: mainLayout.implicitHeight + 28
    color: "transparent"
    WlrLayershell.exclusiveZone: 0
    onFullyOpened: root.today = new Date()
    onTransitionRequested: (entering, generation) => panelTransition.transition(entering, generation)

    // Keep the input surface full-screen while open so clicks outside the
    // panel can dismiss it.
    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    DismissibleOverlay {
        excludedItem: panelSurface.presentationItem
        enabled: root.interactive
        onDismissed: SurfaceController.closeCalendar()
    }

    Timer {
        interval: 3600000
        repeat: true
        running: root.autoUpdateToday && root.mounted
        onTriggered: root.today = new Date()
    }

    M3Surface {
        id: panelSurface

        width: root.implicitWidth
        height: root.implicitHeight
        radius: 16
        color: Theme.scheme.surfaceContainer

        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 6
        }

        ColumnLayout {
            id: mainLayout

            spacing: 12

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 6
                rightMargin: 6
                topMargin: 14
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 12
                Layout.bottomMargin: 12
                spacing: 8

                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6

                    M3Text {
                        text: Qt.formatDate(root.displayedMonth, "MMMM")
                        font.pixelSize: 18
                        font.weight: Font.Normal
                    }

                    M3Text {
                        text: Qt.formatDate(root.displayedMonth, "yyyy")
                        font.pixelSize: 18
                        font.weight: Font.Normal
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                M3Button {
                    style: M3Button.Text
                    iconName: "today"
                    iconSize: 20
                    implicitWidth: 36
                    implicitHeight: 36
                    enabled: !root.sameMonth(root.today, root.displayedMonth) || root.selectedDate.getDate() !== root.today.getDate() || root.selectedDate.getMonth() !== root.today.getMonth() || root.selectedDate.getFullYear() !== root.today.getFullYear()
                    contentColor: root.sameMonth(root.today, root.displayedMonth) ? Theme.scheme.onSurfaceVariant : Theme.scheme.onSurface
                    Accessible.name: "Go to today"
                    onClicked: root.goToday()
                }

                M3Button {
                    style: M3Button.Text
                    iconName: "expand_less"
                    iconSize: 20
                    implicitWidth: 36
                    implicitHeight: 36
                    contentColor: Theme.scheme.onSurface
                    Accessible.name: "Previous month"
                    onClicked: root.navigateMonth(-1)
                }

                M3Button {
                    style: M3Button.Text
                    iconName: "expand_more"
                    iconSize: 20
                    implicitWidth: 36
                    implicitHeight: 36
                    contentColor: Theme.scheme.onSurface
                    Accessible.name: "Next month"
                    onClicked: root.navigateMonth(1)
                }
            }

            Row {
                Layout.fillWidth: true
                height: 20

                Repeater {
                    model: ["S", "M", "T", "W", "T", "F", "S"]

                    delegate: Item {
                        width: parent.width / 7
                        height: 20

                        M3Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 240

                CalendarMonth {
                    anchors.fill: parent
                    monthDate: root.displayedMonth
                    selectedDate: root.selectedDate
                    today: root.today
                    eventDates: root.eventDates
                    onDateClicked: function(value) {
                        root.selectedDate = value;
                        root.dateActivated(value);
                        if (!root.sameMonth(value, root.displayedMonth))
                            root.navigateToMonth(value);
                    }
                }
            }
        }
    }

    SlideTransition {
        id: panelTransition

        target: panelSurface.presentationItem
        hiddenOffsetY: -(panelSurface.height + panelSurface.anchors.topMargin + 5)
        onTransitionFinished: generation => root.completeTransition(generation)
    }
}
