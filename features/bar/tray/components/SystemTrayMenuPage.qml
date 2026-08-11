pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import qs.components
import qs.theme

Item {
    id: root

    required property bool submenu
    required property string title
    required property int menuWidth
    required property int menuPadding
    required property int maximumHeight

    property var initialMenuHandle: null
    property SystemTrayMenuPage parentPage: null
    property string entryKey: ""
    property int entryOccurrence: 0

    readonly property var resolvedMenuHandle: root.parentPage === null
        ? root.initialMenuHandle
        : root.parentPage.findEntry(root.entryKey, root.entryOccurrence)

    signal backRequested
    signal entryActivated(var entry)

    // DBus menu providers may replace entry objects during a refresh.
    // Resolve submenu routes through the live parent model instead.
    function keyForEntry(entry): string {
        return String(entry?.text || "");
    }

    function occurrenceForEntry(entry): int {
        const entries = menuOpener.children.values || [];
        const key = root.keyForEntry(entry);
        let occurrence = 0;

        for (let index = 0; index < entries.length; ++index) {
            const candidate = entries[index];
            if (candidate === entry)
                return occurrence;
            if (root.keyForEntry(candidate) === key)
                ++occurrence;
        }

        return 0;
    }

    function findEntry(key, occurrence) {
        const entries = menuOpener.children.values || [];
        let currentOccurrence = 0;

        for (let index = 0; index < entries.length; ++index) {
            const candidate = entries[index];
            if (root.keyForEntry(candidate) !== key)
                continue;
            if (currentOccurrence === occurrence)
                return candidate;
            ++currentOccurrence;
        }

        return null;
    }

    implicitWidth: root.menuWidth
    implicitHeight: Math.min(root.maximumHeight, menuColumn.implicitHeight + root.menuPadding * 2)

    QsMenuOpener {
        id: menuOpener

        menu: root.resolvedMenuHandle
    }

    Flickable {
        id: viewport

        anchors.fill: parent
        contentWidth: width
        contentHeight: menuColumn.implicitHeight + root.menuPadding * 2
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        clip: true

        Column {
            id: menuColumn

            x: root.menuPadding
            y: root.menuPadding
            width: viewport.width - root.menuPadding * 2
            spacing: 0

            AbstractButton {
                id: backButton

                visible: root.submenu
                width: parent.width
                implicitHeight: visible ? 32 : 0
                focusPolicy: Qt.StrongFocus
                hoverEnabled: true
                leftPadding: 6
                rightPadding: 6
                onClicked: root.backRequested()

                Accessible.name: qsTr("Back")

                background: Rectangle {
                    radius: 6
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Theme.scheme.onSurface
                        opacity: backButton.down
                            ? Theme.statePressedOpacity
                            : backButton.hovered
                                ? Theme.stateHoverOpacity
                                : backButton.visualFocus
                                    ? Theme.stateFocusOpacity
                                    : 0
                    }
                }

                contentItem: Row {
                    spacing: 6

                    M3Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "arrow_back"
                        size: 16
                        color: Theme.scheme.onSurfaceVariant
                    }

                    M3Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: backButton.availableWidth - 22
                        text: root.title
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        color: Theme.scheme.onSurface
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }

            Rectangle {
                visible: root.submenu
                width: parent.width
                implicitHeight: visible ? 5 : 0
                color: "transparent"

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: 1
                    color: Theme.scheme.outlineVariant
                    opacity: 0.6
                }
            }

            Repeater {
                model: menuOpener.children

                delegate: SystemTrayMenuItem {
                    required property var modelData

                    width: menuColumn.width
                    entry: modelData
                    onActivated: root.entryActivated(modelData)
                }
            }
        }

        ScrollBar.vertical: M3ScrollBar {
            policy: viewport.interactive ? M3ScrollBar.AsNeeded : M3ScrollBar.AlwaysOff
        }
    }
}
