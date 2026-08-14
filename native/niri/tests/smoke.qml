import QtQuick
import Ateria.Niri

Item {
    Component.onCompleted: {
        console.log("Ateria.Niri loaded",
                    "available=" + NiriIpc.available,
                    "connected=" + NiriIpc.connected)
        Qt.quit()
    }
}
