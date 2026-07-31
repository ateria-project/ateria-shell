import QtQuick
import Quickshell
import qs.components
import qs.features.quicksettings.pages
import qs.shell
import qs.theme

PanelWindow {
    id: root

    property bool open: SurfaceController.quickSettingsOpen

    screen: SurfaceController.activeScreen
    visible: open
    color: "transparent"
    implicitWidth: 300
    implicitHeight: 200
    onOpenChanged: {
        if (!open)
            controller.reset();
    }

    anchors {
        top: true
        right: true
    }

    margins {
        top: 6
        right: 6
    }

    QuickSettingsController {
        id: controller
    }

    MainPage {
        anchors.fill: parent
        controller: controller
    }
}
