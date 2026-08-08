import QtQuick
import Quickshell
import qs.theme
import "WorkspaceLayout.js" as WorkspaceLayout
import "components"

Rectangle {
    id: root

    property var view: null
    property bool useAppIcons: true
    readonly property var items: root.view?.visibleWindows ?? []
    readonly property var activeWindowId: root.view?.activeWindowId ?? null
    readonly property int activePosition: Number(root.view?.activeVisibleWindowPosition ?? -1)
    readonly property var activeItem: root.activePosition >= 0 && root.activePosition < root.items.length ? root.items[root.activePosition] : null
    readonly property int cellWidth: WorkspaceLayout.windowWidth
    readonly property int barHeight: WorkspaceLayout.barHeight
    property int desktopEntriesRevision: 0

    signal windowRequested(double windowId)

    visible: root.items.length > 0
    implicitWidth: root.items.length * root.cellWidth
    implicitHeight: root.barHeight
    radius: Metrics.radiusSm
    color: Theme.scheme.surfaceContainer

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            // Make bindings retry after Quickshell finishes its asynchronous desktop-entry scan.
            root.desktopEntriesRevision += 1;
        }
    }

    ExpressiveIndicator {
        id: activeIndicator

        readonly property bool urgent: root.activeItem !== null && Boolean(root.activeItem.urgent)

        visible: root.activePosition >= 0
        targetX: Math.max(0, root.activePosition) * root.cellWidth
            + (root.cellWidth - WorkspaceLayout.activeIndicatorWidth) / 2
        targetWidth: WorkspaceLayout.activeIndicatorWidth
        motionEnabled: root.activePosition >= 0
        anchors.verticalCenter: parent.verticalCenter
        height: root.barHeight
        z: 1

        Rectangle {
            anchors.fill: parent
            radius: Metrics.radiusSm
            color: activeIndicator.urgent ? Theme.scheme.errorContainer : root.useAppIcons ? Theme.scheme.surfaceContainerHighest : Theme.scheme.secondaryContainer

            Behavior on color {
                ColorAnimation { duration: Motion.durationShort }
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        z: 2

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 140
                easing.type: Motion.easingStandardDecelerate
                easing.bezierCurve: Motion.standardDecelerateCurve
            }
        }

        Repeater {
            model: root.items.length

            delegate: WindowButton {
                id: control

                required property int index
                windowData: root.items[index] ?? null
                cellWidth: root.cellWidth
                cellHeight: root.barHeight
                indicatorWidth: WorkspaceLayout.activeIndicatorWidth
                active: root.activeWindowId !== null && control.windowId === Number(root.activeWindowId)
                useAppIcons: root.useAppIcons
                desktopEntriesRevision: root.desktopEntriesRevision
                onClicked: root.windowRequested(control.windowId)
            }
        }
    }
}
