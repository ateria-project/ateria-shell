pragma Singleton

import QtQuick
import Quickshell
import qs.platform.notifications

Singleton {
    id: root

    property int displayDuration: 6000
    property var notifications: []
    property bool visibleRequested: false
    property bool hovered: false
    property double hideDeadline: 0
    property int remainingDuration: displayDuration
    property int expansionRevision: 0
    property var dismissedNotificationKeys: ({})

    readonly property var notificationGroupState: NotificationController.groupNotificationState(root.notifications)
    readonly property var notificationGroups: root.notificationGroupState.groups
    readonly property var notificationGroupKeys: root.notificationGroupState.keys
    readonly property var notificationGroupsByKey: root.notificationGroupState.byKey
    readonly property bool hasNotifications: root.notifications.length > 0

    function notificationKey(notification): string {
        return NotificationController.notificationKey(notification);
    }

    function groupKey(notification): string {
        return NotificationController.groupKey(notification);
    }

    function resetHideDeadline() {
        root.remainingDuration = root.displayDuration;
        root.hideDeadline = Date.now() + root.displayDuration;
        if (!root.hovered && root.visibleRequested)
            hideTimer.restart();
    }

    function setHovered(value: bool) {
        if (root.hovered === value)
            return;

        root.hovered = value;
        if (value) {
            root.remainingDuration = Math.max(1, Math.ceil(root.hideDeadline - Date.now()));
            hideTimer.stop();
        } else if (root.visibleRequested) {
            root.hideDeadline = Date.now() + root.remainingDuration;
            hideTimer.restart();
        }
    }

    function historyFor(notification): var {
        const key = root.notificationKey(notification);
        const group = root.groupKey(notification);
        const history = [];

        if (!notification.transient) {
            for (const candidate of NotificationService.nonTransientNotifications) {
                const candidateKey = root.notificationKey(candidate);
                if (candidateKey === key || root.dismissedNotificationKeys[candidateKey])
                    continue;
                if (root.groupKey(candidate) === group)
                    history.push(candidate);
            }
        }

        history.push(notification);
        return history;
    }

    function show(notification) {
        const key = root.notificationKey(notification);
        if (key.length === 0)
            return;

        if (root.dismissedNotificationKeys[key]) {
            const dismissed = Object.assign({}, root.dismissedNotificationKeys);
            delete dismissed[key];
            root.dismissedNotificationKeys = dismissed;
        }

        const group = root.groupKey(notification);
        const next = root.visibleRequested ? root.notifications.filter(candidate => {
            return root.groupKey(candidate) !== group;
        }) : [];
        for (const candidate of root.historyFor(notification))
            next.push(candidate);

        root.notifications = next;
        root.expansionRevision++;
        root.visibleRequested = true;
        root.resetHideDeadline();
    }

    function hide() {
        if (!root.visibleRequested)
            return;

        root.visibleRequested = false;
        hideTimer.stop();
    }

    function completeExit() {
        if (root.visibleRequested)
            return;

        root.notifications = [];
        root.hovered = false;
        root.remainingDuration = root.displayDuration;
        root.expansionRevision++;
    }

    function dismissGroup(group): bool {
        if (!group || !group.notifications || group.notifications.length === 0)
            return false;

        const dismissed = Object.assign({}, root.dismissedNotificationKeys);
        for (const notification of group.notifications)
            dismissed[root.notificationKey(notification)] = true;
        root.dismissedNotificationKeys = dismissed;

        const groupKey = String(group.key || "");
        root.notifications = root.notifications.filter(notification => {
            return root.groupKey(notification) !== groupKey;
        });
        root.expansionRevision++;
        if (root.notifications.length === 0)
            root.hide();
        else
            root.resetHideDeadline();

        return group.notifications.length > 1 ? NotificationService.dismissMany(group.notifications) : NotificationService.dismiss(group.notifications[0]);
    }

    function reconcileNotifications() {
        const activeByKey = {};
        for (const notification of NotificationService.notifications) {
            const key = root.notificationKey(notification);
            if (key.length > 0)
                activeByKey[key] = notification;
        }

        const dismissed = {};
        for (const key of Object.keys(root.dismissedNotificationKeys)) {
            if (activeByKey[key])
                dismissed[key] = true;
        }
        if (!NotificationController.mapsEqual(root.dismissedNotificationKeys, dismissed))
            root.dismissedNotificationKeys = dismissed;

        const next = [];
        let changed = false;
        for (const notification of root.notifications) {
            const activeNotification = activeByKey[root.notificationKey(notification)];
            if (!activeNotification) {
                changed = true;
                continue;
            }

            next.push(activeNotification);
            if (activeNotification !== notification)
                changed = true;
        }
        if (!changed)
            return;

        root.notifications = next;
        if (next.length === 0)
            root.hide();
    }

    Connections {
        target: NotificationService

        function onNotificationReceived(notification) {
            root.show(notification);
        }

        function onDismissalBatchActiveChanged() {
            if (!NotificationService.dismissalBatchActive)
                reconcileTimer.restart();
        }
    }

    Connections {
        target: NotificationService.notificationModel

        function onValuesChanged() {
            if (!NotificationService.dismissalBatchActive)
                reconcileTimer.restart();
        }
    }

    Timer {
        id: reconcileTimer

        interval: 0
        repeat: false
        onTriggered: root.reconcileNotifications()
    }

    Timer {
        id: hideTimer

        interval: Math.max(1, root.remainingDuration)
        repeat: false
        onTriggered: root.hide()
    }
}
