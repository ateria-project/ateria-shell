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
    property bool saveAttempted: false
    property bool saveInProgress: false
    property string saveError: ""
    readonly property var securityValues: [
        NetworkService.securityWpaPersonal,
        NetworkService.securityWpa3Personal,
        NetworkService.securityOpen,
        NetworkService.securityOwe,
        NetworkService.securityWep
    ]
    readonly property int selectedSecurity: root.securityValues[securityCombo.currentIndex]

    implicitHeight: header.implicitHeight + Metrics.spacingLg * 2 + formColumn.implicitHeight

    function setKeyboardInputActive(active: bool) {
        if (root.controller)
            root.controller.keyboardInputActive = active;
    }

    function saveNetwork() {
        root.saveAttempted = true;
        if (NetworkService.validatePassword(root.selectedSecurity, passwordInput.text).length > 0)
            return;

        root.saveError = "";
        root.saveInProgress = NetworkService.addAndConnectWifi(ssidInput.text,
            NetworkService.requiresPassword(root.selectedSecurity) ? passwordInput.text : "",
            root.selectedSecurity,
            hiddenSwitch.checked);
        if (!root.saveInProgress)
            root.saveError = NetworkService.lastError;
    }

    Component.onCompleted: {
        root.setKeyboardInputActive(true);
        Qt.callLater(() => ssidInput.forceActiveFocus());
    }
    Component.onDestruction: {
        passwordInput.clear();
        root.setKeyboardInputActive(false);
    }

    Connections {
        target: NetworkService

        function onNetworkConnected() {
            if (!root.saveInProgress)
                return;
            root.saveInProgress = false;
            if (root.controller)
                root.controller.popPage();
        }

        function onOperationFailed(operation: string, message: string) {
            if (!root.saveInProgress || operation !== "connect")
                return;
            root.saveInProgress = false;
            root.saveError = message;
        }
    }

    Header {
        id: header

        width: parent.width
        title: "Add network"
        onBackRequested: {
            if (root.controller)
                root.controller.popPage();
        }
    }

    M3ProgressBar {
        anchors {
            left: header.left
            right: header.right
            top: header.bottom
        }
        z: 1
        visible: root.saveInProgress
        height: 2
        indeterminate: true
        accessibleName: qsTr("Saving Wi-Fi network")
    }

    ColumnLayout {
        id: formColumn

        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            leftMargin: Metrics.spacingXl
            rightMargin: Metrics.spacingXl
            topMargin: Metrics.spacingLg
        }
        spacing: Metrics.spacingLg

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSm

            M3Text {
                text: "Network name"
                color: Theme.scheme.onSurface
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            M3OutlinedTextField {
                id: ssidInput

                Layout.fillWidth: true
                placeholderText: "SSID"
                maximumLength: 32
                onTextChanged: root.saveError = ""
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSm

            M3Text {
                text: "Security"
                color: Theme.scheme.onSurface
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            M3ComboBox {
                id: securityCombo

                Layout.fillWidth: true
                alwaysShowContainer: true
                textAlignment: Text.AlignLeft
                model: ["WPA/WPA2", "WPA3", "Open", "Enhanced Open", "WEP"]
                onCurrentIndexChanged: {
                    root.saveAttempted = false;
                    root.saveError = "";
                }
            }
        }

        ColumnLayout {
            visible: NetworkService.requiresPassword(root.selectedSecurity)
            Layout.fillWidth: true
            spacing: Metrics.spacingSm

            M3Text {
                text: "Password"
                color: Theme.scheme.onSurface
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            M3OutlinedTextField {
                id: passwordInput

                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                maximumLength: 64
                onTextChanged: root.saveError = ""
                onAccepted: saveButton.clicked()
            }

            M3Text {
                readonly property string validationMessage: NetworkService.validatePassword(root.selectedSecurity,
                    passwordInput.text)

                visible: root.saveAttempted && validationMessage.length > 0
                Layout.fillWidth: true
                text: validationMessage
                color: Theme.scheme.error
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacingSm
            spacing: Metrics.spacingMd

            M3Switch {
                id: hiddenSwitch

                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                checked: true
                Accessible.name: qsTr("Hidden network")
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                M3Text {
                    Layout.fillWidth: true
                    text: "Hidden network"
                    color: Theme.scheme.onSurface
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                M3Text {
                    Layout.fillWidth: true
                    text: "Use this when the network does not broadcast its name."
                    color: Theme.scheme.onSurfaceVariant
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }
        }

        M3Text {
            visible: root.saveError.length > 0
            Layout.fillWidth: true
            text: root.saveError
            color: Theme.scheme.error
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacingMd
            spacing: Metrics.spacingMd

            Item { Layout.fillWidth: true }

            M3Button {
                text: "Cancel"
                style: M3Button.Text
                Layout.preferredHeight: 38
                onClicked: {
                    if (root.controller)
                        root.controller.popPage();
                }
            }

            M3Button {
                id: saveButton

                text: root.saveInProgress ? "Saving…" : "Save"
                Layout.preferredHeight: 38
                enabled: ssidInput.text.trim().length > 0
                    && !NetworkService.operationBusy
                onClicked: root.saveNetwork()
            }
        }
    }
}
