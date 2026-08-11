pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import qs.components
import qs.theme
import "components"

PopupWindow {
    id: root

    required property Item anchorItem

    property var menuHandle: null
    property bool openPending: false
    property int openGeneration: 0
    property bool pageReleasePending: false

    readonly property int menuWidth: 208
    readonly property int menuPadding: Metrics.spacingXs
    readonly property int maximumHeight: root.screen ? Math.min(480, Math.max(128, root.screen.height - 64)) : 480
    readonly property real pageHeight: menuStack.currentItem ? menuStack.currentItem.implicitHeight : 1

    function toggleMenu(menuHandle): void {
        if (root.menuHandle === menuHandle && (root.visible || root.openPending)) {
            root.closeMenu();
            return;
        }

        root.openMenu(menuHandle);
    }

    function openMenu(menuHandle): void {
        if (menuHandle === null || menuHandle === undefined)
            return;

        const generation = ++root.openGeneration;
        root.openPending = true;
        root.menuHandle = menuHandle;

        menuStack.clear(StackView.Immediate);
        menuStack.push(menuPageComponent, {
            initialMenuHandle: menuHandle,
            submenu: false,
            title: ""
        }, StackView.Immediate);

        Qt.callLater(() => {
            if (generation !== root.openGeneration || !root.openPending || menuStack.depth === 0)
                return;

            root.anchor.updateAnchor();
            root.visible = true;
            root.openPending = false;
        });
    }

    function releasePagesLater(): void {
        if (root.pageReleasePending)
            return;

        root.pageReleasePending = true;
        Qt.callLater(() => {
            root.pageReleasePending = false;
            if (!root.visible && !root.openPending)
                menuStack.clear(StackView.Immediate);
        });
    }

    function closeMenu(): void {
        if (!root.visible && !root.openPending && menuStack.depth === 0)
            return;

        ++root.openGeneration;
        root.openPending = false;
        root.visible = false;
        root.releasePagesLater();
    }

    function pushSubmenu(entry, parentPage): void {
        menuStack.push(menuPageComponent, {
            initialMenuHandle: null,
            parentPage: parentPage,
            entryKey: parentPage.keyForEntry(entry),
            entryOccurrence: parentPage.occurrenceForEntry(entry),
            submenu: true,
            title: String(entry.text || qsTr("Menu"))
        }, StackView.Immediate);
    }

    function activateEntry(entry, page): void {
        if (!entry.enabled || entry.isSeparator)
            return;

        if (entry.hasChildren) {
            root.pushSubmenu(entry, page);
            return;
        }

        entry.triggered();
        root.closeMenu();
    }

    visible: false
    implicitWidth: root.menuWidth
    implicitHeight: Math.max(1, Math.min(root.maximumHeight, root.pageHeight))
    color: "transparent"
    grabFocus: true

    anchor {
        item: root.anchorItem
        edges: Edges.Bottom | Edges.Right
        gravity: Edges.Bottom | Edges.Left
        adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
        margins.bottom: Metrics.spacingXs
    }

    onClosed: {
        if (root.openPending) {
            ++root.openGeneration;
            root.openPending = false;
        }

        root.releasePagesLater();
    }

    M3Panel {
        anchors.fill: parent
        radius: Metrics.radiusSm
        color: Theme.scheme.surfaceContainerHigh

        StackView {
            id: menuStack

            anchors.fill: parent
            clip: true
        }
    }

    Component {
        id: menuPageComponent

        SystemTrayMenuPage {
            id: page

            menuWidth: root.menuWidth
            menuPadding: root.menuPadding
            maximumHeight: root.maximumHeight
            onBackRequested: menuStack.pop(StackView.Immediate)
            onEntryActivated: entry => root.activateEntry(entry, page)
        }
    }
}
