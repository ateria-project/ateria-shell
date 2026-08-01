import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.features.calendar.components
import qs.shell
import qs.theme

PanelWindow {
    id: root

    property bool open: SurfaceController.calendarOpen

    property date today: new Date()
    property bool autoUpdateToday: true
    property date selectedDate: new Date(today.getFullYear(), today.getMonth(), today.getDate())
    property date displayedMonth: new Date(today.getFullYear(), today.getMonth(), 1)
    property var eventDates: []

    signal settingsRequested
    signal dateActivated(date value)

    property date _shownMonth: new Date(displayedMonth.getFullYear(), displayedMonth.getMonth(), 1)
    property date _targetMonth: _shownMonth
    property bool _changingDisplayedMonth: false

    screen: SurfaceController.activeScreen

    anchors {
        top: true
    }
    margins {
        top: 6
    }

    implicitWidth: 380
    implicitHeight: mainLayout.implicitHeight + 28
    color: "transparent"
    WlrLayershell.exclusiveZone: 0
    visible: open

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 150
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 150
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
        }
    }

    function sameMonth(a, b) {
        return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth();
    }

    function canonicalMonth(value) {
        return new Date(value.getFullYear(), value.getMonth(), 1);
    }

    function navigateMonth(delta) {
        var base = _targetMonth;
        var target = new Date(base.getFullYear(), base.getMonth() + delta, 1);
        navigateToMonth(target);
    }

    function navigateToMonth(value) {
        var target = canonicalMonth(value);
        if (sameMonth(target, _shownMonth) && !monthTransition.running) {
            displayedMonth = target;
            return;
        }

        if (monthTransition.running) {
            monthTransition.stop();
            _shownMonth = _targetMonth;
            currentMonth.x = 0;
            currentMonth.y = 0;
            currentMonth.opacity = 1.0;
            incomingMonth.x = 0;
            incomingMonth.y = 0;
            incomingMonth.opacity = 0.0;
        }

        var direction = target.getTime() > _shownMonth.getTime() ? 1 : -1;
        _targetMonth = target;
        _changingDisplayedMonth = true;
        displayedMonth = target;
        _changingDisplayedMonth = false;

        incomingMonth.monthDate = target;
        incomingMonth.y = direction > 0 ? 30 : -30;
        incomingMonth.opacity = 0.0;

        outgoingY.to = direction > 0 ? -30 : 30;
        incomingY.from = incomingMonth.y;
        incomingY.to = 0;
        monthTransition.restart();
    }

    function goToday() {
        var value = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        selectedDate = value;
        navigateToMonth(value);
        dateActivated(value);
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.autoUpdateToday
        onTriggered: root.today = new Date()
    }

    onDisplayedMonthChanged: {
        if (!_changingDisplayedMonth && !monthTransition.running && !sameMonth(displayedMonth, _shownMonth)) {
            _shownMonth = canonicalMonth(displayedMonth);
        }
    }

    M3Panel {
        id: panelSurface
        anchors.fill: parent
        radius: 16
        color: Theme.scheme.surfaceContainer

        ColumnLayout {
            id: mainLayout
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 6
                rightMargin: 6
                topMargin: 14
            }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 12
                spacing: 8

                M3Text {
                    text: "Calendar"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }

                Item {
                    Layout.fillWidth: true
                }

                M3Button {
                    style: M3Button.Tonal
                    text: "Today"
                    implicitHeight: 32
                    containerColor: root.sameMonth(root.today, root.displayedMonth) ? Theme.scheme.surfaceContainerHighest : Theme.scheme.primaryContainer
                    contentColor: root.sameMonth(root.today, root.displayedMonth) ? Theme.scheme.onSurface : Theme.scheme.onPrimaryContainer
                    onClicked: root.goToday()
                }

                M3Button {
                    style: M3Button.Text
                    iconName: "settings"
                    iconSize: 20
                    implicitWidth: 36
                    implicitHeight: 36
                    containerColor: Theme.scheme.surfaceContainerHighest
                    contentColor: Theme.scheme.onSurface
                    Accessible.name: "Calendar settings"
                    onClicked: root.settingsRequested()
                }
            }

            Item {}

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 12
                spacing: 8

                M3Text {
                    id: monthTitle
                    text: Qt.formatDate(root.displayedMonth, "MMMM yyyy")
                    font.pixelSize: 18
                    font.weight: Font.Normal

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.34, 0.80, 0.34, 1.0, 1.0, 1.0]
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
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

            Item {}

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
                id: monthViewport
                Layout.fillWidth: true
                Layout.preferredHeight: 240
                clip: true

                CalendarMonth {
                    id: currentMonth
                    anchors.fill: parent
                    monthDate: root._shownMonth
                    selectedDate: root.selectedDate
                    today: root.today
                    eventDates: root.eventDates
                    onDateClicked: function (value) {
                        root.selectedDate = value;
                        root.dateActivated(value);
                        if (!root.sameMonth(value, root._shownMonth))
                            root.navigateToMonth(value);
                    }
                }

                CalendarMonth {
                    id: incomingMonth
                    anchors.fill: parent
                    opacity: 0.0
                    selectedDate: root.selectedDate
                    today: root.today
                    eventDates: root.eventDates
                    onDateClicked: function (value) {
                        root.selectedDate = value;
                        root.dateActivated(value);
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: monthTransition

        NumberAnimation {
            id: outgoingY
            target: currentMonth
            property: "y"
            duration: 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.27, 1.06, 0.18, 1.0, 1.0, 1.0]
        }
        NumberAnimation {
            target: currentMonth
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 160
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.34, 0.80, 0.34, 1.0, 1.0, 1.0]
        }
        NumberAnimation {
            id: incomingY
            target: incomingMonth
            property: "y"
            duration: 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.27, 1.06, 0.18, 1.0, 1.0, 1.0]
        }
        NumberAnimation {
            target: incomingMonth
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 160
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.34, 0.80, 0.34, 1.0, 1.0, 1.0]
        }

        onFinished: {
            root._shownMonth = root._targetMonth;
            currentMonth.x = 0;
            currentMonth.y = 0;
            currentMonth.opacity = 1.0;
            incomingMonth.x = 0;
            incomingMonth.y = 0;
            incomingMonth.opacity = 0.0;
        }
    }
}
