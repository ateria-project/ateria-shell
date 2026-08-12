pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.platform.bluetooth
import qs.theme

Item {
    id: root

    required property var request
    property bool embedded: false
    property color contentColor: Theme.scheme.onSurface
    property color secondaryColor: Theme.scheme.onSurfaceVariant

    readonly property string requestType: String(root.request?.type ?? "")
    readonly property bool inputRequired: root.requestType === "pinCode" || root.requestType === "passkey"
    readonly property bool displayOnly: root.request?.event === "display"
    readonly property bool inputValid: root.requestType === "pinCode"
        ? responseInput.text.length > 0 && responseInput.text.length <= 16
        : /^\d{1,6}$/.test(responseInput.text)

    implicitHeight: promptContent.implicitHeight

    function requestTitle(): string {
        switch (root.requestType) {
        case "pinCode":
        case "passkey":
            return "Enter pairing code";
        case "confirmation":
            return "Confirm pairing code";
        case "authorization":
            return "Bluetooth pairing request";
        case "serviceAuthorization":
            return "Bluetooth access request";
        default:
            return "Bluetooth pairing";
        }
    }

    function requestDescription(): string {
        const name = String(root.request?.name ?? "Bluetooth device");
        switch (root.requestType) {
        case "pinCode":
            return qsTr("Enter the PIN shown on %1 or in its documentation.").arg(name);
        case "passkey":
            return qsTr("Enter the numeric passkey for %1.").arg(name);
        case "confirmation":
            return qsTr("Confirm that this code also appears on %1.").arg(name);
        case "authorization":
            return qsTr("%1 wants to pair with this computer.").arg(name);
        case "serviceAuthorization":
            return qsTr("Allow %1 to use %2?").arg(name).arg(BluetoothService.serviceName(String(root.request?.uuid ?? "")));
        default:
            return qsTr("Enter this code on %1, then complete pairing on the device.").arg(name);
        }
    }

    function rejectRequest() {
        if (root.displayOnly) {
            BluetoothService.cancelActivePairing();
            BluetoothService.dismissPairingDisplay();
        } else {
            BluetoothService.rejectPairing();
        }
    }

    function acceptRequest() {
        if (root.inputRequired && !root.inputValid)
            return;
        BluetoothService.acceptPairing(root.inputRequired ? responseInput.text : "");
    }

    onRequestChanged: {
        responseInput.clear();
        if (root.inputRequired)
            Qt.callLater(() => responseInput.forceActiveFocus());
    }

    ColumnLayout {
        id: promptContent

        width: parent.width
        spacing: Metrics.spacingMd

        M3Text {
            visible: !(root.embedded && root.requestType === "confirmation")
            Layout.fillWidth: true
            text: root.requestTitle()
            color: root.contentColor
            font.pixelSize: root.embedded ? 13 : 16
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        M3Text {
            Layout.fillWidth: true
            text: root.requestDescription()
            color: root.secondaryColor
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        M3Text {
            visible: !root.inputRequired && String(root.request?.value ?? "").length > 0
            Layout.fillWidth: true
            text: String(root.request?.value ?? "")
            horizontalAlignment: Text.AlignHCenter
            color: root.contentColor
            font.pixelSize: root.embedded ? 26 : 30
            font.weight: Font.DemiBold
            font.letterSpacing: 5
        }

        M3Text {
            visible: root.displayOnly && root.requestType === "passkey" && Number(root.request?.entered ?? 0) > 0
            Layout.fillWidth: true
            text: qsTr("%1 of 6 digits entered").arg(Number(root.request?.entered ?? 0))
            horizontalAlignment: Text.AlignHCenter
            color: root.secondaryColor
            font.pixelSize: 12
        }

        M3OutlinedTextField {
            id: responseInput

            visible: root.inputRequired
            Layout.fillWidth: true
            placeholderText: root.requestType === "pinCode" ? "PIN" : "Passkey"
            inputMethodHints: root.requestType === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
            maximumLength: root.requestType === "pinCode" ? 16 : 6
            contentColor: root.contentColor
            placeholderColor: root.secondaryColor
            Accessible.name: placeholderText
            onAccepted: root.acceptRequest()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSm

            Item {
                Layout.fillWidth: true
            }

            M3Button {
                text: root.displayOnly ? "Cancel pairing" : (root.requestType === "confirmation" ? "Doesn't match" : "Deny")
                style: M3Button.Text
                contentColor: root.displayOnly ? Theme.scheme.error : root.secondaryColor
                onClicked: root.rejectRequest()
            }

            M3Button {
                visible: !root.displayOnly
                text: root.inputRequired ? "Continue" : (root.requestType === "confirmation" ? "Matches" : "Allow")
                enabled: !root.inputRequired || root.inputValid
                onClicked: root.acceptRequest()
            }
        }
    }
}
