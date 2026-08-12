pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Wayland
import qs.components
import qs.features.settings.components
import qs.platform.workspace
import qs.shell
import qs.theme

TransientPanelWindow {
    id: root

    readonly property int panelWidth: 960
    readonly property int panelHeight: 720
    readonly property int sidebarWidth: 300
    readonly property int panelRadius: 16
    property string currentNamespace: ""

    function showCategory(namespaceName: string) {
        if (namespaceName.length === 0 || namespaceName === root.currentNamespace)
            return;

        const properties = {
            settingsController,
            namespaceName
        };

        if (pageStack.depth === 0)
            pageStack.push(settingsPageComponent, properties, StackView.Immediate);
        else
            pageStack.replace(settingsPageComponent, properties, StackView.Immediate);

        root.currentNamespace = namespaceName;
    }

    open: SurfaceController.settingsOpen
    targetScreen: SurfaceController.settingsScreen
    fallbackScreen: SurfaceController.preferredScreen(WorkspaceService.focusedOutputName)
    transitionsEnabled: true
    implicitWidth: root.panelWidth
    implicitHeight: root.panelHeight
    color: "transparent"
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: root.interactive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "ateria-shell-settings"
    onTransitionRequested: (entering, generation) => panelTransition.transition(entering, generation)

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    onOpenChanged: {
        if (root.open) {
            const currentPage = pageStack.currentItem;
            if (currentPage && currentPage.listEditorOpen)
                currentPage.closeListEditor();
            settingsController.ensureSelection();
            root.showCategory(settingsController.selectedNamespace);
        }
    }

    Component.onCompleted: {
        settingsController.ensureSelection();
        root.showCategory(settingsController.selectedNamespace);
    }

    SettingsController {
        id: settingsController
    }

    Connections {
        target: settingsController

        function onSelectedNamespaceChanged() {
            root.showCategory(settingsController.selectedNamespace);
        }
    }

    // Scrim backdrop
    Rectangle {
        anchors.fill: parent
        color: Theme.scheme.scrim
        opacity: 0.32 * panelTransition.progress
    }

    DismissibleOverlay {
        excludedItem: panelPresentation
        enabled: root.interactive
        onDismissed: SurfaceController.closeSettings()
    }

    PresentationLayer {
        id: panelPresentation

        anchors.centerIn: parent
        width: Math.min(root.panelWidth, Math.max(480, root.width - Metrics.spacingLg * 2))
        height: Math.min(root.panelHeight, Math.max(360, root.height - Metrics.spacingLg * 2))

        Rectangle {
            id: windowFrame

            anchors.fill: parent
            radius: root.panelRadius
                + 12 * (1 - Math.max(0, Math.min(1, panelTransition.spatialProgress)))
            color: Theme.scheme.surfaceContainerLow
            clip: true

            // Outer keyline for depth
            Rectangle {
                anchors.fill: parent
                z: 100
                color: "transparent"
                radius: parent.radius
                antialiasing: true
                border.width: Theme.panelBorderWidth
                border.color: Theme.panelOuterKeyline
            }

            // Inner highlight
            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.panelInnerBorderInset
                z: 101
                color: "transparent"
                radius: Math.max(0, parent.radius - Theme.panelInnerBorderInset)
                antialiasing: true
                border.width: Theme.panelBorderWidth
                border.color: Theme.panelInnerHighlight
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.preferredWidth: root.sidebarWidth
                    Layout.fillHeight: true
                    color: Theme.scheme.surfaceContainer
                    topLeftRadius: windowFrame.radius
                    bottomLeftRadius: windowFrame.radius
                    antialiasing: true

                    SettingsNavigation {
                        anchors {
                            fill: parent
                            margins: Metrics.spacingLg
                        }
                        settingsController: settingsController
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    StackView {
                        id: pageStack

                        anchors.fill: parent
                    }
                }
            }
        }
    }

    Component {
        id: settingsPageComponent

        SettingsPage {}
    }

    Shortcut {
        enabled: root.interactive
        sequences: [StandardKey.Cancel]
        onActivated: {
            const currentPage = pageStack.currentItem;
            if (currentPage && currentPage.listEditorOpen)
                currentPage.closeListEditor();
            else
                SurfaceController.closeSettings();
        }
    }

    ScaleFadeTransition {
        id: panelTransition

        target: panelPresentation
        onTransitionFinished: generation => root.completeTransition(generation)
    }
}
