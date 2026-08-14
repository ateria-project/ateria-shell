import QtQuick
import Ateria.Bluetooth

Item {
    Component.onCompleted: {
        if (BluetoothAgent.ready)
            throw new Error("agent must not register before initialize()")
        if (BluetoothAgent.hasRequest)
            throw new Error("agent unexpectedly has a pairing request")
        if (BluetoothAgent.respond(true, ""))
            throw new Error("agent accepted a response without a request")
        Qt.quit()
    }
}
