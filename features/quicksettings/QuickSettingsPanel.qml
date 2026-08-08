import QtQuick
import QtQuick.Controls
import qs.components
import qs.features.quicksettings.pages
import qs.shell
import qs.theme

TransientPanelWindow {
    id: root

    property real panelWidth: 396
    property real maximumPanelHeight: 450

    open: SurfaceController.quickSettingsOpen
    targetScreen: SurfaceController.quickSettingsScreen
    transitionsEnabled: true
    readonly property Item activePage: navigationStack.currentItem
    readonly property real targetPanelWidth: root.activePage && root.activePage.implicitWidth > 0
        ? root.activePage.implicitWidth
        : root.panelWidth
    readonly property real targetPanelHeight: root.activePage && root.activePage.implicitHeight > 0
        ? Math.min(root.activePage.implicitHeight, root.maximumPanelHeight)
        : root.maximumPanelHeight

    color: "transparent"
    // Keep the input surface full-screen while open so clicks outside the
    // panel can dismiss it.
    // Keep the native layer surface stable. Animating its size causes a
    // Wayland configure and a full page relayout on every frame.
    implicitWidth: root.panelWidth
    implicitHeight: root.maximumPanelHeight
    onTransitionRequested: (entering, generation) => panelTransition.transition(entering, generation)

    // Reset only when the window lifecycle has actually ended. Keeping page
    // state independent from the requested open state prevents an eventual
    // exit transition from being relaid out underneath itself.
    onFullyClosed: navigationController.reset()

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    DismissibleOverlay {
        excludedItem: panelPresentation
        enabled: root.interactive
        onDismissed: SurfaceController.closeQuickSettings()
    }

    QuickSettingsController {
        id: navigationController

        screen: root.screen

        onPageRequested: page => {
            const component = root.componentForPage(page);
            if (component)
                navigationStack.push(component, {}, StackView.Immediate);
        }
        onBackRequested: {
            if (navigationStack.depth > 1)
                navigationStack.pop(null, StackView.Immediate);
        }
        onResetRequested: {
            if (navigationStack.depth > 1)
                navigationStack.pop(null, StackView.Immediate);
        }
    }

    function componentForPage(page: string): Component {
        switch (page) {
        case "audio":
            return audioPageComponent;
        case "brightness":
            return brightnessPageComponent;
        default:
            return null;
        }
    }

    Item {
        id: panelViewport

        anchors {
            top: parent.top
            right: parent.right
            topMargin: 6
            rightMargin: 6
        }
        width: root.targetPanelWidth
        height: root.targetPanelHeight
        clip: navigationStack.busy

        PresentationLayer {
            id: panelPresentation

            anchors.fill: parent

            StackView {
                id: navigationStack

                anchors.fill: parent
                initialItem: mainPageComponent

                // Navigation and lifecycle are now owned by StackView. Motion
                // can be added here later without changing page geometry.
                pushEnter: NoTransition {}
                pushExit: NoTransition {}
                popEnter: NoTransition {}
                popExit: NoTransition {}
            }
        }
    }

    SlideTransition {
        id: panelTransition

        target: panelPresentation
        hiddenOffsetY: -(panelViewport.height + panelViewport.anchors.topMargin + 5)
        onTransitionFinished: generation => root.completeTransition(generation)
    }

    component NoTransition: Transition {
        NumberAnimation { duration: 0 }
    }

    Component {
        id: mainPageComponent

        MainPage {
            controller: navigationController
        }
    }

    Component {
        id: audioPageComponent

        AudioPage {
            controller: navigationController
        }
    }

    Component {
        id: brightnessPageComponent

        BrightnessPage {
            controller: navigationController
        }
    }
}
