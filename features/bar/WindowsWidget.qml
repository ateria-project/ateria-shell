import QtQuick
import QtQuick.Controls
import Quickshell
import qs.components
import qs.platform.appicons
import qs.theme

Rectangle {
    id: root

    property var windows: null
    property var activeWindowId: null
    property bool useAppIcons: true
    readonly property var items: root.windows ?? []
    readonly property int activePosition: root.items.findIndex(window => {
        return root.activeWindowId !== null && Number(window.id) === Number(root.activeWindowId);
    })
    readonly property int cellWidth: 34
    readonly property int barHeight: 28
    readonly property int iconSourceSize: 36
    property int desktopEntriesRevision: 0

    function resolvedIconSource(appId: string, desktopIcon: string): string {
        const declaredSource = AppIconResolver.source(desktopIcon, root.iconSourceSize);
        if (declaredSource.length > 0)
            return declaredSource;

        return AppIconResolver.source(appId, root.iconSourceSize);
    }

    signal windowRequested(double windowId)

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            // Make bindings retry after Quickshell finishes its asynchronous desktop-entry scan.
            root.desktopEntriesRevision += 1;
        }
    }

    visible: root.items.length > 0
    implicitWidth: root.visible ? root.items.length * root.cellWidth : 0
    implicitHeight: root.barHeight
    radius: Metrics.radiusSm
    color: Theme.scheme.surfaceContainer

    Rectangle {
        id: activeIndicator

        readonly property bool urgent: root.activePosition >= 0 && Boolean(root.items[root.activePosition].urgent)

        visible: root.activePosition >= 0
        x: root.activePosition * root.cellWidth + (root.cellWidth - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 28
        radius: Metrics.radiusSm
        color: activeIndicator.urgent ? Theme.scheme.errorContainer : root.useAppIcons ? Theme.scheme.surfaceContainerHighest : Theme.scheme.primaryContainer

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

    Row {
        anchors.verticalCenter: parent.verticalCenter
        z: 1

        Repeater {
            model: root.items

            delegate: AbstractButton {
                id: control

                required property var modelData
                readonly property double windowId: Number(control.modelData.id)
                readonly property string appId: String(control.modelData.appId || "")
                readonly property string title: String(control.modelData.title || control.appId || qsTr("Window"))
                readonly property bool active: root.activeWindowId !== null && control.windowId === Number(root.activeWindowId)
                readonly property bool urgent: Boolean(control.modelData.urgent)
                readonly property var desktopEntry: {
                    root.desktopEntriesRevision;
                    return control.appId.length > 0 ? DesktopEntries.heuristicLookup(control.appId) : null;
                }
                readonly property string desktopIcon: control.desktopEntry ? String(control.desktopEntry.icon || "") : ""
                readonly property string displayName: control.desktopEntry ? String(control.desktopEntry.name || control.appId || control.title) : String(control.appId || control.title)
                readonly property string initial: control.displayName.length > 0 ? control.displayName.charAt(0).toUpperCase() : "?"
                readonly property string iconSource: root.useAppIcons ? root.resolvedIconSource(control.appId, control.desktopIcon) : ""

                Accessible.name: control.title
                focusPolicy: Qt.StrongFocus
                hoverEnabled: true
                implicitWidth: root.cellWidth
                implicitHeight: root.barHeight
                scale: control.down ? 0.82 : 1
                onClicked: root.windowRequested(control.windowId)

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                background: Rectangle {
                    anchors.centerIn: parent
                    width: 32
                    height: 28
                    radius: Metrics.radiusSm
                    color: control.urgent && !control.active ? Theme.scheme.errorContainer : Theme.scheme.onSurface
                    opacity: control.urgent && !control.active ? 1 : control.hovered && !control.active ? 0.08 : control.visualFocus && !control.active ? 0.14 : 0

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
                        source: control.iconSource
                        fillMode: Image.PreserveAspectFit
                        opacity: control.active ? 1 : 0.85
                        sourceSize.width: root.iconSourceSize
                        sourceSize.height: root.iconSourceSize
                        visible: control.iconSource.length > 0 && status !== Image.Error
                    }

                    M3Text {
                        anchors.centerIn: parent
                        visible: !appIcon.visible
                        text: control.initial
                        color: control.urgent ? Theme.scheme.onErrorContainer : control.active ? Theme.scheme.onPrimaryContainer : Theme.scheme.onSurface
                        opacity: control.active ? 1 : 0.85
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
