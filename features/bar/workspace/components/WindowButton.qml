import QtQuick
import QtQuick.Controls
import Quickshell
import qs.components
import qs.platform.appicons
import qs.theme

AbstractButton {
    id: root

    required property var windowData
    required property real cellWidth
    required property real cellHeight
    required property real indicatorWidth
    property bool active: false
    property bool useAppIcons: true
    property int desktopEntriesRevision: 0

    readonly property int iconSourceSize: 36
    readonly property double windowId: Number(root.windowData?.id ?? 0)
    readonly property string appId: String(root.windowData?.appId || "")
    readonly property string title: String(root.windowData?.title || root.appId || qsTr("Window"))
    readonly property bool urgent: Boolean(root.windowData?.urgent)
    readonly property var desktopEntry: {
        root.desktopEntriesRevision;
        return root.appId.length > 0 ? DesktopEntries.heuristicLookup(root.appId) : null;
    }
    readonly property string desktopIcon: root.desktopEntry ? String(root.desktopEntry.icon || "") : ""
    readonly property string displayName: root.desktopEntry
        ? String(root.desktopEntry.name || root.appId || root.title)
        : String(root.appId || root.title)
    readonly property string initial: root.displayName.length > 0 ? root.displayName.charAt(0).toUpperCase() : "?"
    readonly property string iconSource: {
        if (!root.useAppIcons)
            return "";
        const declaredSource = AppIconResolver.source(root.desktopIcon, root.iconSourceSize);
        return declaredSource.length > 0
            ? declaredSource
            : AppIconResolver.source(root.appId, root.iconSourceSize);
    }

    Accessible.name: root.title
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    implicitWidth: root.cellWidth
    implicitHeight: root.cellHeight
    scale: root.down ? 0.82 : 1

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    background: Rectangle {
        anchors.centerIn: parent
        width: root.indicatorWidth
        height: root.cellHeight
        radius: Metrics.radiusSm
        color: root.urgent && !root.active ? Theme.scheme.errorContainer : Theme.scheme.onSurface
        opacity: root.urgent && !root.active ? 1 : root.hovered && !root.active ? 0.08 : root.visualFocus && !root.active ? 0.14 : 0

        Behavior on color {
            ColorAnimation { duration: Motion.durationShort }
        }
        Behavior on opacity {
            NumberAnimation { duration: Motion.durationShort }
        }
    }

    contentItem: Item {
        Image {
            id: appIcon

            anchors.centerIn: parent
            width: 18
            height: 18
            source: root.iconSource
            sourceSize.width: root.iconSourceSize
            sourceSize.height: root.iconSourceSize
            fillMode: Image.PreserveAspectFit
            opacity: root.active ? 1 : 0.85
            scale: root.active ? 1 : 0.88
            visible: root.iconSource.length > 0 && status !== Image.Error

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

        M3Text {
            anchors.centerIn: parent
            visible: !appIcon.visible
            text: root.initial
            color: root.urgent ? Theme.scheme.onErrorContainer : root.active ? Theme.scheme.onPrimaryContainer : Theme.scheme.onSurface
            opacity: root.active ? 1 : 0.85
            scale: root.active ? 1 : 0.88
            font.pixelSize: 14
            font.weight: Font.Medium

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
