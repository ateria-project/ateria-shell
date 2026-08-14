import QtQuick
import Ateria.Network

Item {
    Connections {
        target: WifiManager

        function onNetworkAutoconnectChanged(networkId: string, enabled: bool) {
            console.log("Auto-connect changed", networkId, enabled);
        }
    }

    Component.onCompleted: {
        console.log("Ateria.Network loaded",
            "available=" + WifiManager.available,
            "devices=" + WifiManager.wifiDevices.length,
            "networks=" + WifiManager.networks.count,
            "saved=" + WifiManager.savedNetworks.count);
        Qt.quit();
    }
}
