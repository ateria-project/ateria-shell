import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell.Wayland
import qs.components
import qs.features.bluetooth
import qs.features.quicksettings.pages
import qs.platform.bluetooth
import qs.shell
import qs.theme

TransientPanelWindow {
    id: root

    property real panelWidth: 396
    property real maximumPanelHeight: 450
    property real _pageTravelDistance: panelWidth

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
    WlrLayershell.keyboardFocus: root.interactive
        && (navigationController.keyboardInputActive
            || (BluetoothPairingController.useInlinePrompt
                && (BluetoothService.pairingRequest?.type === "pinCode" || BluetoothService.pairingRequest?.type === "passkey")))
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
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
            if (component && !navigationStack.busy) {
                root._pageTravelDistance = panelViewport.width;
                navigationStack.push(component, {}, StackView.PushTransition);
            }
        }
        onBackRequested: {
            if (navigationStack.depth > 1 && !navigationStack.busy) {
                root._pageTravelDistance = panelViewport.width;
                navigationStack.pop(null, StackView.PopTransition);
            }
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
        case "bluetooth":
            return bluetoothPageComponent;
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
        readonly property bool roundedClipActive: navigationStack.busy
            || panelWidthAnimation.running
            || panelHeightAnimation.running

        layer.enabled: panelViewport.roundedClipActive
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: panelMask
        }

        Behavior on width {
            PanelResizeAnimation { id: panelWidthAnimation }
        }

        Behavior on height {
            PanelResizeAnimation { id: panelHeightAnimation }
        }

        PresentationLayer {
            id: panelPresentation

            anchors.fill: parent

            StackView {
                id: navigationStack

                anchors.fill: parent
                initialItem: mainPageComponent

                pushEnter: PageTransition {
                    fromX: root._pageTravelDistance
                    toX: 0
                }
                pushExit: PageTransition {
                    fromX: 0
                    toX: -root._pageTravelDistance
                }
                popEnter: PageTransition {
                    fromX: -root._pageTravelDistance
                    toX: 0
                }
                popExit: PageTransition {
                    fromX: 0
                    toX: root._pageTravelDistance
                }
            }
        }
    }

    Rectangle {
        id: panelMask

        anchors.fill: panelViewport
        radius: 16
        color: "black"
        antialiasing: true
        visible: false
        layer.enabled: panelViewport.roundedClipActive
    }

    SlideTransition {
        id: panelTransition

        target: panelPresentation
        hiddenOffsetY: -(panelViewport.height + panelViewport.anchors.topMargin + 5)
        onTransitionFinished: generation => root.completeTransition(generation)
    }

    component PageTransition: Transition {
        id: pageTransition

        required property real fromX
        required property real toX

        NumberAnimation {
            property: "x"
            from: pageTransition.fromX
            to: pageTransition.toX
            duration: Motion.durationPageTransition
            easing.type: Motion.easingExpressiveSpatial
            easing.bezierCurve: Motion.expressiveGentleSpatialCurve
        }
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

    Component {
        id: bluetoothPageComponent

        BluetoothPage {
            controller: navigationController
        }
    }
}
