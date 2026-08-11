pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell.Services.SystemTray
import qs.components
import qs.theme
import "components"

Rectangle {
    id: root

    required property bool expanded

    signal expandedRequested(bool expanded)

    readonly property int toggleWidth: 28
    readonly property int leadingPadding: 6
    readonly property bool hasItems: trayRepeater.count > 0
    readonly property real expandedWidth: root.toggleWidth + Metrics.spacingXs + trayContent.implicitWidth

    function toggleItemMenu(item): void {
        trayMenu.toggleMenu(item.menu);
    }

    function closeMenu(): void {
        trayMenu.closeMenu();
    }

    function pointHitsTrayIcon(scenePoint): bool {
        if (!root.expanded)
            return false;

        const point = trayItems.mapFromItem(null, scenePoint.x, scenePoint.y);
        return point.x >= 0
            && point.y >= 0
            && point.x < trayItems.width
            && point.y < trayItems.height;
    }

    implicitWidth: root.hasItems ? (root.expanded ? root.expandedWidth : root.toggleWidth) : 0
    implicitHeight: 28
    width: root.implicitWidth
    visible: root.hasItems || trayWidthAnimation.running
    radius: Metrics.radiusFull
    color: Theme.scheme.surfaceContainer
    clip: true

    onExpandedChanged: {
        if (!root.expanded)
            root.closeMenu();
    }
    onHasItemsChanged: {
        if (!root.hasItems)
            root.closeMenu();
    }

    Row {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        spacing: Metrics.spacingXs

        Item {
            id: trayContent

            implicitWidth: root.leadingPadding + trayItems.implicitWidth
            implicitHeight: root.implicitHeight
            enabled: root.expanded
            opacity: root.expanded ? 1 : 0
            scale: root.expanded ? 1 : 0.72
            transformOrigin: Item.Right
            layer.enabled: true
            layer.smooth: true

            Row {
                id: trayItems

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 4

                Repeater {
                    id: trayRepeater

                    model: SystemTray.items

                    delegate: TrayIconButton {
                        required property var modelData

                        item: modelData
                        onMenuRequested: trayItem => root.toggleItemMenu(trayItem)
                    }
                }
            }

            Behavior on opacity {
                OpacityAnimator {
                    duration: Motion.durationMedium
                    easing.type: root.expanded ? Motion.easingStandardDecelerate : Motion.easingStandardAccelerate
                    easing.bezierCurve: root.expanded ? Motion.standardDecelerateCurve : Motion.standardAccelerateCurve
                }
            }

            Behavior on scale {
                ScaleAnimator {
                    duration: Motion.durationSpatialDefault
                    easing.type: Motion.easingExpressiveSpatial
                    easing.bezierCurve: Motion.expressiveDefaultSpatialCurve
                }
            }
        }

        AbstractButton {
            id: expansionToggle

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.toggleWidth
            implicitHeight: root.implicitHeight
            focusPolicy: Qt.StrongFocus
            hoverEnabled: true
            scale: down ? 0.9 : 1

            Accessible.name: root.expanded ? qsTr("Collapse system tray") : qsTr("Expand system tray")
            onClicked: root.expandedRequested(!root.expanded)

            background: Rectangle {
                radius: Metrics.radiusFull
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.scheme.onSurface
                    opacity: expansionToggle.down ? Theme.statePressedOpacity : expansionToggle.hovered ? Theme.stateHoverOpacity : expansionToggle.visualFocus ? Theme.stateFocusOpacity : 0

                    Behavior on opacity {
                        OpacityAnimator {
                            duration: Motion.durationShort
                            easing.type: Motion.easingStandard
                            easing.bezierCurve: Motion.standardCurve
                        }
                    }
                }
            }

            contentItem: M3Icon {
                name: "chevron_left"
                size: 20
                color: Theme.scheme.onSurfaceVariant
                rotation: root.expanded ? 180 : 0

                Behavior on rotation {
                    RotationAnimator {
                        duration: Motion.durationSpatialDefault
                        easing.type: Motion.easingExpressiveSpatial
                        easing.bezierCurve: Motion.expressiveDefaultSpatialCurve
                    }
                }
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            Behavior on scale {
                ScaleAnimator {
                    duration: Motion.durationNotification
                    easing.type: Motion.easingExpressiveSpatial
                    easing.bezierCurve: Motion.expressiveDefaultSpatialCurve
                }
            }
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            id: trayWidthAnimation

            duration: Motion.durationSpatialDefault
            easing.type: Motion.easingExpressiveSpatial
            easing.bezierCurve: Motion.expressiveDefaultSpatialCurve
        }
    }

    SystemTrayMenu {
        id: trayMenu

        anchorItem: root
    }
}
