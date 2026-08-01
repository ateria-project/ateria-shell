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
    readonly property Item activePage: {
        if (controller.currentPage === "main")
            return mainPage;
        if (controller.currentPage === "audio")
            return audioPage;
        if (controller.currentPage === "brightness")
            return brightnessPage;
        for (let i = 0; i < panelViewport.children.length; ++i) {
            const child = panelViewport.children[i];
            if (child.visible)
                return child;
        }
        return mainPage;
    }
    readonly property real targetPanelWidth: root.activePage && root.activePage.implicitWidth > 0 ? root.activePage.implicitWidth : mainPage.implicitWidth
    readonly property real targetPanelHeight: root.activePage && root.activePage.implicitHeight > 0 ? root.activePage.implicitHeight : mainPage.implicitHeight

    color: "transparent"
    // Keep the native layer surface stable. Animating its size causes a
    // Wayland configure and a full page relayout on every frame.
    implicitWidth: Math.max(mainPage.implicitWidth, audioPage.implicitWidth, brightnessPage.implicitWidth)
    implicitHeight: Math.max(mainPage.implicitHeight, audioPage.implicitHeight, brightnessPage.implicitHeight)
    mask: Region {
        item: panelViewport
    }

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

    Item {
        id: panelViewport

        anchors {
            top: parent.top
            right: parent.right
        }
        width: root.targetPanelWidth
        height: root.targetPanelHeight
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Motion.durationMedium
                easing.type: Motion.easingEmphasized
                easing.bezierCurve: Motion.emphasizedCurve
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Motion.durationMedium
                easing.type: Motion.easingEmphasized
                easing.bezierCurve: Motion.emphasizedCurve
            }
        }

        MainPage {
            id: mainPage

            anchors.fill: parent
            visible: controller.currentPage === "main"
            controller: controller
        }

        AudioPage {
            id: audioPage

            anchors.fill: parent
            visible: controller.currentPage === "audio"
            controller: controller
        }

        BrightnessPage {
            id: brightnessPage

            anchors.fill: parent
            visible: controller.currentPage === "brightness"
            controller: controller
        }
    }
}
