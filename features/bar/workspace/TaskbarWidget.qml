import QtQuick
import QtQuick.Controls
import Quickshell
import qs.components
import qs.theme
import "WorkspaceLayout.js" as WorkspaceLayout
import "components"

Item {
    id: root

    property var view: null
    property var layoutData: null
    property bool useAppIcons: true
    property bool showWorkspaceNumbers: true
    readonly property var workspaces: root.view?.visibleWorkspaces ?? []
    readonly property var activeWindowId: root.view?.activeWindowId ?? null
    readonly property int workspaceWidth: WorkspaceLayout.workspaceWidth
    readonly property int windowWidth: WorkspaceLayout.windowWidth
    readonly property int barHeight: WorkspaceLayout.barHeight
    readonly property int activeIndicatorWidth: WorkspaceLayout.activeIndicatorWidth
    property int desktopEntriesRevision: 0
    readonly property var emptyWindows: []
    readonly property var windowsByWorkspace: root.view && root.view.windowsByWorkspace
        ? root.view.windowsByWorkspace
        : ({})
    readonly property var workspaceLayouts: root.layoutData && root.layoutData.workspaceLayouts
        ? root.layoutData.workspaceLayouts
        : []
    readonly property double normalizedActiveWindowId: root.activeWindowId === null
        || root.activeWindowId === undefined ? 0 : Number(root.activeWindowId)
    readonly property var activeWindowLayout: root.layoutData?.activeWindowLayout ?? null

    signal workspaceRequested(int workspaceIndex)
    signal windowRequested(double windowId)

    function windowsForWorkspace(workspaceId) {
        if (workspaceId < 1)
            return root.emptyWindows;

        return root.windowsByWorkspace[String(workspaceId)] ?? root.emptyWindows;
    }

    visible: (root.workspaces ?? []).length > 0
    implicitHeight: root.barHeight
    implicitWidth: root.layoutData ? root.layoutData.totalWidth : contentRow.implicitWidth

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            ++root.desktopEntriesRevision;
        }
    }

    // Layer 1: workspace rails
    Repeater {
        model: root.workspaceLayouts.length

        delegate: Rectangle {
            required property int index
            readonly property var layoutInfo: root.workspaceLayouts[index] ?? null

            x: layoutInfo?.x ?? 0
            anchors.verticalCenter: parent.verticalCenter
            width: layoutInfo?.width ?? 0
            height: root.barHeight
            radius: Metrics.radiusFull
            color: Theme.scheme.surfaceContainer

            Behavior on x {
                NumberAnimation {
                    duration: Motion.durationMedium
                    easing.type: Motion.easingEmphasizedDecelerate
                    easing.bezierCurve: Motion.emphasizedDecelerateCurve
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: Motion.durationMedium
                    easing.type: Motion.easingEmphasized
                    easing.bezierCurve: Motion.emphasizedCurve
                }
            }
        }
    }

    // Layer 2: active-window indicator
    ExpressiveIndicator {
        id: activeWindowIndicator

        visible: root.activeWindowLayout !== null
        targetPosition: root.activeWindowLayout?.x ?? 0
        targetExtent: root.activeIndicatorWidth
        crossPosition: 0
        crossExtent: root.barHeight
        motionEnabled: root.activeWindowLayout !== null
        z: 1

        Rectangle {
            anchors.fill: parent
            radius: Metrics.radiusSm
            color: Boolean(root.activeWindowLayout?.windowData?.urgent)
                ? Theme.scheme.errorContainer
                : (root.useAppIcons ? Theme.scheme.surfaceContainerHighest : Theme.scheme.secondaryContainer)

            Behavior on color {
                ColorAnimation { duration: Motion.durationShort }
            }
        }
    }

    // Layer 3: interactive content
    Row {
        id: contentRow

        spacing: Metrics.spacingSm
        z: 2

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Motion.durationMedium
                easing.type: Motion.easingEmphasizedDecelerate
                easing.bezierCurve: Motion.emphasizedDecelerateCurve
            }
        }

        Repeater {
            model: (root.workspaces ?? []).length

            delegate: Item {
                id: workspaceRow

                required property int index
                readonly property var workspaceData: (root.workspaces ?? [])[index] ?? null
                readonly property bool active: Boolean(workspaceData?.active)
                readonly property bool occupied: Boolean(workspaceData?.occupied)
                readonly property bool urgent: Boolean(workspaceData?.urgent)
                readonly property int workspaceIndex: Number(workspaceData?.index ?? 0)
                readonly property int workspaceId: Number(workspaceData?.id ?? 0)
                readonly property var workspaceWindows: root.windowsForWorkspace(workspaceId)
                readonly property int windowCount: workspaceRow.workspaceWindows.length
                readonly property bool pillVisible: root.showWorkspaceNumbers || workspaceRow.windowCount === 0

                implicitWidth: workspaceContent.implicitWidth
                implicitHeight: root.barHeight

                Row {
                    id: workspaceContent

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Metrics.spacingXs

                    // Workspace button
                    AbstractButton {
                        id: workspaceControl

                        visible: workspaceRow.pillVisible
                        Accessible.name: qsTr("Workspace %1").arg(workspaceRow.workspaceIndex)
                        focusPolicy: Qt.StrongFocus
                        hoverEnabled: true
                        implicitWidth: root.workspaceWidth
                        implicitHeight: root.barHeight
                        scale: down ? 0.82 : 1
                        onClicked: root.workspaceRequested(workspaceRow.workspaceIndex)

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }

                        background: Item {
                            Rectangle {
                                anchors.fill: parent
                                radius: Metrics.radiusFull
                                color: workspaceRow.active ? Theme.scheme.primary : (workspaceRow.occupied ? Theme.scheme.surfaceContainerHigh : "transparent")

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Motion.durationShort
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Metrics.radiusFull
                                color: Theme.scheme.onSurface
                                opacity: !workspaceRow.active && workspaceControl.hovered ? 0.08 : (!workspaceRow.active && workspaceControl.visualFocus ? 0.14 : 0)

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Motion.durationShort
                                    }
                                }
                            }
                        }

                        contentItem: Item {
                            M3Text {
                                id: workspaceLabel

                                anchors.centerIn: parent
                                text: String(workspaceRow.workspaceIndex)
                                color: workspaceRow.active ? (workspaceRow.urgent ? Theme.scheme.onError : Theme.scheme.onPrimary) : (workspaceRow.urgent ? Theme.scheme.error : Theme.scheme.onSurfaceVariant)
                                opacity: workspaceRow.active ? 1 : (workspaceRow.occupied ? 0.85 : 0.6)
                                scale: workspaceRow.active ? 1 : 0.82
                                font.family: Typography.monoFamily
                                font.pixelSize: 14
                                font.weight: Font.Medium

                                Behavior on color {
                                    ColorAnimation { duration: 140 }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: 140 }
                                }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Motion.durationMedium
                                        easing.type: Motion.easingEmphasizedDecelerate
                                        easing.bezierCurve: Motion.emphasizedDecelerateCurve
                                    }
                                }
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Motion.durationShort
                                easing.type: Motion.easingStandard
                                easing.bezierCurve: Motion.standardCurve
                            }
                        }
                    }

                    // Windows for this workspace. Hiding an empty row prevents
                    // spacing after an unoccupied workspace.
                    Row {
                        id: windowsRow

                        visible: workspaceRow.workspaceWindows.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

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
                            model: workspaceRow.workspaceWindows.length

                            delegate: WindowButton {
                                id: windowControl

                                required property int index
                                windowData: workspaceRow.workspaceWindows[index] ?? null
                                cellWidth: root.windowWidth
                                cellHeight: root.barHeight
                                indicatorWidth: root.activeIndicatorWidth
                                active: root.normalizedActiveWindowId > 0
                                    && windowControl.windowId === root.normalizedActiveWindowId
                                useAppIcons: root.useAppIcons
                                desktopEntriesRevision: root.desktopEntriesRevision
                                onClicked: root.windowRequested(windowControl.windowId)
                            }
                        }
                    }
                }
            }
        }
    }
}
