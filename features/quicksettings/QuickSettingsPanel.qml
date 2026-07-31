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
        for (let i = 0; i < root.contentItem.children.length; ++i) {
            const child = root.contentItem.children[i];
            if (child !== controller && child.visible)
                return child;
        }
        return mainPage;
    }

    color: "transparent"
    implicitWidth: {
        const page = root.activePage;
        return (page && page.implicitWidth > 0) ? page.implicitWidth : mainPage.implicitWidth;
    }
    implicitHeight: {
        const page = root.activePage;
        return (page && page.implicitHeight > 0) ? page.implicitHeight : mainPage.implicitHeight;
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Motion.durationMedium
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Motion.durationMedium
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
        }
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
