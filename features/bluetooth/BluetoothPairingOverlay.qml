pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.platform.bluetooth
import qs.platform.workspace
import qs.shell
import qs.theme

TransientPanelWindow {
    id: root

    readonly property var request: BluetoothService.pairingRequest
    readonly property bool inputRequired: root.request?.type === "pinCode" || root.request?.type === "passkey"

    open: BluetoothService.hasPairingRequest && !BluetoothPairingController.useInlinePrompt
    fallbackScreen: SurfaceController.preferredScreen(WorkspaceService.focusedOutputName)
    implicitWidth: 380
    implicitHeight: pairingCard.implicitHeight
    color: "transparent"
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: root.interactive && root.inputRequired ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    interactiveMask: Region {
        item: pairingCard
    }

    anchors {
        top: true
        right: true
    }

    margins {
        top: Metrics.spacingSm
        right: Metrics.spacingMd
    }

    M3Panel {
        id: pairingCard

        width: root.implicitWidth
        implicitHeight: pairingPrompt.implicitHeight + Metrics.spacingXl * 2

        BluetoothPairingPrompt {
            id: pairingPrompt

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Metrics.spacingXl
            }
            request: root.request ?? ({})
        }
    }
}
