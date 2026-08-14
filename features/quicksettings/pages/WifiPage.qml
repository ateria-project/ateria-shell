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
    property string credentialNetworkId: ""
    property string credentialSsid: ""
    property int credentialSecurity: NetworkService.securityWpaPersonal

    implicitHeight: 450

    function setKeyboardInputActive(active: bool) {
        if (root.controller)
            root.controller.keyboardInputActive = active;
    }

    function openCredentials(networkId: string, ssid: string, security: int) {
        root.credentialNetworkId = networkId;
        root.credentialSsid = ssid;
        root.credentialSecurity = security;
        passwordInput.clear();
        passwordDialog.open();
    }

    function networkDescription(connected: bool, connecting: bool, known: bool): string {
        if (connected) {
            if (NetworkService.captivePortal)
                return qsTr("Sign-in required");
            if (NetworkService.limitedConnectivity)
                return qsTr("Connected, no internet");
            return qsTr("Connected");
        }
        if (connecting)
            return qsTr("Connecting…");
        if (known)
            return qsTr("Saved");
        return "";
    }

    function requestScanOnOpen() {
        if (!root.visible
                || !NetworkService.available
                || !NetworkService.hasWifiDevice
                || !NetworkService.wifiHardwareEnabled
                || !NetworkService.wifiEnabled) {
            scanRetryTimer.stop();
            return;
        }

        if (NetworkService.scanning || NetworkService.requestScan()) {
            scanRetryTimer.stop();
            return;
        }

        scanRetryTimer.restart();
    }

    Component.onCompleted: Qt.callLater(root.requestScanOnOpen)
    Component.onDestruction: root.setKeyboardInputActive(false)
    StackView.onActivated: Qt.callLater(root.requestScanOnOpen)

    Connections {
        target: NetworkService

        function onCredentialsRequired(networkId: string, ssid: string, security: int) {
            root.openCredentials(networkId, ssid, security);
        }

        function onNetworkConnected() {
            passwordDialog.close();
        }

        function onWifiEnabledChanged() {
            if (NetworkService.wifiEnabled)
                Qt.callLater(root.requestScanOnOpen);
            else
                scanRetryTimer.stop();
        }
    }

    Timer {
        id: scanRetryTimer

        interval: 500
        repeat: false
        onTriggered: root.requestScanOnOpen()
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.visible && NetworkService.wifiEnabled
        onTriggered: NetworkService.requestScan()
    }

    component WifiNetworkRow: Rectangle {
        id: networkRow

        required property string networkId
        required property string ssid
        required property int strength
        required property int security
        required property bool known
        required property bool connected
        required property bool connecting
        required property bool autoconnect
        required property bool canForget
        required property string bssid

        readonly property color rowContentColor: networkRow.connected
            ? Theme.scheme.onSecondaryContainer
            : Theme.scheme.onSurface

        width: networkColumn.width
        height: 56
        radius: 14
        color: networkRow.connected ? Theme.scheme.secondaryContainer : "transparent"

        HoverHandler {
            id: networkRowHover
        }

        AbstractButton {
            id: primaryAction

            anchors {
                left: parent.left
                right: menuButton.visible ? menuButton.left : parent.right
                top: parent.top
                bottom: parent.bottom
            }
            enabled: !networkRow.connecting
                && !NetworkService.operationBusy
                && (!networkRow.connected || networkRow.canForget)
            hoverEnabled: enabled
            focusPolicy: Qt.StrongFocus
            Accessible.name: networkRow.connected
                ? qsTr("Network details for %1").arg(networkRow.ssid)
                : qsTr("Connect to %1").arg(networkRow.ssid)
            onClicked: {
                if (networkRow.connected) {
                    networkMenu.open();
                    return;
                }
                NetworkService.connectNetwork(networkRow.networkId);
            }

            background: Rectangle {
                width: networkRow.width
                radius: networkRow.radius
                color: primaryAction.down || networkRowHover.hovered
                    ? Theme.stateLayer(networkRow.rowContentColor,
                        primaryAction.down ? Theme.statePressedOpacity : Theme.stateHoverOpacity)
                    : "transparent"
            }

            contentItem: RowLayout {
                spacing: Metrics.spacingMd

                M3Icon {
                    Layout.leftMargin: Metrics.listItemInset
                    Layout.preferredWidth: Metrics.listLeadingIconSize
                    name: NetworkService.signalIcon(networkRow.strength)
                    size: 24
                    color: networkRow.rowContentColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    M3Text {
                        Layout.fillWidth: true
                        text: networkRow.ssid
                        color: networkRow.rowContentColor
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    M3Text {
                        Layout.fillWidth: true
                        text: root.networkDescription(networkRow.connected,
                            networkRow.connecting,
                            networkRow.known)
                        visible: text.length > 0
                        color: networkRow.connected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurfaceVariant
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Item {
                    visible: networkRow.connecting
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.rightMargin: menuButton.visible ? 0 : Metrics.listItemInset

                    M3ProgressRing {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        indeterminate: true
                        color: Theme.scheme.primary
                    }
                }

                Item {
                    visible: !networkRow.connected
                        && !networkRow.connecting
                        && !networkRow.known
                        && NetworkService.requiresPassword(networkRow.security)
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.rightMargin: menuButton.visible ? 0 : Metrics.listItemInset

                    M3Icon {
                        anchors.centerIn: parent
                        name: "lock"
                        size: 20
                        color: Theme.scheme.onSurfaceVariant
                    }
                }
            }

            HoverHandler {
                cursorShape: primaryAction.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }

        M3Button {
            id: menuButton

            visible: networkRow.known || networkRow.connected
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
            contentColor: networkRow.connected ? Theme.scheme.onSecondaryContainer : Theme.scheme.onSurfaceVariant
            enabled: !networkRow.connecting && !NetworkService.operationBusy
            Accessible.name: qsTr("Settings for %1").arg(networkRow.ssid)
            onClicked: networkMenu.open()

            Popup {
                id: networkMenu

                x: menuButton.width - width
                y: menuButton.height
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
                            Layout.fillWidth: true
                            text: networkRow.bssid
                            visible: text.length > 0
                            color: Theme.scheme.onSurfaceVariant
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    PopupMenuItem {
                        label: networkRow.connected ? "Disconnect" : "Connect"
                        menuIcon: networkRow.connected ? "link_off" : "link"
                        Layout.fillWidth: true
                        onActivated: {
                            networkMenu.close();
                            if (networkRow.connected)
                                NetworkService.disconnectNetwork(networkRow.networkId);
                            else
                                NetworkService.connectNetwork(networkRow.networkId);
                        }
                    }

                    PopupMenuItem {
                        visible: networkRow.known
                        label: networkRow.autoconnect ? "Disable auto-connect" : "Enable auto-connect"
                        menuIcon: networkRow.autoconnect ? "pause_circle" : "play_circle"
                        Layout.fillWidth: true
                        onActivated: {
                            networkMenu.close();
                            NetworkService.setAutoconnect(networkRow.networkId, !networkRow.autoconnect);
                        }
                    }

                    Rectangle {
                        visible: networkRow.canForget
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                        Layout.preferredHeight: visible ? 1 : 0
                        color: Theme.scheme.outlineVariant
                        opacity: 0.5
                    }

                    PopupMenuItem {
                        visible: networkRow.canForget
                        label: "Forget network"
                        menuIcon: "delete"
                        itemColor: Theme.scheme.error
                        Layout.fillWidth: true
                        onActivated: {
                            networkMenu.close();
                            root.credentialNetworkId = networkRow.networkId;
                            root.credentialSsid = networkRow.ssid;
                            forgetDialog.open();
                        }
                    }
                }
            }
        }
    }

    Header {
        id: header

        width: parent.width
        title: "Wi-Fi"
        trailingItem: M3Switch {
            checked: NetworkService.wifiEnabled
            enabled: NetworkService.available
                && NetworkService.hasWifiDevice
                && NetworkService.wifiHardwareEnabled
                && !NetworkService.operationBusy
            Accessible.name: checked ? qsTr("Turn Wi-Fi off") : qsTr("Turn Wi-Fi on")
            onToggled: {
                if (checked !== NetworkService.wifiEnabled)
                    NetworkService.setWifiEnabled(checked);
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
        visible: NetworkService.scanning || NetworkService.currentOperation === "connect"
        height: 2
        indeterminate: true
        accessibleName: NetworkService.scanning
            ? qsTr("Scanning for Wi-Fi networks")
            : qsTr("Connecting to Wi-Fi")
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
            visible: !NetworkService.available
                || !NetworkService.hasWifiDevice
                || !NetworkService.wifiHardwareEnabled
                || !NetworkService.wifiEnabled

            M3Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: !NetworkService.hasWifiDevice ? "wifi_off" : "signal_wifi_off"
                size: 40
                color: Theme.scheme.onSurfaceVariant
            }

            M3Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: !NetworkService.available
                    ? "The Wi-Fi service is unavailable"
                    : (!NetworkService.hasWifiDevice
                        ? "No Wi-Fi adapter found"
                        : (!NetworkService.wifiHardwareEnabled ? "Wi-Fi is hardware disabled" : "Wi-Fi is off"))
                color: Theme.scheme.onSurface
                font.pixelSize: 15
                font.weight: Font.Medium
            }

            M3Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: NetworkService.wifiHardwareEnabled
                    ? "Use the switch above to turn on Wi-Fi."
                    : "Check the device's wireless switch or airplane mode."
                color: Theme.scheme.onSurfaceVariant
                font.pixelSize: 12
            }
        }

        Flickable {
            id: networkList

            anchors {
                fill: parent
                leftMargin: Metrics.listOuterInset
                rightMargin: Metrics.listOuterInset
                topMargin: Metrics.spacingSm
                bottomMargin: Metrics.spacingSm
            }
            visible: NetworkService.available
                && NetworkService.hasWifiDevice
                && NetworkService.wifiHardwareEnabled
                && NetworkService.wifiEnabled
            contentWidth: width
            contentHeight: networkColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: networkColumn

                width: networkList.width
                spacing: Metrics.spacingXs

                M3Text {
                    visible: NetworkService.lastError.length > 0
                    width: parent.width
                    height: visible ? Math.max(40, contentHeight + Metrics.spacingLg) : 0
                    leftPadding: Metrics.listSectionHeaderInset
                    rightPadding: Metrics.listItemInset
                    topPadding: Metrics.spacingSm
                    bottomPadding: Metrics.spacingSm
                    text: NetworkService.lastError
                    color: Theme.scheme.error
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    width: parent.width
                    height: 36

                    M3Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: Metrics.listSectionHeaderInset
                        text: "Available networks"
                        color: Theme.scheme.onSurfaceVariant
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                }

                Repeater {
                    model: NetworkService.wifiNetworks

                    delegate: WifiNetworkRow {}
                }

                M3Text {
                    visible: NetworkService.wifiNetworkCount === 0 && !NetworkService.scanning
                    width: parent.width
                    height: visible ? 52 : 0
                    text: "No Wi-Fi networks found"
                    color: Theme.scheme.onSurfaceVariant
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                AbstractButton {
                    id: addNetworkButton

                    width: parent.width
                    height: 48
                    enabled: !NetworkService.operationBusy
                    hoverEnabled: enabled
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: qsTr("Add network")
                    onClicked: {
                        if (root.controller)
                            root.controller.pushPage("wifi-add");
                    }

                    background: Rectangle {
                        radius: Metrics.radiusMd
                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.scheme.onSurface
                            opacity: addNetworkButton.down
                                ? Theme.statePressedOpacity
                                : addNetworkButton.hovered ? Theme.stateHoverOpacity : 0
                        }
                    }

                    contentItem: RowLayout {
                        spacing: Metrics.spacingMd

                        M3Icon {
                            Layout.leftMargin: Metrics.listItemInset
                            name: "add"
                            size: 20
                            color: Theme.scheme.onSurface
                        }

                        M3Text {
                            Layout.fillWidth: true
                            Layout.rightMargin: Metrics.listItemInset
                            text: "Add network"
                            color: Theme.scheme.onSurface
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                    }

                    HoverHandler {
                        cursorShape: addNetworkButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.scheme.outlineVariant
                    opacity: 0.55
                }

                AbstractButton {
                    id: savedNetworksButton

                    width: parent.width
                    height: 56
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: qsTr("Saved networks, %1 saved").arg(NetworkService.savedWifiNetworkCount)
                    onClicked: {
                        if (root.controller)
                            root.controller.pushPage("wifi-saved");
                    }

                    background: Rectangle {
                        radius: Metrics.radiusMd
                        color: "transparent"

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Theme.scheme.onSurface
                            opacity: savedNetworksButton.down
                                ? Theme.statePressedOpacity
                                : savedNetworksButton.hovered ? Theme.stateHoverOpacity : 0
                        }
                    }

                    contentItem: RowLayout {
                        spacing: Metrics.spacingMd

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: Metrics.listItemInset
                            spacing: 1

                            M3Text {
                                Layout.fillWidth: true
                                text: "Saved networks"
                                color: Theme.scheme.onSurface
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }

                            M3Text {
                                Layout.fillWidth: true
                                text: NetworkService.savedWifiNetworkCount === 1
                                    ? "1 network"
                                    : NetworkService.savedWifiNetworkCount + " networks"
                                color: Theme.scheme.onSurfaceVariant
                                font.pixelSize: 12
                            }
                        }

                        M3Icon {
                            Layout.rightMargin: Metrics.listItemInset
                            name: "chevron_forward"
                            size: 20
                            color: Theme.scheme.onSurfaceVariant
                        }
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

        }
    }

    Popup {
        id: passwordDialog

        parent: root
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: 300
        implicitHeight: passwordContent.implicitHeight + topPadding + bottomPadding
        padding: Metrics.spacingXl
        modal: true
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: {
            root.setKeyboardInputActive(true);
            Qt.callLater(() => passwordInput.forceActiveFocus());
        }
        onClosed: {
            passwordInput.clear();
            root.setKeyboardInputActive(false);
        }

        background: Rectangle {
            radius: Metrics.radiusLg
            color: Theme.scheme.surfaceContainerHigh
        }

        contentItem: ColumnLayout {
            id: passwordContent

            spacing: Metrics.spacingMd

            M3Text {
                Layout.fillWidth: true
                text: qsTr("Connect to %1").arg(root.credentialSsid)
                color: Theme.scheme.onSurface
                font.pixelSize: 16
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }

            M3Text {
                Layout.fillWidth: true
                text: NetworkService.securityLabel(root.credentialSecurity)
                color: Theme.scheme.onSurfaceVariant
                font.pixelSize: 12
            }

            M3OutlinedTextField {
                id: passwordInput

                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                maximumLength: 64
                onAccepted: connectButton.clicked()
            }

            M3Text {
                readonly property string validationMessage: NetworkService.validatePassword(root.credentialSecurity, passwordInput.text)

                visible: passwordInput.text.length > 0 && validationMessage.length > 0
                Layout.fillWidth: true
                text: validationMessage
                color: Theme.scheme.error
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Metrics.spacingMd

                M3Button {
                    text: "Cancel"
                    style: M3Button.Text
                    Layout.preferredHeight: 36
                    onClicked: passwordDialog.close()
                }

                M3Button {
                    id: connectButton

                    text: "Connect"
                    Layout.preferredHeight: 36
                    enabled: !NetworkService.operationBusy
                        && NetworkService.validatePassword(root.credentialSecurity, passwordInput.text).length === 0
                    onClicked: {
                        if (NetworkService.connectNetworkWithPassword(root.credentialNetworkId, passwordInput.text))
                            passwordDialog.close();
                    }
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
                text: qsTr("Forget %1?").arg(root.credentialSsid)
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
                        NetworkService.forgetNetwork(root.credentialNetworkId);
                    }
                }
            }
        }
    }
}
