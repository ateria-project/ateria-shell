pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.components
import qs.features.notifications
import qs.platform.notifications
import qs.theme

Control {
    id: root

    clip: true

    required property var notification
    property bool expanded: false
    property bool grouped: false
    property string relativeTime: qsTr("now")
    property bool showSeparator: true
    property bool drawSeparator: true
    property color toggleContainerColor: Theme.scheme.surfaceContainerHighest
    property bool animationReady: false

    readonly property string summary: root.notification ? String(root.notification.summary || "") : ""
    readonly property string sourceName: NotificationController.sourceName(root.notification)
    readonly property string body: NotificationController.bodyText(root.notification)
    readonly property bool hasSummary: root.summary.length > 0 && root.summary !== root.sourceName
    readonly property bool hasBody: root.body.length > 0
    readonly property bool hasActions: Boolean(root.notification && root.notification.actions && root.notification.actions.length > 0)
    readonly property bool hasImage: Boolean(root.notification && String(root.notification.image || "").length > 0)
    readonly property bool expandable: root.hasBody || root.hasActions || root.hasImage
    readonly property string appIconSource: NotificationController.iconSource(root.notification)
    readonly property string groupedIconSource: root.hasImage && root.notification ? String(root.notification.image) : root.appIconSource
    readonly property real expandedContentOffset: metadataLine.implicitHeight + notificationContent.spacing
    readonly property real collapsedIconOffset: Math.max(0, (notificationRow.implicitHeight - applicationIconContainer.implicitHeight) / 2)

    signal expansionRequested

    Component.onCompleted: root.animationReady = true

    onExpandedChanged: {
        if (!root.animationReady || !root.hasSummary)
            return;

        contentPositionAnimation.stop();
        contentPositionOffset.y += root.expanded ? -root.expandedContentOffset : root.expandedContentOffset;
        Qt.callLater(() => contentPositionAnimation.start());
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Motion.durationMedium
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
        }
    }

    leftPadding: root.grouped ? 0 : Metrics.spacingLg
    rightPadding: root.grouped ? 0 : Metrics.spacingLg
    topPadding: root.grouped ? Metrics.spacingSm : Metrics.spacingLg
    bottomPadding: root.grouped ? Metrics.spacingSm : Metrics.spacingLg

    contentItem: RowLayout {
        id: notificationRow

        spacing: Metrics.spacingLg

        Item {
            id: applicationIconContainer

            implicitWidth: 32
            implicitHeight: 32
            Layout.alignment: Qt.AlignTop
            transform: Translate {
                y: root.expanded ? 0 : root.collapsedIconOffset

                Behavior on y {
                    enabled: root.animationReady

                    NumberAnimation {
                        duration: Motion.durationMedium
                        easing.type: Motion.easingEmphasized
                        easing.bezierCurve: Motion.emphasizedCurve
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Metrics.radiusFull
                color: Theme.scheme.primaryContainer
                visible: !applicationIcon.visible && !groupedIconMask.visible

                M3Icon {
                    anchors.centerIn: parent
                    name: "notifications"
                    size: 19
                    color: Theme.scheme.onPrimaryContainer
                }
            }

            Image {
                id: applicationIcon

                anchors.centerIn: parent
                width: 28
                height: 28
                source: root.grouped ? "" : root.appIconSource
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: !root.grouped && source.toString().length > 0 && status !== Image.Error
            }

            Image {
                id: groupedIconImage

                anchors.fill: parent
                source: root.grouped ? root.groupedIconSource : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            Rectangle {
                id: groupedIconShape

                anchors.fill: parent
                radius: Metrics.radiusFull
                visible: false
            }

            OpacityMask {
                id: groupedIconMask

                anchors.fill: parent
                source: groupedIconImage
                maskSource: groupedIconShape
                cached: true
                visible: root.grouped && root.groupedIconSource.length > 0 && groupedIconImage.status !== Image.Error
            }
        }

        ColumnLayout {
            id: notificationContent

            Layout.fillWidth: true
            spacing: Metrics.spacingSm
            transform: Translate {
                id: contentPositionOffset
            }

            M3Text {
                id: metadataLine

                Layout.fillWidth: true
                visible: !root.hasSummary || root.expanded
                text: root.grouped && root.expanded ? root.relativeTime : qsTr("%1  •  %2").arg(root.sourceName).arg(root.relativeTime)
                elide: Text.ElideRight
                maximumLineCount: 1
                color: Theme.scheme.onSurfaceVariant
                font.pixelSize: 14
            }

            M3Text {
                Layout.fillWidth: true
                visible: root.hasSummary
                text: root.expanded ? root.summary : qsTr("%1  •  %2").arg(root.summary).arg(root.relativeTime)
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                maximumLineCount: root.expanded ? 3 : 1
                elide: Text.ElideRight
                color: root.expanded ? Theme.scheme.onSurface : Theme.scheme.onSurfaceVariant
                font.pixelSize: 14
            }

            M3Text {
                Layout.fillWidth: true
                visible: root.hasBody
                text: root.body
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                maximumLineCount: root.expanded ? 6 : 1
                elide: Text.ElideRight
                color: Theme.scheme.onSurfaceVariant
                font.pixelSize: 14
                lineHeight: 1.25
            }

            Flow {
                visible: root.expanded && root.hasActions
                Layout.fillWidth: true
                Layout.topMargin: Metrics.spacingSm
                Layout.bottomMargin: root.grouped && root.showSeparator ? Metrics.spacingSm : 0
                spacing: Metrics.spacingXl

                Repeater {
                    model: root.expanded && root.hasActions ? root.notification.actions.length : 0

                    delegate: NotificationActionLink {
                        required property int index

                        action: root.notification.actions[index]
                    }
                }
            }
        }

        NumberAnimation {
            id: contentPositionAnimation

            target: contentPositionOffset
            property: "y"
            to: 0
            duration: Motion.durationMedium
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
        }

        Rectangle {
            visible: !root.grouped && root.hasImage
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            Layout.alignment: root.expanded ? Qt.AlignTop : Qt.AlignCenter
            radius: Metrics.radiusMd
            color: Theme.scheme.surfaceContainerHighest

            Image {
                id: thumbnailImage

                anchors.fill: parent
                source: !root.grouped && root.notification ? root.notification.image : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            Rectangle {
                id: thumbnailMask

                anchors.fill: parent
                radius: Metrics.radiusMd
                visible: false
            }

            OpacityMask {
                anchors.fill: parent
                source: thumbnailImage
                maskSource: thumbnailMask
                cached: true
            }
        }

        M3Button {
            Layout.alignment: root.expanded ? Qt.AlignTop : Qt.AlignCenter
            visible: root.expandable
            iconName: root.expanded ? "expand_less" : "expand_more"
            iconSize: 20
            style: M3Button.Text
            implicitWidth: 32
            implicitHeight: 32
            containerColor: root.toggleContainerColor
            contentColor: Theme.scheme.onSurfaceVariant
            Accessible.name: root.expanded ? qsTr("Collapse notification") : qsTr("Expand notification")
            onClicked: root.expansionRequested()
        }
    }

    background: Item {
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 1
            color: Theme.scheme.outlineVariant
            opacity: 0.6
            visible: root.showSeparator && root.drawSeparator
        }
    }
}
