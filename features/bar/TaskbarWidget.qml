import QtQuick
import QtQuick.Controls
import Quickshell
import qs.components
import qs.platform.compositor
import qs.platform.appicons
import qs.theme

Item {
    id: root

    property var workspaces: null
    property var activeWindowId: null
    property bool useAppIcons: true
    property bool showWorkspaceNumbers: true

    readonly property int workspaceWidth: 30
    readonly property int windowWidth: 34
    readonly property int barHeight: 28
    readonly property int activeIndicatorWidth: 32
    readonly property int iconSourceSize: 36

    property int desktopEntriesRevision: 0

    // Group the compositor window list once per update instead of filtering it
    // independently in every workspace delegate and indicator binding.
    readonly property var emptyWindows: []
    readonly property var windowsByWorkspace: {
        const grouped = {};
        const windows = NiriService.windows ?? [];

        for (let i = 0; i < windows.length; ++i) {
            const windowData = windows[i];
            const workspaceId = Number(windowData.workspaceId);

            if (workspaceId < 1)
                continue;

            const key = String(workspaceId);
            let bucket = grouped[key];

            if (bucket === undefined) {
                bucket = [];
                grouped[key] = bucket;
            }

            bucket.push(windowData);
        }

        for (const key in grouped) {
            grouped[key].sort((left, right) => {
                const leftPosition = left.layoutPosition;
                const rightPosition = right.layoutPosition;
                if (leftPosition === null && rightPosition === null)
                    return Number(left.id) - Number(right.id);
                if (leftPosition === null)
                    return 1;
                if (rightPosition === null)
                    return -1;
                if (Number(leftPosition[0]) !== Number(rightPosition[0]))
                    return Number(leftPosition[0]) - Number(rightPosition[0]);
                return Number(leftPosition[1]) - Number(rightPosition[1]);
            });
        }

        return grouped;
    }

    // Cache each window's horizontal indicator position. The object is rebuilt
    // only when workspace/window layout inputs change; active-window changes
    // then become a constant-time lookup.
    readonly property var windowLayoutById: {
        const layoutById = {};
        const workspaceList = root.workspaces ?? [];
        let currentX = 0;

        for (let i = 0; i < workspaceList.length; ++i) {
            const workspaceId = Number(workspaceList[i].id);
            const windows = root.windowsForWorkspace(workspaceId);
            const pillVisible = root.showWorkspaceNumbers || windows.length === 0;

            for (let j = 0; j < windows.length; ++j) {
                const windowData = windows[j];
                const key = root.windowKey(windowData.id);

                layoutById[key] = {
                    windowData: windowData,
                    x: currentX + (pillVisible ? root.workspaceWidth + Metrics.spacingXs : 0) + j * root.windowWidth + (root.windowWidth - root.activeIndicatorWidth) / 2
                };
            }

            currentX += (pillVisible ? root.workspaceWidth : 0) + (windows.length > 0 ? (pillVisible ? Metrics.spacingXs : 0) + windows.length * root.windowWidth : 0) + Metrics.spacingSm;
        }

        return layoutById;
    }

    readonly property var normalizedActiveWindowId: {
        return root.activeWindowId === null || root.activeWindowId === undefined ? null : Number(root.activeWindowId);
    }

    readonly property var activeWindowInfo: {
        if (root.normalizedActiveWindowId === null)
            return {
                found: false,
                x: 0,
                urgent: false
            };

        const layout = root.windowLayoutById[root.windowKey(root.normalizedActiveWindowId)];

        if (layout === undefined)
            return {
                found: false,
                x: 0,
                urgent: false
            };

        return {
            found: true,
            x: layout.x,
            urgent: Boolean(layout.windowData.urgent)
        };
    }

    visible: (root.workspaces ?? []).length > 0
    implicitHeight: root.barHeight
    implicitWidth: contentRow.implicitWidth

    signal workspaceRequested(int workspaceIndex)
    signal windowRequested(double windowId)

    function windowKey(windowId) {
        return "id:" + String(Number(windowId));
    }

    function windowsForWorkspace(workspaceId) {
        if (workspaceId < 1)
            return root.emptyWindows;

        return root.windowsByWorkspace[String(workspaceId)] ?? root.emptyWindows;
    }

    function resolvedIconSource(appId, desktopIcon) {
        const declaredSource = AppIconResolver.source(desktopIcon, root.iconSourceSize);
        return declaredSource.length > 0 ? declaredSource : AppIconResolver.source(appId, root.iconSourceSize);
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            ++root.desktopEntriesRevision;
        }
    }

    // Layer 1: pill backgrounds
    Row {
        id: bgRow

        anchors.fill: parent
        spacing: Metrics.spacingSm

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Motion.durationMedium
                easing.type: Motion.easingStandard
                easing.bezierCurve: Motion.standardCurve
            }
        }

        Repeater {
            model: root.workspaces ?? []

            delegate: Rectangle {
                required property var modelData

                readonly property int workspaceId: Number(modelData.id)
                readonly property int windowCount: root.windowsForWorkspace(workspaceId).length
                readonly property bool pillVisible: root.showWorkspaceNumbers || windowCount === 0

                visible: true
                width: (pillVisible ? root.workspaceWidth : 0) + (windowCount > 0 ? (pillVisible ? Metrics.spacingXs : 0) + windowCount * root.windowWidth : 0)
                height: root.barHeight
                radius: Metrics.radiusFull
                color: Theme.scheme.surfaceContainer

                Behavior on width {
                    NumberAnimation {
                        duration: Motion.durationMedium
                        easing.type: Motion.easingStandard
                        easing.bezierCurve: Motion.standardCurve
                    }
                }
            }
        }
    }

    // Layer 2: sliding active-window indicator
    Rectangle {
        id: activeWindowIndicator

        visible: root.activeWindowInfo.found
        x: root.activeWindowInfo.x
        anchors.verticalCenter: parent.verticalCenter
        width: root.activeIndicatorWidth
        height: root.barHeight
        radius: Metrics.radiusSm
        color: root.activeWindowInfo.urgent ? Theme.scheme.errorContainer : (root.useAppIcons ? Theme.scheme.surfaceContainerHighest : Theme.scheme.primaryContainer)

        Behavior on x {
            NumberAnimation {
                duration: Motion.durationLong
                easing.type: Motion.easingEmphasized
                easing.bezierCurve: Motion.emphasizedCurve
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Motion.durationShort
            }
        }
    }

    // Layer 3: interactive content
    Row {
        id: contentRow

        spacing: Metrics.spacingSm

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Motion.durationMedium
                easing.type: Motion.easingStandard
                easing.bezierCurve: Motion.standardCurve
            }
        }

        Repeater {
            model: root.workspaces ?? []

            delegate: Row {
                id: workspaceRow

                required property var modelData

                readonly property bool active: Boolean(modelData.active)
                readonly property bool occupied: Boolean(modelData.occupied)
                readonly property bool urgent: Boolean(modelData.urgent)
                readonly property int workspaceIndex: Number(modelData.index)
                readonly property int workspaceId: Number(modelData.id)
                readonly property var workspaceWindows: root.windowsForWorkspace(workspaceId)
                readonly property int windowCount: workspaceRow.workspaceWindows.length
                readonly property bool pillVisible: root.showWorkspaceNumbers || workspaceRow.windowCount === 0

                visible: true
                spacing: Metrics.spacingXs

                // Workspace button
                AbstractButton {
                    id: workspaceControl

                    visible: workspaceRow.pillVisible
                    Accessible.name: qsTr("Workspace %1").arg(workspaceRow.workspaceIndex)
                    focusPolicy: Qt.StrongFocus
                    hoverEnabled: true
                    implicitWidth: root.workspaceWidth
                    implicitHeight: root.barHeight
                    scale: down ? 0.82 : 1

                    onClicked: root.workspaceRequested(workspaceRow.workspaceIndex)

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    background: Item {
                        Rectangle {
                            anchors.fill: parent
                            radius: Metrics.radiusFull
                            color: workspaceRow.active ? Theme.scheme.primary : (workspaceRow.occupied ? Theme.scheme.surfaceContainerHigh : "transparent")

                            Behavior on color {
                                ColorAnimation {
                                    duration: Motion.durationShort
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Metrics.radiusFull
                            color: Theme.scheme.onSurface
                            opacity: !workspaceRow.active && workspaceControl.hovered ? 0.08 : (!workspaceRow.active && workspaceControl.visualFocus ? 0.14 : 0)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Motion.durationShort
                                }
                            }
                        }
                    }

                    contentItem: Item {
                        M3Text {
                            anchors.centerIn: parent
                            text: String(workspaceRow.workspaceIndex)
                            color: workspaceRow.active ? (workspaceRow.urgent ? Theme.scheme.onError : Theme.scheme.onPrimary) : (workspaceRow.urgent ? Theme.scheme.error : Theme.scheme.onSurfaceVariant)
                            opacity: workspaceRow.active ? 1 : (workspaceRow.occupied ? 0.85 : 0.6)
                            font.family: Typography.monoFamily
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Motion.durationShort
                            easing.type: Motion.easingStandard
                            easing.bezierCurve: Motion.standardCurve
                        }
                    }
                }

                // Windows for this workspace. Hiding an empty row prevents the
                // parent Row from adding spacing after an unoccupied workspace.
                Row {
                    id: windowsRow

                    visible: workspaceRow.workspaceWindows.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Repeater {
                        model: workspaceRow.workspaceWindows

                        delegate: AbstractButton {
                            id: windowControl

                            required property var modelData

                            readonly property double windowId: Number(modelData.id)
                            readonly property string appId: String(modelData.appId || "")
                            readonly property string title: String(modelData.title || appId || qsTr("Window"))
                            readonly property bool windowActive: root.normalizedActiveWindowId !== null && windowId === root.normalizedActiveWindowId
                            readonly property bool windowUrgent: Boolean(modelData.urgent)
                            readonly property var desktopEntry: {
                                // Explicit dependency so lookups refresh when the
                                // desktop-entry database changes.
                                root.desktopEntriesRevision;
                                return appId.length > 0 ? DesktopEntries.heuristicLookup(appId) : null;
                            }
                            readonly property string desktopIcon: desktopEntry ? String(desktopEntry.icon || "") : ""
                            readonly property string displayName: desktopEntry ? String(desktopEntry.name || appId || title) : String(appId || title)
                            readonly property string initial: displayName.length > 0 ? displayName.charAt(0).toUpperCase() : "?"
                            readonly property string iconSource: root.useAppIcons ? root.resolvedIconSource(appId, desktopIcon) : ""

                            Accessible.name: title
                            focusPolicy: Qt.StrongFocus
                            hoverEnabled: true
                            implicitWidth: root.windowWidth
                            implicitHeight: root.barHeight
                            scale: down ? 0.82 : 1

                            onClicked: root.windowRequested(windowId)

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }

                            background: Rectangle {
                                anchors.centerIn: parent
                                width: root.activeIndicatorWidth
                                height: root.barHeight
                                radius: Metrics.radiusSm
                                color: windowControl.windowUrgent && !windowControl.windowActive ? Theme.scheme.errorContainer : Theme.scheme.onSurface
                                opacity: windowControl.windowUrgent && !windowControl.windowActive ? 1 : (windowControl.hovered && !windowControl.windowActive ? 0.08 : (windowControl.visualFocus && !windowControl.windowActive ? 0.14 : 0))

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Motion.durationShort
                                    }
                                }
                            }

                            contentItem: Item {
                                Image {
                                    id: appIcon

                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    source: windowControl.iconSource
                                    sourceSize.width: root.iconSourceSize
                                    sourceSize.height: root.iconSourceSize
                                    fillMode: Image.PreserveAspectFit
                                    opacity: windowControl.windowActive ? 1 : 0.85
                                    visible: windowControl.iconSource.length > 0 && status !== Image.Error
                                }

                                M3Text {
                                    anchors.centerIn: parent
                                    visible: !appIcon.visible
                                    text: windowControl.initial
                                    color: windowControl.windowUrgent ? Theme.scheme.onErrorContainer : (windowControl.windowActive ? Theme.scheme.onPrimaryContainer : Theme.scheme.onSurface)
                                    opacity: windowControl.windowActive ? 1 : 0.85
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Motion.durationShort
                                    easing.type: Motion.easingStandard
                                    easing.bezierCurve: Motion.standardCurve
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
