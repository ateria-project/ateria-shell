pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.features.settings.components
import qs.platform.workspace
import qs.shell
import qs.theme

TransientPanelWindow {
    id: root

    property real panelWidth: 900
    property real panelHeight: 680
    property string currentNamespace: ""

    function showCategory(namespaceName: string) {
        if (namespaceName.length === 0 || namespaceName === root.currentNamespace)
            return;

        const category = settingsController.category(namespaceName);
        const properties = {
            settingsController,
            namespaceName,
            title: category.title,
            description: category.description
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
    transitionsEnabled: false
    implicitWidth: root.panelWidth
    implicitHeight: root.panelHeight
    color: "transparent"
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: root.interactive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "ateria-shell-settings"

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }

    onOpenChanged: {
        if (root.open) {
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

    IpcHandler {
        target: "settings"

        function open(): void {
            SurfaceController.openSettings(root.fallbackScreen);
        }

        function close(): void {
            SurfaceController.closeSettings();
        }

        function toggle(): void {
            SurfaceController.toggleSettings(root.fallbackScreen);
        }
    }

    // Scrim backdrop
    Rectangle {
        anchors.fill: parent
        color: Theme.scheme.scrim
        opacity: 0.32
    }

    DismissibleOverlay {
        excludedItem: windowFrame
        enabled: root.interactive
        onDismissed: SurfaceController.closeSettings()
    }

    Rectangle {
        id: windowFrame

        anchors.centerIn: parent
        width: Math.min(root.panelWidth, Math.max(480, root.width - 48))
        height: Math.min(root.panelHeight, Math.max(360, root.height - 48))
        radius: Metrics.radiusXl
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

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header bar
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                Layout.leftMargin: Metrics.spacingXl
                Layout.rightMargin: Metrics.spacingMd
                spacing: Metrics.spacingSm

                M3Text {
                    Layout.fillWidth: true
                    text: qsTr("Settings")
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    color: Theme.scheme.onSurface
                }

                M3Button {
                    style: M3Button.Text
                    iconName: "close"
                    iconSize: 22
                    contentColor: Theme.scheme.onSurfaceVariant
                    Accessible.name: qsTr("Close settings")
                    onClicked: SurfaceController.closeSettings()
                }
            }

            // Header divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.scheme.outlineVariant
                opacity: 0.5
            }

            // Main content split
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // Navigation sidebar
                Item {
                    Layout.preferredWidth: 280
                    Layout.fillHeight: true

                    SettingsNavigation {
                        id: navigation

                        anchors {
                            fill: parent
                            margins: Metrics.spacingMd
                        }
                        settingsController: settingsController
                    }
                }

                // Vertical divider
                Rectangle {
                    Layout.fillHeight: true
                    Layout.topMargin: Metrics.spacingSm
                    Layout.bottomMargin: Metrics.spacingSm
                    width: 1
                    color: Theme.scheme.outlineVariant
                    opacity: 0.5
                }

                // Content area
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
        onActivated: SurfaceController.closeSettings()
    }
}
