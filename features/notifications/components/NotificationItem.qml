pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell.Widgets
import qs.components
import qs.features.notifications
import qs.theme

Control {
    id: root

    required property var notification
    property bool expanded: false
    property bool grouped: false
    property string relativeTime: qsTr("now")
    property bool showSeparator: true
    property bool drawSeparator: true
    property color toggleContainerColor: Theme.scheme.surfaceContainerHighest

    readonly property var meta: NotificationController.metadata(root.notification)
    readonly property string summary: root.notification ? String(root.notification.summary || "").trim() : ""
    readonly property string sourceName: root.meta.sourceName
    readonly property string body: root.meta.body
    readonly property bool hasSummary: root.summary.length > 0 && root.summary !== root.sourceName
    readonly property bool hasBody: root.body.length > 0
    readonly property bool hasActions: Boolean(root.notification && root.notification.actions && root.notification.actions.length > 0)
    readonly property string imageSource: root.notification ? String(root.notification.image || "") : ""
    readonly property bool hasImage: root.imageSource.length > 0
    readonly property bool expandable: root.hasBody || root.hasActions || root.hasImage
    readonly property string appIconSource: root.meta.iconSource
    readonly property string groupedIconSource: root.hasImage ? root.imageSource : root.appIconSource
    readonly property real rowImplicitHeight: notificationRow.implicitHeight
    readonly property real collapsedIconOffset: Math.max(0, (root.rowImplicitHeight - applicationIconContainer.implicitHeight) / 2)

    signal expansionRequested

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
                    NumberAnimation {
                        duration: Motion.durationNotification
                        easing.type: Motion.easingEmphasized
                        easing.bezierCurve: Motion.emphasizedCurve
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Metrics.radiusFull
                color: Theme.scheme.primaryContainer
                visible: !applicationIcon.visible && !groupedIconContainer.visible

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
                visible: !root.grouped && root.appIconSource.length > 0 && status !== Image.Error
            }

            ClippingRectangle {
                id: groupedIconContainer

                anchors.fill: parent
                radius: Metrics.radiusFull
                color: "transparent"
                visible: root.grouped && root.groupedIconSource.length > 0 && groupedIconImage.status !== Image.Error

                Image {
                    id: groupedIconImage

                    anchors.fill: parent
                    source: root.grouped ? root.groupedIconSource : ""
                    sourceSize.width: 64
                    sourceSize.height: 64
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
        }

        ColumnLayout {
            id: notificationContent

            Layout.fillWidth: true
            spacing: Metrics.spacingSm

            M3Text {
                id: metadataLine

                Layout.fillWidth: true
                visible: !root.hasSummary || root.expanded
                text: root.grouped && root.expanded ? root.relativeTime : qsTr("%1  •  %2").arg(root.sourceName).arg(root.relativeTime)
                textFormat: Text.PlainText
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
                    model: root.expanded && root.hasActions ? root.notification.actions : null

                    delegate: NotificationActionLink {
                        required property var modelData

                        action: modelData
                    }
                }
            }
        }

        ClippingRectangle {
            id: notificationImage

            readonly property real collapsedOffset: visible ? Math.max(0, (root.rowImplicitHeight - height) / 2) : 0

            visible: !root.grouped && root.hasImage
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            Layout.alignment: Qt.AlignTop
            radius: Metrics.radiusMd
            color: Theme.scheme.surfaceContainerHighest

            transform: Translate {
                y: root.expanded ? 0 : notificationImage.collapsedOffset

                Behavior on y {
                    enabled: notificationImage.visible

                    NumberAnimation {
                        duration: Motion.durationNotification
                        easing.type: Motion.easingEmphasized
                        easing.bezierCurve: Motion.emphasizedCurve
                    }
                }
            }

            Image {
                anchors.fill: parent
                source: !root.grouped ? root.imageSource : ""
                sourceSize.width: 96
                sourceSize.height: 96
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
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
