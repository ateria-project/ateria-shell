pragma Singleton

import QtQuick
import Quickshell
import qs.platform.notifications

Singleton {
    id: root

    property var receivedAtById: ({})
    property var expandedById: ({})
    property var expandedGroupsByKey: ({})
    property var metadataById: ({})
    property int clockRevision: 0
    property var notificationGroups: []
    property var notificationGroupKeys: []
    property var notificationGroupsByKey: ({})

    readonly property alias notificationGroupModel: _notificationGroupModel

    ListModel {
        id: _notificationGroupModel
    }

    function notificationKey(notification): string {
        if (!notification || notification.id === null || notification.id === undefined)
            return "";
        return String(notification.id);
    }

    function remember(notification) {
        const key = root.notificationKey(notification);
        if (key.length === 0 || Object.prototype.hasOwnProperty.call(root.receivedAtById, key))
            return;

        const nextReceivedAt = Object.assign({}, root.receivedAtById);
        nextReceivedAt[key] = Date.now();
        root.receivedAtById = nextReceivedAt;
    }

    function mapsEqual(first, second): bool {
        const firstKeys = Object.keys(first);
        const secondKeys = Object.keys(second);
        return firstKeys.length === secondKeys.length
            && firstKeys.every(key => Object.prototype.hasOwnProperty.call(second, key) && first[key] === second[key]);
    }

    function scheduleReconcile() {
        reconcileTimer.restart();
    }

    function groupStatesEqual(first: var, second: var): bool {
        if (first.length !== second.length)
            return false;

        for (let i = 0; i < first.length; i++) {
            const a = first[i];
            const b = second[i];
            if (!a || !b
                    || a.key !== b.key
                    || a.sourceName !== b.sourceName
                    || a.appIconSource !== b.appIconSource
                    || a.latestNotification !== b.latestNotification
                    || a.notifications.length !== b.notifications.length)
                return false;

            for (let j = 0; j < a.notifications.length; j++) {
                if (a.notifications[j] !== b.notifications[j])
                    return false;
            }
        }

        return true;
    }

    function stringArraysEqual(first: var, second: var): bool {
        if (first.length !== second.length)
            return false;
        for (let i = 0; i < first.length; i++) {
            if (first[i] !== second[i])
                return false;
        }
        return true;
    }

    function parseBody(value): var {
        const text = String(value || "");
        const sourceLink = text.match(/^\s*<a\b[^>]*>([^<]+)<\/a>\s*/i);

        if (sourceLink) {
            return {
                source: sourceLink[1].trim(),
                content: text.slice(sourceLink[0].length).trim()
            };
        }

        const plainSource = text.match(/^\s*((?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,})(?:[ \t]*\r?\n)+/i);
        if (!plainSource)
            return { source: "", content: text };

        return {
            source: plainSource[1].trim(),
            content: text.slice(plainSource[0].length).trim()
        };
    }

    function metadata(notification): var {
        if (!notification) {
            return {
                sourceName: qsTr("Notification"),
                body: "",
                groupKey: "",
                iconSource: ""
            };
        }

        const key = root.notificationKey(notification);
        const cacheable = key.length > 0;
        const body = String(notification.body || "");
        const appName = String(notification.appName || "");
        const desktopEntry = String(notification.desktopEntry || "");
        const appIcon = String(notification.appIcon || "");
        const cached = cacheable ? root.metadataById[key] : null;
        if (cached
                && cached.sourceBody === body
                && cached.sourceAppName === appName
                && cached.sourceDesktopEntry === desktopEntry
                && cached.sourceAppIcon === appIcon)
            return cached;

        const parsedBody = root.parseBody(body);
        const parsedSource = parsedBody.source.toLowerCase();
        let groupKey = "";
        if (parsedSource.length > 0)
            groupKey = "site:" + parsedSource;
        else if (desktopEntry.length > 0)
            groupKey = "app:" + desktopEntry.toLowerCase();
        else
            groupKey = "app:" + String(appName || qsTr("Notification")).toLowerCase();

        let iconSource = "";
        if (appIcon.startsWith("/") || appIcon.includes("://"))
            iconSource = appIcon;
        else if (appIcon.length > 0)
            iconSource = Quickshell.iconPath(appIcon, true);
        else if (desktopEntry.length > 0)
            iconSource = Quickshell.iconPath(desktopEntry, true);

        const value = {
            sourceBody: body,
            sourceAppName: appName,
            sourceDesktopEntry: desktopEntry,
            sourceAppIcon: appIcon,
            sourceName: parsedBody.source || appName || desktopEntry || qsTr("Notification"),
            body: parsedBody.content,
            groupKey: groupKey,
            iconSource: iconSource
        };
        if (cacheable)
            root.metadataById[key] = value;
        return value;
    }

    function sourceName(notification): string {
        return root.metadata(notification).sourceName;
    }

    function bodyText(notification): string {
        return root.metadata(notification).body;
    }

    function iconSource(notification): string {
        return root.metadata(notification).iconSource;
    }

    function groupKey(notification): string {
        return root.metadata(notification).groupKey;
    }

    function previewText(notification): string {
        if (!notification)
            return "";

        const summary = String(notification.summary || "").trim();
        const body = root.metadata(notification).body.replace(/\s+/g, " ").trim();
        if (summary.length === 0)
            return body;
        if (body.length === 0)
            return summary;
        return summary + "  " + body;
    }

    function groupNotificationState(notifications: var): var {
        const groupsByKey = {};
        const groups = [];
        const keys = [];

        for (let index = notifications.length - 1; index >= 0; index--) {
            const notification = notifications[index];
            if (!notification)
                continue;

            const meta = root.metadata(notification);
            const key = meta.groupKey;
            let group = groupsByKey[key];
            if (!group) {
                group = {
                    key: key,
                    sourceName: meta.sourceName,
                    appIconSource: meta.iconSource,
                    latestNotification: notification,
                    notifications: []
                };
                groupsByKey[key] = group;
                groups.push(group);
                keys.push(key);
            }

            group.notifications.push(notification);
        }

        return {
            groups: groups,
            keys: keys,
            byKey: groupsByKey
        };
    }

    function groupNotifications(notifications: var): var {
        return root.groupNotificationState(notifications).groups;
    }

    function reconcileKeyModel(model: var, nextKeys: var) {
        const nextKeysSet = new Set(nextKeys);

        for (let i = model.count - 1; i >= 0; i--) {
            const key = model.get(i).key;
            if (!nextKeysSet.has(key)) {
                model.remove(i, 1);
            }
        }

        for (let i = 0; i < nextKeys.length; i++) {
            const nextKey = nextKeys[i];
            let currentIndex = -1;
            for (let j = i; j < model.count; j++) {
                if (model.get(j).key === nextKey) {
                    currentIndex = j;
                    break;
                }
            }

            if (currentIndex === -1) {
                model.insert(i, { key: nextKey });
            } else if (currentIndex !== i) {
                model.move(currentIndex, i, 1);
            }
        }
    }

    function reconcileNotifications() {
        const notifications = NotificationService.notifications;
        const nextReceivedAt = {};
        const nextExpanded = {};
        const now = Date.now();

        for (const notification of notifications) {
            const key = root.notificationKey(notification);
            if (key.length === 0)
                continue;

            nextReceivedAt[key] = Object.prototype.hasOwnProperty.call(root.receivedAtById, key)
                ? root.receivedAtById[key]
                : now;
            if (root.expandedById[key])
                nextExpanded[key] = true;
        }

        for (const key of Object.keys(root.metadataById)) {
            if (!Object.prototype.hasOwnProperty.call(nextReceivedAt, key))
                delete root.metadataById[key];
        }

        // Build group state once, then derive expansion validity from it.
        // This avoids a second full grouping/counting pass over notifications.
        const newState = root.groupNotificationState(NotificationService.nonTransientNotifications);
        const nextExpandedGroups = {};
        for (const key of Object.keys(root.expandedGroupsByKey)) {
            const group = newState.byKey[key];
            if (group && group.notifications.length > 1)
                nextExpandedGroups[key] = true;
        }

        if (!root.mapsEqual(root.receivedAtById, nextReceivedAt))
            root.receivedAtById = nextReceivedAt;
        if (!root.mapsEqual(root.expandedById, nextExpanded))
            root.expandedById = nextExpanded;
        if (!root.mapsEqual(root.expandedGroupsByKey, nextExpandedGroups))
            root.expandedGroupsByKey = nextExpandedGroups;

        const groupsChanged = !root.groupStatesEqual(root.notificationGroups, newState.groups);
        const keysChanged = !root.stringArraysEqual(root.notificationGroupKeys, newState.keys);

        // Preserve object identity when the visible grouping did not actually
        // change. This keeps delegate group/size bindings quiet on unrelated
        // notification-model updates.
        if (groupsChanged) {
            root.notificationGroups = newState.groups;
            root.notificationGroupsByKey = newState.byKey;
        }
        if (keysChanged) {
            root.notificationGroupKeys = newState.keys;
            root.reconcileKeyModel(_notificationGroupModel, newState.keys);
        }
    }

    function isExpanded(notification): bool {
        return Boolean(root.expandedById[root.notificationKey(notification)]);
    }

    function toggleExpanded(notification) {
        const key = root.notificationKey(notification);
        if (key.length === 0)
            return;

        const nextExpanded = Object.assign({}, root.expandedById);
        if (nextExpanded[key])
            delete nextExpanded[key];
        else
            nextExpanded[key] = true;
        root.expandedById = nextExpanded;
    }

    function isGroupExpanded(group): bool {
        return Boolean(group && root.expandedGroupsByKey[group.key]);
    }

    function toggleGroupExpanded(group) {
        if (!group || !group.key)
            return;

        const nextExpandedGroups = Object.assign({}, root.expandedGroupsByKey);
        if (nextExpandedGroups[group.key])
            delete nextExpandedGroups[group.key];
        else
            nextExpandedGroups[group.key] = true;
        root.expandedGroupsByKey = nextExpandedGroups;
    }

    function relativeTime(notification): string {
        const revision = root.clockRevision;
        const receivedAt = root.receivedAtById[root.notificationKey(notification)] ?? Date.now();
        const elapsedSeconds = Math.max(0, Math.floor((Date.now() - receivedAt) / 1000));
        if (elapsedSeconds < 60)
            return qsTr("now");

        const elapsedMinutes = Math.floor(elapsedSeconds / 60);
        if (elapsedMinutes < 60)
            return qsTr("%1m").arg(elapsedMinutes);

        const elapsedHours = Math.floor(elapsedMinutes / 60);
        if (elapsedHours < 24)
            return qsTr("%1h").arg(elapsedHours);

        return qsTr("%1d").arg(Math.floor(elapsedHours / 24));
    }

    Component.onCompleted: root.reconcileNotifications()

    Connections {
        target: NotificationService

        function onNotificationReceived(notification) {
            root.remember(notification);
        }

        function onDismissalBatchActiveChanged() {
            if (!NotificationService.dismissalBatchActive)
                root.scheduleReconcile();
        }
    }

    Connections {
        target: NotificationService.notificationModel

        function onValuesChanged() {
            if (!NotificationService.dismissalBatchActive)
                root.scheduleReconcile();
        }
    }

    Timer {
        id: reconcileTimer

        interval: 0
        repeat: false
        onTriggered: root.reconcileNotifications()
    }

    Timer {
        interval: 60000
        repeat: true
        running: NotificationService.hasNotifications
        onTriggered: root.clockRevision++
    }
}
