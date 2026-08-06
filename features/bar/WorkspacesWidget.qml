import QtQuick
import QtQuick.Controls
import Quickshell
import qs.components
import qs.theme

Rectangle {
    id: root

    property var workspaces: null
    readonly property int cellWidth: 30
    readonly property int barHeight: 28
    readonly property int indicatorSize: 28
    readonly property var items: root.workspaces ?? []
    readonly property var workspaceLayout: {
        const source = root.items;
        const runs = [];
        let activePosition = -1;
        let runStart = -1;
        for (let index = 0; index < source.length; ++index) {
            const workspace = source[index];
            const active = Boolean(workspace.active);
            const occupied = active || Boolean(workspace.occupied);
            if (activePosition < 0 && active)
                activePosition = index;

            if (occupied) {
                if (runStart < 0)
                    runStart = index;
            } else if (runStart >= 0) {
                runs.push({
                    "start": runStart,
                    "length": index - runStart
                });
                runStart = -1;
            }
        }
        if (runStart >= 0)
            runs.push({
                "start": runStart,
                "length": source.length - runStart
            });

        return {
            "activePosition": activePosition,
            "occupiedRuns": runs
        };
    }
    readonly property int activePosition: root.workspaceLayout.activePosition
    readonly property var occupiedRuns: root.workspaceLayout.occupiedRuns
    readonly property bool showWorkspaceNumbers: workspaceHover.hovered

    signal workspaceRequested(int workspaceIndex)

    visible: root.items.length > 0
    implicitWidth: root.visible ? root.items.length * root.cellWidth : 0
    implicitHeight: root.barHeight
    radius: Metrics.radiusFull
    color: Theme.scheme.surfaceContainer

    HoverHandler {
        id: workspaceHover
    }

    Repeater {
        model: root.occupiedRuns

        delegate: Rectangle {
            required property var modelData

            x: modelData.start * root.cellWidth
            anchors.verticalCenter: parent.verticalCenter
            width: modelData.length * root.cellWidth
            height: root.indicatorSize
            radius: Metrics.radiusFull
            color: Theme.scheme.surfaceContainerHigh

            Behavior on x {
                NumberAnimation {
                    duration: Motion.durationMedium
                    easing.type: Motion.easingStandard
                    easing.bezierCurve: Motion.standardCurve
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: Motion.durationMedium
                    easing.type: Motion.easingStandard
                    easing.bezierCurve: Motion.standardCurve
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Motion.durationMedium
                }
            }
        }
    }

    Rectangle {
        id: activeIndicator

        readonly property bool urgent: root.activePosition >= 0 && Boolean(root.items[root.activePosition].urgent)

        visible: root.activePosition >= 0
        x: root.activePosition * root.cellWidth + (root.cellWidth - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.indicatorSize
        height: width
        radius: Metrics.radiusFull
        color: activeIndicator.urgent ? Theme.scheme.error : Theme.scheme.primary

        Behavior on x {
            NumberAnimation {
                duration: Motion.durationLong
                easing.type: Motion.easingEmphasized
                easing.bezierCurve: Motion.emphasizedCurve
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Motion.durationShort
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        z: 1

        Repeater {
            model: root.items

            delegate: AbstractButton {
                id: control

                required property var modelData
                readonly property bool active: Boolean(control.modelData.active)
                readonly property bool occupied: Boolean(control.modelData.occupied)
                readonly property bool urgent: Boolean(control.modelData.urgent)
                readonly property int workspaceIndex: Number(control.modelData.index)

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
                        opacity: control.active ? 1.0 : (root.showWorkspaceNumbers ? (control.occupied ? 0.85 : 0.6) : 0.0)
                        visible: opacity > 0
                        font.family: Typography.monoFamily
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                    Rectangle {
                        id: indicatorDot

                        anchors.centerIn: parent
                        width: 5
                        height: width
                        radius: width / 2
                        color: control.urgent ? Theme.scheme.error : Theme.scheme.onSurfaceVariant
                        opacity: !control.active && !root.showWorkspaceNumbers ? (control.occupied ? 0.85 : 0.55) : 0.0
                        visible: opacity > 0

                        Behavior on color {
                            ColorAnimation {
                                duration: Motion.durationShort
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
