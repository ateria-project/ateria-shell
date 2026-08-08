import QtQuick
import Quickshell
import qs.features.notifications.components
import qs.platform.workspace
import qs.theme
import "workspace"
import "workspace/WorkspaceLayout.js" as WorkspaceLayout

PanelWindow {
    id: window

    readonly property string outputName: window.screen ? window.screen.name : ""
    readonly property int workspacePageSize: 9
    readonly property var workspaceView: WorkspaceService.viewForOutput(
        window.outputName,
        window.workspacePageSize
    )
    readonly property var workspaceLayout: WorkspaceLayout.build(
        window.workspaceView,
        BarSettings.showWorkspaceNumbers,
        Metrics.spacingXs,
        Metrics.spacingSm
    )

    readonly property bool useGroupedTaskbar: {
        if (!BarSettings.combineWorkspacesAndWindows)
            return false;

        const availableSpace = (window.width - clockWidget.width) / 2 - 24;
        const requiredSpace = launcher.width + leftContainer.spacing + window.workspaceLayout.totalWidth;
        return requiredSpace <= availableSpace;
    }

    implicitHeight: 38
    color: Theme.scheme.surface

    anchors {
        top: true
        left: true
        right: true
    }

    Row {
        id: leftContainer
        spacing: Metrics.spacingXs

        anchors {
            left: parent.left
            leftMargin: 6
            verticalCenter: parent.verticalCenter
        }

        LauncherButton {
            id: launcher
            screen: window.screen
        }

        WallpaperSwitcherButton {
            id: wallpaperSwitcherBtn
            screen: window.screen
        }

        Loader {
            id: taskArea

            anchors.verticalCenter: parent.verticalCenter
            asynchronous: false
            sourceComponent: window.useGroupedTaskbar ? groupedTaskbarComponent : splitTaskbarComponent
        }
    }

    Component {
        id: groupedTaskbarComponent

        TaskbarWidget {
            view: window.workspaceView
            layoutData: window.workspaceLayout
            useAppIcons: BarSettings.useAppIcons
            showWorkspaceNumbers: BarSettings.showWorkspaceNumbers
            onWorkspaceRequested: workspaceIndex => WorkspaceService.focusWorkspace(workspaceIndex, window.outputName)
            onWindowRequested: windowId => WorkspaceService.focusWindow(windowId)
        }
    }

    Component {
        id: splitTaskbarComponent

        Row {
            spacing: Metrics.spacingXs

            WorkspacesWidget {
                view: window.workspaceView
                showWorkspaceNumbersOnHover: BarSettings.showWorkspaceNumbersOnHover
                onWorkspaceRequested: workspaceIndex => WorkspaceService.focusWorkspace(workspaceIndex, window.outputName)
            }

            WindowsWidget {
                view: window.workspaceView
                useAppIcons: BarSettings.useAppIcons
                onWindowRequested: windowId => WorkspaceService.focusWindow(windowId)
            }
        }
    }

    ClockWidget {
        id: clockWidget
        anchors.centerIn: parent
        screen: window.screen
    }

    Row {
        spacing: Metrics.spacingXs

        anchors {
            right: parent.right
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }

        NotificationIndicator {
            anchors.verticalCenter: parent.verticalCenter
            screen: window.screen
        }

        MediaWidget {
            anchors.verticalCenter: parent.verticalCenter
        }

        StatusArea {
            anchors.verticalCenter: parent.verticalCenter
            screen: window.screen
            hasBattery: true
        }
    }
}
