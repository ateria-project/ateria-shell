import QtQuick
import QtQuick.Controls
import qs.components
import qs.theme
import "WorkspaceLayout.js" as WorkspaceLayout

Rectangle {
    id: root

    property var view: null
    property bool showWorkspaceNumbersOnHover: true
    property bool alwaysShowWorkspaceNumbers: false
    readonly property int cellWidth: WorkspaceLayout.workspaceWidth
    readonly property int barHeight: WorkspaceLayout.barHeight
    readonly property int indicatorSize: 28
    readonly property var items: root.view?.visibleWorkspaces ?? []
    readonly property int activePosition: Number(root.view?.activeWorkspacePosition ?? -1)
    readonly property var activeItem: root.activePosition >= 0 && root.activePosition < root.items.length ? root.items[root.activePosition] : null
    readonly property bool showWorkspaceNumbers: root.alwaysShowWorkspaceNumbers
        || (root.showWorkspaceNumbersOnHover && workspaceHover.hovered)

    signal workspaceRequested(int workspaceIndex)

    visible: root.items.length > 0
    implicitWidth: root.items.length * root.cellWidth
    implicitHeight: root.barHeight
    radius: Metrics.radiusFull
    color: Theme.scheme.surfaceContainer

    HoverHandler {
        id: workspaceHover
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.items.length

            delegate: Item {
                id: occupiedCell

                required property int index
                readonly property var workspaceData: root.items[index] ?? null
                readonly property bool occupied: Boolean(workspaceData?.active) || Boolean(workspaceData?.occupied)
                readonly property bool previousOccupied: index > 0
                    && (Boolean(root.items[index - 1].active) || Boolean(root.items[index - 1].occupied))
                readonly property bool nextOccupied: index + 1 < root.items.length
                    && (Boolean(root.items[index + 1].active) || Boolean(root.items[index + 1].occupied))

                width: root.cellWidth
                height: root.barHeight

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: occupiedCell.occupied
                        ? (occupiedCell.previousOccupied ? -root.cellWidth / 2 : 0)
                        : root.cellWidth / 2
                    width: occupiedCell.occupied
                        ? root.cellWidth * (1 + (occupiedCell.previousOccupied ? 0.5 : 0) + (occupiedCell.nextOccupied ? 0.5 : 0))
                        : 0
                    height: root.indicatorSize
                    radius: Metrics.radiusFull
                    color: Theme.scheme.surfaceContainerHigh
                    opacity: occupiedCell.occupied ? 1 : 0

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
                    Behavior on opacity {
                        NumberAnimation { duration: 140 }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Motion.durationMedium }
                    }
                }
            }
        }
    }

    ExpressiveIndicator {
        id: activeIndicator

        readonly property bool urgent: root.activeItem !== null && Boolean(root.activeItem.urgent)

        visible: root.activePosition >= 0
        targetPosition: Math.max(0, root.activePosition) * root.cellWidth + (root.cellWidth - root.indicatorSize) / 2
        targetExtent: root.indicatorSize
        crossPosition: (root.height - root.indicatorSize) / 2
        crossExtent: root.indicatorSize
        motionEnabled: root.activePosition >= 0
        z: 1

        Rectangle {
            anchors.fill: parent
            radius: Metrics.radiusFull
            color: activeIndicator.urgent ? Theme.scheme.error : Theme.scheme.primary

            Behavior on color {
                ColorAnimation { duration: Motion.durationShort }
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        z: 2

        Repeater {
            model: root.items.length

            delegate: AbstractButton {
                id: control

                required property int index
                readonly property var workspaceData: root.items[index] ?? null
                readonly property bool active: Boolean(control.workspaceData?.active)
                readonly property bool occupied: Boolean(control.workspaceData?.occupied)
                readonly property bool urgent: Boolean(control.workspaceData?.urgent)
                readonly property int workspaceIndex: Number(control.workspaceData?.index ?? 0)

                focusPolicy: Qt.StrongFocus
                hoverEnabled: true
                implicitWidth: root.cellWidth
                implicitHeight: root.barHeight
                scale: control.down ? 0.82 : 1
                onClicked: root.workspaceRequested(control.workspaceIndex)

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                // The extra Item wrapper was unnecessary.
                background: Rectangle {
                    radius: Metrics.radiusFull
                    color: Theme.scheme.onSurface
                    opacity: control.hovered && !control.active ? 0.08 : control.visualFocus ? 0.14 : 0
                }

                contentItem: Item {
                    M3Text {
                        id: numberText

                        anchors.centerIn: parent
                        text: String(control.workspaceIndex)
                        color: control.active ? (control.urgent ? Theme.scheme.onError : Theme.scheme.onPrimary) : (control.urgent ? Theme.scheme.error : Theme.scheme.onSurfaceVariant)
                        opacity: control.active ? 1 : (root.showWorkspaceNumbers ? (control.occupied ? 0.85 : 0.6) : 0)
                        visible: opacity > 0
                        scale: control.active || root.showWorkspaceNumbers ? 1 : 0.72
                        font.family: Typography.monoFamily
                        font.pixelSize: 14
                        font.weight: Font.Medium

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 140
                                easing.type: Motion.easingStandard
                                easing.bezierCurve: Motion.standardCurve
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Motion.durationMedium
                                easing.type: Motion.easingEmphasizedDecelerate
                                easing.bezierCurve: Motion.emphasizedDecelerateCurve
                            }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 140 }
                        }
                    }

                    Rectangle {
                        id: indicatorDot

                        anchors.centerIn: parent
                        width: 5
                        height: width
                        radius: width / 2
                        color: control.urgent ? Theme.scheme.error : Theme.scheme.onSurfaceVariant
                        opacity: !control.active && !root.showWorkspaceNumbers ? (control.occupied ? 0.85 : 0.55) : 0
                        visible: opacity > 0
                        scale: !control.active && !root.showWorkspaceNumbers ? 1 : 0.55

                        Behavior on color {
                            ColorAnimation {
                                duration: Motion.durationShort
                            }
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
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Motion.durationMedium
        }
    }
}
