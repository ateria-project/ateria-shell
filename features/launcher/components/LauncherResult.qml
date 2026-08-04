pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.components
import qs.features.launcher.icons
import qs.theme

AbstractButton {
    id: root

    required property var desktopEntry
    property bool selected: false

    readonly property string appName: root.desktopEntry ? String(root.desktopEntry.name || "") : ""
    readonly property string appDescription: {
        if (!root.desktopEntry)
            return "";

        const comment = String(root.desktopEntry.comment || "").trim();
        if (comment.length > 0)
            return comment;

        const genericName = String(root.desktopEntry.genericName || "").trim();
        return genericName.length > 0 ? genericName : String(root.desktopEntry.id || "");
    }
    readonly property string iconSource: IconResolver.source(root.desktopEntry ? root.desktopEntry.icon : "")
    readonly property string initial: root.appName.length > 0 ? root.appName.charAt(0).toUpperCase() : "?"

    Accessible.name: root.appDescription.length > 0 ? qsTr("%1, %2").arg(root.appName).arg(root.appDescription) : root.appName
    focusPolicy: Qt.NoFocus
    hoverEnabled: true
    implicitHeight: 56

    background: Rectangle {
        radius: Metrics.radiusMd
        color: root.selected ? Theme.scheme.secondaryContainer : "transparent"

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.selected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
            opacity: root.down ? Theme.statePressedOpacity : root.hovered ? Theme.stateHoverOpacity : 0
        }
    }

    contentItem: RowLayout {
        spacing: Metrics.spacingMd

        Item {
            Layout.leftMargin: Metrics.spacingMd
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36

            Rectangle {
                anchors.fill: parent
                visible: !appIcon.visible
                radius: Metrics.radiusMd
                color: Theme.scheme.primaryContainer

                M3Text {
                    anchors.centerIn: parent
                    text: root.initial
                    color: Theme.scheme.onPrimaryContainer
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    font.family: Typography.monoFamily
                }
            }

            Image {
                id: appIcon

                anchors.fill: parent
                source: root.iconSource
                sourceSize.width: IconResolver.preferredSize
                sourceSize.height: IconResolver.preferredSize
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                visible: root.iconSource.length > 0 && status !== Image.Error
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            M3Text {
                Layout.fillWidth: true
                text: root.appName
                color: root.selected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
                elide: Text.ElideRight
                font.pixelSize: 16
                font.weight: Font.Medium
            }

            M3Text {
                Layout.fillWidth: true
                text: root.appDescription
                color: root.selected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurfaceVariant
                elide: Text.ElideRight
                font.pixelSize: 13
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
