pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.features.quicksettings.components
import qs.platform.network
import qs.theme

M3Panel {
    id: root

    property var controller: null
    property string pendingForgetId: ""
    property string pendingForgetName: ""
    property string pendingOperation: ""
    property string pendingNetworkId: ""
    property string pageError: ""

    implicitHeight: 450

    component SavedNetworkRow: Rectangle {
        id: networkRow

        required property string networkId
        required property string ssid
        required property bool connecting
        required property bool autoconnect
        required property string bssid

        width: savedColumn.width
        height: 56
        radius: 14
        color: "transparent"

        Item {
            anchors {
                left: parent.left
                right: settingsButton.left
                top: parent.top
                bottom: parent.bottom
            }

            RowLayout {
                anchors.fill: parent
                spacing: Metrics.spacingMd

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Metrics.listItemInset
                    spacing: 1

                    M3Text {
                        Layout.fillWidth: true
                        text: networkRow.ssid
                        color: Theme.scheme.onSurface
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    M3Text {
                        Layout.fillWidth: true
                        text: networkRow.autoconnect ? "Auto-connect on" : "Auto-connect off"
                        color: Theme.scheme.onSurfaceVariant
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Item {
                    visible: networkRow.connecting
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36

                    M3ProgressRing {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        indeterminate: true
                        color: Theme.scheme.primary
                    }
                }
            }
        }

        M3Button {
            id: settingsButton

            anchors {
                right: parent.right
                rightMargin: Metrics.listItemInset
                verticalCenter: parent.verticalCenter
            }
            width: 36
            height: 36
            iconName: "settings"
            iconSize: 20
            style: M3Button.Text
            contentColor: Theme.scheme.onSurfaceVariant
            enabled: !networkRow.connecting && !NetworkService.operationBusy
            Accessible.name: qsTr("Settings for %1").arg(networkRow.ssid)
            onClicked: networkMenu.open()

            Popup {
                id: networkMenu

                x: settingsButton.width - width
                y: settingsButton.height
                width: 210
                implicitHeight: menuColumn.implicitHeight + topPadding + bottomPadding
                padding: Metrics.spacingXs
                modal: true
                dim: false
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                enter: Transition { NumberAnimation { duration: 0 } }
                exit: Transition { NumberAnimation { duration: 0 } }

                background: Rectangle {
                    radius: Metrics.radiusSm
                    color: Theme.scheme.surfaceContainerHigh
                }

                contentItem: ColumnLayout {
                    id: menuColumn

                    spacing: 0

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: Metrics.spacingMd
                        spacing: 1

                        M3Text {
                            Layout.fillWidth: true
                            text: networkRow.ssid
                            color: Theme.scheme.onSurface
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        M3Text {
                            visible: networkRow.bssid.length > 0
                            Layout.fillWidth: true
                            text: networkRow.bssid
                            color: Theme.scheme.onSurfaceVariant
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    PopupMenuItem {
                        label: networkRow.autoconnect ? "Disable auto-connect" : "Enable auto-connect"
                        menuIcon: networkRow.autoconnect ? "pause_circle" : "play_circle"
                        Layout.fillWidth: true
                        onActivated: {
                            networkMenu.close();
                            root.pageError = "";
                            root.pendingOperation = "autoconnect";
                            root.pendingNetworkId = networkRow.networkId;
                            if (!NetworkService.setAutoconnect(networkRow.networkId, !networkRow.autoconnect)) {
                                root.pendingOperation = "";
                                root.pendingNetworkId = "";
                                root.pageError = NetworkService.lastError;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                        Layout.preferredHeight: 1
                        color: Theme.scheme.outlineVariant
                        opacity: 0.5
                    }

                    PopupMenuItem {
                        label: "Forget network"
                        menuIcon: "delete"
                        itemColor: Theme.scheme.error
                        Layout.fillWidth: true
                        onActivated: {
                            networkMenu.close();
                            root.pendingForgetId = networkRow.networkId;
                            root.pendingForgetName = networkRow.ssid;
                            forgetDialog.open();
                        }
                    }
                }
            }
        }

    }

    Connections {
        target: NetworkService

        function onNetworkForgotten(networkId: string) {
            if (root.pendingOperation !== "forget" || root.pendingNetworkId !== networkId)
                return;
            root.pendingOperation = "";
            root.pendingNetworkId = "";
            root.pageError = "";
        }

        function onNetworkAutoconnectChanged(networkId: string) {
            if (root.pendingOperation !== "autoconnect"
                    || root.pendingNetworkId !== networkId)
                return;
            root.pendingOperation = "";
            root.pendingNetworkId = "";
            root.pageError = "";
        }

        function onOperationFailed(operation: string, message: string) {
            if (root.pendingOperation !== operation)
                return;
            root.pendingOperation = "";
            root.pendingNetworkId = "";
            root.pageError = message;
        }
    }

    Header {
        id: header

        width: parent.width
        title: "Saved networks"
        onBackRequested: {
            if (root.controller)
                root.controller.popPage();
        }
    }

    Flickable {
        id: savedList

        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            bottom: parent.bottom
            leftMargin: Metrics.listOuterInset
            rightMargin: Metrics.listOuterInset
            topMargin: Metrics.spacingSm
            bottomMargin: Metrics.spacingSm
        }
        contentWidth: width
        contentHeight: savedColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: savedColumn

            width: savedList.width
            spacing: Metrics.spacingXs

            M3Text {
                visible: root.pageError.length > 0
                width: parent.width
                height: visible ? Math.max(40, contentHeight + Metrics.spacingLg) : 0
                leftPadding: Metrics.listSectionHeaderInset
                rightPadding: Metrics.listItemInset
                topPadding: Metrics.spacingSm
                bottomPadding: Metrics.spacingSm
                text: root.pageError
                color: Theme.scheme.error
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            M3Text {
                width: parent.width
                leftPadding: Metrics.listSectionHeaderInset
                height: 32
                text: NetworkService.savedWifiNetworkCount === 1
                    ? "1 saved network"
                    : NetworkService.savedWifiNetworkCount + " saved networks"
                color: Theme.scheme.onSurfaceVariant
                font.pixelSize: 12
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: NetworkService.savedWifiNetworks

                delegate: SavedNetworkRow {}
            }

            Column {
                visible: NetworkService.savedWifiNetworkCount === 0
                width: parent.width
                spacing: Metrics.spacingMd

                Item {
                    width: 1
                    height: 52
                }

                M3Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "bookmark_border"
                    size: 36
                    color: Theme.scheme.onSurfaceVariant
                }

                M3Text {
                    width: parent.width
                    text: "No saved networks"
                    color: Theme.scheme.onSurfaceVariant
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

    }

    Popup {
        id: forgetDialog

        parent: root
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 280
        implicitHeight: forgetContent.implicitHeight + topPadding + bottomPadding
        padding: Metrics.spacingXl
        modal: true
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: Metrics.radiusLg
            color: Theme.scheme.surfaceContainerHigh
        }

        contentItem: ColumnLayout {
            id: forgetContent

            spacing: Metrics.spacingMd

            M3Text {
                Layout.fillWidth: true
                text: qsTr("Forget %1?").arg(root.pendingForgetName)
                color: Theme.scheme.onSurface
                font.pixelSize: 16
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }

            M3Text {
                Layout.fillWidth: true
                text: "The saved profile and credentials will be removed."
                color: Theme.scheme.onSurfaceVariant
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Metrics.spacingMd

                M3Button {
                    text: "Cancel"
                    style: M3Button.Text
                    Layout.preferredHeight: 36
                    onClicked: forgetDialog.close()
                }

                M3Button {
                    text: "Forget"
                    style: M3Button.Text
                    contentColor: Theme.scheme.error
                    Layout.preferredHeight: 36
                    onClicked: {
                        forgetDialog.close();
                        root.pageError = "";
                        root.pendingOperation = "forget";
                        root.pendingNetworkId = root.pendingForgetId;
                        if (!NetworkService.forgetNetwork(root.pendingForgetId)) {
                            root.pendingOperation = "";
                            root.pendingNetworkId = "";
                            root.pageError = NetworkService.lastError;
                        }
                    }
                }
            }
        }
    }
}
