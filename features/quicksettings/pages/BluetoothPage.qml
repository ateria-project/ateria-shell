pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.features.bluetooth
import qs.features.quicksettings.components
import qs.platform.bluetooth
import qs.theme

M3Panel {
    id: root

    property var controller: null
    property bool discoveryStartedHere: false
    property bool discoverableStartedHere: false
    property bool pairableStartedHere: false
    property int previousDiscoverableTimeout: 0
    property int previousPairableTimeout: 0
    property int discoveryRetryCount: 0
    property string operationMessage: ""

    readonly property var activePairingDevice: BluetoothService.pairingRequestDevice()

    implicitHeight: 450

    function updateInlinePairingAvailability() {
        BluetoothPairingController.inlinePromptAvailable = root.activePairingDevice !== null;
    }

    function showOperationFailure(message: string) {
        root.operationMessage = message;
        operationMessageTimer.restart();
    }

    function setKeyboardInputActive(active: bool) {
        if (root.controller)
            root.controller.keyboardInputActive = active;
    }

    function startDiscovery() {
        if (!BluetoothService.operational)
            return;

        if (!BluetoothService.pairable) {
            if (!root.pairableStartedHere)
                root.previousPairableTimeout = Number(BluetoothService.adapter?.pairableTimeout ?? 0);
            if (BluetoothService.setPairable(true, 0))
                root.pairableStartedHere = true;
        }
        if (!BluetoothService.discoverable) {
            if (!root.discoverableStartedHere)
                root.previousDiscoverableTimeout = Number(BluetoothService.adapter?.discoverableTimeout ?? 0);
            if (BluetoothService.setDiscoverable(true, 0))
                root.discoverableStartedHere = true;
        }

        if (!BluetoothService.discovering) {
            if (BluetoothService.setDiscovering(true))
                root.discoveryStartedHere = true;
        }
        discoveryVerificationTimer.restart();
    }

    function stopDiscovery() {
        discoveryVerificationTimer.stop();
        if (root.discoveryStartedHere)
            BluetoothService.setDiscovering(false);
        if (root.discoverableStartedHere)
            BluetoothService.setDiscoverable(false, root.previousDiscoverableTimeout);
        if (root.pairableStartedHere)
            BluetoothService.setPairable(false, root.previousPairableTimeout);
        root.discoveryStartedHere = false;
        root.discoverableStartedHere = false;
        root.pairableStartedHere = false;
        root.previousDiscoverableTimeout = 0;
        root.previousPairableTimeout = 0;
        root.discoveryRetryCount = 0;
    }

    Component.onCompleted: {
        BluetoothPairingController.bluetoothPageActive = true;
        root.updateInlinePairingAvailability();
        if (BluetoothService.operational)
            root.startDiscovery();
    }
    Component.onDestruction: {
        BluetoothPairingController.bluetoothPageActive = false;
        BluetoothPairingController.inlinePromptAvailable = false;
        root.setKeyboardInputActive(false);
        root.stopDiscovery();
    }
    onActivePairingDeviceChanged: root.updateInlinePairingAvailability()

    Connections {
        target: BluetoothService

        function onOperationalChanged() {
            if (BluetoothService.operational) {
                root.startDiscovery();
            } else {
                discoveryVerificationTimer.stop();
                root.discoveryStartedHere = false;
                root.discoverableStartedHere = false;
                root.pairableStartedHere = false;
                root.previousDiscoverableTimeout = 0;
                root.previousPairableTimeout = 0;
                root.discoveryRetryCount = 0;
            }
        }
    }

    Timer {
        id: discoveryVerificationTimer

        interval: 750
        onTriggered: {
            if (!BluetoothService.operational)
                return;

            const exposureReady = BluetoothService.pairable && BluetoothService.discoverable;
            if (exposureReady && BluetoothService.discovering) {
                root.discoveryRetryCount = 0;
                return;
            }

            if (root.discoveryRetryCount < 2) {
                root.discoveryRetryCount++;
                root.startDiscovery();
                return;
            }

            root.discoveryRetryCount = 0;
            root.showOperationFailure(exposureReady
                ? "Could not start device discovery"
                : "Could not make this device discoverable and pairable");
        }
    }

    Timer {
        id: operationMessageTimer

        interval: 4000
        onTriggered: root.operationMessage = ""
    }

    component DeviceMenuItem: AbstractButton {
        id: menuItem

        required property string label
        required property string menuIcon
        property color itemColor: Theme.scheme.onSurface

        signal activated

        implicitHeight: 42
        leftPadding: Metrics.spacingMd
        rightPadding: Metrics.spacingMd
        hoverEnabled: menuItem.enabled
        focusPolicy: Qt.StrongFocus
        opacity: menuItem.enabled ? 1 : 0.38
        Accessible.name: menuItem.label
        onClicked: menuItem.activated()

        background: Rectangle {
            radius: Metrics.radiusSm
            color: menuItem.down || menuItem.hovered ? Theme.stateLayer(menuItem.itemColor, menuItem.down ? Theme.statePressedOpacity : Theme.stateHoverOpacity) : "transparent"
        }

        contentItem: RowLayout {
            spacing: Metrics.spacingMd

            M3Icon {
                name: menuItem.menuIcon
                size: 20
                color: menuItem.itemColor
            }

            M3Text {
                Layout.fillWidth: true
                text: menuItem.label
                color: menuItem.itemColor
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }

        HoverHandler {
            cursorShape: menuItem.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }

    component BluetoothDeviceRow: Rectangle {
        id: deviceRow

        required property var device
        property bool newDevice: false

        readonly property bool busy: BluetoothService.deviceBusy(device)
        readonly property bool hasPairingPrompt: root.activePairingDevice === deviceRow.device
        readonly property bool hasPrimaryAction: deviceRow.device.pairing
            || deviceRow.newDevice
            || !deviceRow.device.connected

        Connections {
            target: deviceRow.device

            function onPairedChanged() {
                if (deviceRow.device.paired)
                    BluetoothService.setDeviceTrusted(deviceRow.device, true);
            }
        }

        implicitHeight: 64 + (deviceRow.hasPairingPrompt ? inlinePairingPrompt.implicitHeight + Metrics.spacingXl : 0)
        radius: 14
        color: device.connected ? Theme.scheme.secondaryContainer : Theme.scheme.surfaceContainerHighest

        AbstractButton {
            id: deviceAction

            anchors {
                left: parent.left
                right: deviceMenuButton.visible ? deviceMenuButton.left : parent.right
                top: parent.top
            }
            height: 64

            enabled: deviceRow.hasPrimaryAction
                && (!deviceRow.device.blocked || deviceRow.device.pairing)
                && (!deviceRow.newDevice || deviceRow.device.pairing || BluetoothService.agentReady)
            hoverEnabled: deviceRow.hasPrimaryAction
            focusPolicy: Qt.StrongFocus
            Accessible.name: {
                if (deviceRow.device.pairing)
                    return qsTr("Cancel pairing with %1").arg(BluetoothService.deviceName(deviceRow.device));
                if (deviceRow.newDevice)
                    return qsTr("Pair with %1").arg(BluetoothService.deviceName(deviceRow.device));
                return qsTr("Connect %1").arg(BluetoothService.deviceName(deviceRow.device));
            }

            onClicked: {
                let succeeded = false;
                if (deviceRow.device.pairing)
                    succeeded = BluetoothService.cancelPairing(deviceRow.device);
                else if (deviceRow.newDevice)
                    succeeded = BluetoothService.pairDevice(deviceRow.device);
                else if (!deviceRow.device.connected)
                    succeeded = BluetoothService.toggleDeviceConnection(deviceRow.device);
                else
                    return;

                if (!succeeded)
                    root.showOperationFailure("Bluetooth operation could not be started");
            }

            background: Rectangle {
                radius: deviceRow.radius
                color: deviceAction.down || deviceAction.hovered
                    ? Theme.stateLayer(Theme.scheme.onSurface, deviceAction.down ? Theme.statePressedOpacity : Theme.stateHoverOpacity)
                    : "transparent"
            }

            contentItem: RowLayout {
                spacing: Metrics.spacingMd

                M3Icon {
                    Layout.leftMargin: Metrics.spacingLg
                    name: BluetoothService.deviceIconName(deviceRow.device)
                    size: 24
                    color: deviceRow.device.connected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    M3Text {
                        Layout.fillWidth: true
                        text: BluetoothService.deviceName(deviceRow.device)
                        color: deviceRow.device.connected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    M3Text {
                        Layout.fillWidth: true
                        text: BluetoothService.deviceDescription(deviceRow.device)
                        color: deviceRow.device.connected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurfaceVariant
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                M3ProgressRing {
                    visible: deviceRow.busy
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.rightMargin: deviceMenuButton.visible ? 0 : Metrics.spacingLg
                    indeterminate: true
                    color: deviceRow.device.connected ? Theme.scheme.onSecondaryContainer : Theme.scheme.primary
                }

                M3Icon {
                    visible: !deviceRow.busy && deviceRow.newDevice
                    Layout.rightMargin: deviceMenuButton.visible ? 0 : Metrics.spacingLg
                    name: "add"
                    size: 20
                    color: deviceRow.device.connected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurfaceVariant
                }
            }

            HoverHandler {
                cursorShape: deviceAction.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }

        M3Button {
            id: deviceMenuButton

            visible: !deviceRow.newDevice
            anchors {
                right: parent.right
                rightMargin: Metrics.spacingSm
                top: parent.top
                topMargin: 14
            }
            width: 36
            height: 36
            iconName: "more_vert"
            iconSize: 20
            style: M3Button.Text
            contentColor: deviceRow.device.connected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurfaceVariant
            Accessible.name: qsTr("Settings for %1").arg(BluetoothService.deviceName(deviceRow.device))
            onClicked: deviceMenu.open()

            Popup {
                id: deviceMenu

                x: deviceMenuButton.width - width
                y: deviceMenuButton.height
                width: 190
                implicitHeight: menuColumn.implicitHeight + topPadding + bottomPadding
                padding: Metrics.spacingXs
                modal: true
                dim: false
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                enter: Transition {
                    NumberAnimation { duration: 0 }
                }

                exit: Transition {
                    NumberAnimation { duration: 0 }
                }

                background: Rectangle {
                    radius: Metrics.radiusSm
                    color: Theme.scheme.surfaceContainerHigh
                }

                contentItem: ColumnLayout {
                    id: menuColumn

                    spacing: 0

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Metrics.spacingMd
                        Layout.rightMargin: Metrics.spacingMd
                        Layout.topMargin: Metrics.spacingSm
                        Layout.bottomMargin: Metrics.spacingSm
                        spacing: 1

                        M3Text {
                            Layout.fillWidth: true
                            text: BluetoothService.deviceName(deviceRow.device)
                            color: Theme.scheme.onSurface
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        M3Text {
                            Layout.fillWidth: true
                            text: String(deviceRow.device.address ?? "")
                            color: Theme.scheme.onSurfaceVariant
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    DeviceMenuItem {
                        label: deviceRow.device.connected ? "Disconnect" : "Connect"
                        menuIcon: deviceRow.device.connected ? "link_off" : "link"
                        enabled: !deviceRow.busy && !deviceRow.device.blocked
                        Layout.fillWidth: true
                        onActivated: {
                            deviceMenu.close();
                            if (!BluetoothService.toggleDeviceConnection(deviceRow.device))
                                root.showOperationFailure("Could not change the device connection");
                        }
                    }

                    DeviceMenuItem {
                        label: deviceRow.device.trusted ? "Untrust device" : "Trust device"
                        menuIcon: deviceRow.device.trusted ? "verified_user" : "add_moderator"
                        Layout.fillWidth: true
                        onActivated: {
                            deviceMenu.close();
                            if (!BluetoothService.setDeviceTrusted(deviceRow.device, !deviceRow.device.trusted))
                                root.showOperationFailure("Could not change the trusted-device setting");
                        }
                    }

                    DeviceMenuItem {
                        label: "Rename device"
                        menuIcon: "edit"
                        Layout.fillWidth: true
                        onActivated: {
                            deviceMenu.close();
                            renameInput.text = BluetoothService.deviceName(deviceRow.device);
                            renameDialog.open();
                        }
                    }

                    DeviceMenuItem {
                        label: deviceRow.device.blocked ? "Unblock device" : "Block device"
                        menuIcon: deviceRow.device.blocked ? "lock_open" : "block"
                        Layout.fillWidth: true
                        onActivated: {
                            deviceMenu.close();
                            if (!BluetoothService.setDeviceBlocked(deviceRow.device, !deviceRow.device.blocked))
                                root.showOperationFailure("Could not change the blocked-device setting");
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

                    DeviceMenuItem {
                        label: "Forget device"
                        menuIcon: "delete"
                        itemColor: Theme.scheme.error
                        enabled: !deviceRow.busy
                        Layout.fillWidth: true
                        onActivated: {
                            deviceMenu.close();
                            forgetConfirmation.open();
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: deviceRow.hasPairingPrompt
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: 63
                leftMargin: Metrics.spacingLg
                rightMargin: Metrics.spacingLg
            }
            height: 1
            color: deviceRow.device.connected ? Theme.scheme.onSecondaryContainer : Theme.scheme.outlineVariant
            opacity: 0.35
        }

        BluetoothPairingPrompt {
            id: inlinePairingPrompt

            visible: deviceRow.hasPairingPrompt
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: 64 + Metrics.spacingMd
                leftMargin: Metrics.spacingLg
                rightMargin: Metrics.spacingLg
            }
            request: deviceRow.hasPairingPrompt ? BluetoothService.pairingRequest : ({})
            embedded: true
            contentColor: deviceRow.device.connected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurface
            secondaryColor: deviceRow.device.connected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurfaceVariant
        }

        Popup {
            id: renameDialog

            parent: root
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            width: 288
            implicitHeight: renameContent.implicitHeight + topPadding + bottomPadding
            padding: Metrics.spacingXl
            modal: true
            dim: false
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            onOpened: {
                root.setKeyboardInputActive(true);
                Qt.callLater(() => renameInput.forceActiveFocus());
            }
            onClosed: root.setKeyboardInputActive(false)

            background: Rectangle {
                radius: Metrics.radiusLg
                color: Theme.scheme.surfaceContainerHigh
            }

            contentItem: ColumnLayout {
                id: renameContent

                spacing: Metrics.spacingMd

                M3Text {
                    Layout.fillWidth: true
                    text: "Rename device"
                    color: Theme.scheme.onSurface
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }

                M3Text {
                    Layout.fillWidth: true
                    text: qsTr("Choose a name to identify this device.")
                    color: Theme.scheme.onSurfaceVariant
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                M3OutlinedTextField {
                    id: renameInput

                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    placeholderText: "Device name"
                    maximumLength: 64
                    onAccepted: renameButton.clicked()
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    Layout.topMargin: Metrics.spacingSm
                    spacing: Metrics.spacingMd

                    M3Button {
                        text: "Cancel"
                        style: M3Button.Text
                        labelFontSize: 14
                        Layout.preferredHeight: 36
                        onClicked: renameDialog.close()
                    }

                    M3Button {
                        id: renameButton

                        text: "Rename"
                        labelFontSize: 14
                        Layout.preferredHeight: 36
                        enabled: renameInput.text.trim().length > 0
                        onClicked: {
                            if (!BluetoothService.setDeviceName(deviceRow.device, renameInput.text)) {
                                root.showOperationFailure("Could not rename the device");
                                return;
                            }
                            renameDialog.close();
                        }
                    }
                }
            }
        }

        Popup {
            id: forgetConfirmation

            parent: root
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            width: 280
            implicitHeight: confirmationContent.implicitHeight + topPadding + bottomPadding
            padding: Metrics.spacingXl
            modal: true
            dim: false
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            background: Rectangle {
                radius: Metrics.radiusLg
                color: Theme.scheme.surfaceContainerHigh
            }

            contentItem: ColumnLayout {
                id: confirmationContent

                spacing: Metrics.spacingMd

                M3Text {
                    Layout.fillWidth: true
                    text: qsTr("Forget %1?").arg(BluetoothService.deviceName(deviceRow.device))
                    color: Theme.scheme.onSurface
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }

                M3Text {
                    Layout.fillWidth: true
                    text: "You will need to pair this device again before reconnecting."
                    color: Theme.scheme.onSurfaceVariant
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    Layout.topMargin: Metrics.spacingSm
                    spacing: Metrics.spacingMd

                    M3Button {
                        text: "Cancel"
                        style: M3Button.Text
                        labelFontSize: 14
                        Layout.preferredHeight: 36
                        onClicked: forgetConfirmation.close()
                    }

                    M3Button {
                        text: "Forget"
                        style: M3Button.Text
                        labelFontSize: 14
                        Layout.preferredHeight: 36
                        contentColor: Theme.scheme.error
                        onClicked: {
                            forgetConfirmation.close();
                            if (!BluetoothService.forgetDevice(deviceRow.device))
                                root.showOperationFailure("Could not forget the device");
                        }
                    }
                }
            }
        }
    }

    Header {
        id: header

        width: parent.width
        title: "Bluetooth"
        trailingItem: M3Switch {
            checked: BluetoothService.enabled
            enabled: BluetoothService.available
                && !BluetoothService.blocked
                && !BluetoothService.enabling
                && !BluetoothService.disabling
            Accessible.name: checked ? qsTr("Turn Bluetooth off") : qsTr("Turn Bluetooth on")
            onToggled: {
                if (checked !== BluetoothService.enabled && !BluetoothService.setEnabled(checked))
                    root.showOperationFailure("Could not change Bluetooth power");
            }
        }
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
        visible: BluetoothService.discovering
        height: 2
        indeterminate: true
        accessibleName: qsTr("Scanning for Bluetooth devices")
    }

    Item {
        anchors {
            left: parent.left
            right: parent.right
            top: header.bottom
            bottom: parent.bottom
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: Metrics.spacingMd
            visible: !BluetoothService.operational

            M3Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: BluetoothService.available ? "bluetooth_disabled" : "bluetooth_searching"
                size: 40
                color: Theme.scheme.onSurfaceVariant
            }

            M3Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: BluetoothService.blocked
                    ? "Bluetooth is blocked"
                    : (!BluetoothService.available
                        ? "Bluetooth is unavailable"
                        : (BluetoothService.enabling
                            ? "Turning Bluetooth on"
                            : (BluetoothService.disabling ? "Turning Bluetooth off" : "Bluetooth is off")))
                color: Theme.scheme.onSurface
                font.pixelSize: 15
                font.weight: Font.Medium
            }

            M3Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: BluetoothService.available
                    ? (BluetoothService.blocked
                        ? "Bluetooth has been disabled by the system."
                        : (BluetoothService.enabling
                            ? "Getting the adapter ready…"
                            : "Use the switch above to turn on Bluetooth."))
                    : "No Bluetooth adapter was found."
                color: Theme.scheme.onSurfaceVariant
                font.pixelSize: 12
            }
        }

        Flickable {
            id: deviceList

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                leftMargin: Metrics.spacingLg
                rightMargin: Metrics.spacingLg
                topMargin: Metrics.spacingSm
                bottomMargin: Metrics.spacingSm
            }
            visible: BluetoothService.operational
            contentWidth: width
            contentHeight: deviceColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: deviceColumn

                width: deviceList.width - (deviceList.contentHeight > deviceList.height ? Metrics.spacingMd : 0)
                spacing: Metrics.spacingXs

                M3Text {
                    readonly property string statusMessage: root.operationMessage.length > 0 ? root.operationMessage : BluetoothService.agentError

                    visible: statusMessage.length > 0
                    width: parent.width
                    height: visible ? 34 : 0
                    text: statusMessage
                    color: Theme.scheme.error
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                M3Text {
                    visible: BluetoothService.pairedDevices.length > 0
                    width: parent.width
                    height: visible ? 32 : 0
                    text: "Paired devices"
                    color: Theme.scheme.onSurfaceVariant
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: BluetoothService.pairedDevices

                    delegate: BluetoothDeviceRow {
                        required property var modelData

                        width: deviceColumn.width
                        device: modelData
                    }
                }

                M3Text {
                    width: parent.width
                    height: 38
                    text: "Not paired"
                    color: Theme.scheme.onSurfaceVariant
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: BluetoothService.unpairedDevices

                    delegate: BluetoothDeviceRow {
                        required property var modelData

                        width: deviceColumn.width
                        device: modelData
                        newDevice: true
                    }
                }

                M3Text {
                    visible: BluetoothService.unpairedDevices.length === 0
                    width: parent.width
                    height: visible ? 42 : 0
                    text: BluetoothService.discovering ? "Searching for nearby devices…" : "No devices found"
                    color: Theme.scheme.onSurfaceVariant
                    verticalAlignment: Text.AlignVCenter
                }
            }

            ScrollBar.vertical: M3ScrollBar {
                policy: deviceList.contentHeight > deviceList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }
        }
    }
}
