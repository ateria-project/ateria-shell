pragma Singleton

import QtQuick
import Quickshell
import qs.platform.notifications

Singleton {
    id: root

    property int displayDuration: 6000
    property var notifications: []
    property var expiresAtByGroupKey: ({})
    property var remainingDurationByGroupKey: ({})
    property var protectedGroupKeys: ({})
    property bool hideTimersPaused: false
    property int expansionRevision: 0

    readonly property var notificationGroups: NotificationController.groupNotifications(root.notifications)
    readonly property bool hasNotifications: root.notifications.length > 0

    function notificationKey(notification): string {
        return NotificationController.notificationKey(notification);
    }

    function groupKey(notification): string {
        return NotificationController.groupKey(notification);
    }

    function scheduleReconcile() {
        reconcileTimer.restart();
    }

    function scheduleHideTimer() {
        hideTimer.stop();
        if (root.hideTimersPaused || !root.hasNotifications)
            return;

        let nextExpiresAt = Number.POSITIVE_INFINITY;
        for (const key of Object.keys(root.expiresAtByGroupKey))
            nextExpiresAt = Math.min(nextExpiresAt, root.expiresAtByGroupKey[key]);
        if (!Number.isFinite(nextExpiresAt))
            return;

        hideTimer.interval = Math.max(1, Math.ceil(nextExpiresAt - Date.now()));
        hideTimer.start();
    }

    function setProtectedGroupKeys(keys) {
        const nextProtectedGroups = Object.assign({}, keys || {});
        const currentKeys = Object.keys(root.protectedGroupKeys);
        const nextKeys = Object.keys(nextProtectedGroups);
        if (currentKeys.length === nextKeys.length && currentKeys.every(key => nextProtectedGroups[key]))
            return;

        const nextExpiresAt = Object.assign({}, root.expiresAtByGroupKey);
        const nextRemainingDurations = Object.assign({}, root.remainingDurationByGroupKey);
        const shouldPauseTimers = nextKeys.some(key => nextProtectedGroups[key]);
        const now = Date.now();

        if (!root.hideTimersPaused && shouldPauseTimers) {
            for (const key of Object.keys(nextExpiresAt))
                nextRemainingDurations[key] = Math.max(0, nextExpiresAt[key] - now);
        } else if (root.hideTimersPaused && !shouldPauseTimers) {
            for (const key of Object.keys(nextRemainingDurations))
                nextExpiresAt[key] = now + nextRemainingDurations[key];
            for (const key of Object.keys(nextRemainingDurations))
                delete nextRemainingDurations[key];
        }

        root.protectedGroupKeys = nextProtectedGroups;
        root.hideTimersPaused = shouldPauseTimers;
        root.expiresAtByGroupKey = nextExpiresAt;
        root.remainingDurationByGroupKey = nextRemainingDurations;
        root.scheduleHideTimer();
    }

    function retainedGroupExpirations(notifications): var {
        const nextExpiresAt = {};
        for (const notification of notifications) {
            const key = root.groupKey(notification);
            if (Object.prototype.hasOwnProperty.call(root.expiresAtByGroupKey, key))
                nextExpiresAt[key] = root.expiresAtByGroupKey[key];
        }
        return nextExpiresAt;
    }

    function retainedGroupRemainingDurations(notifications): var {
        const nextRemainingDurations = {};
        for (const notification of notifications) {
            const key = root.groupKey(notification);
            if (Object.prototype.hasOwnProperty.call(root.remainingDurationByGroupKey, key))
                nextRemainingDurations[key] = root.remainingDurationByGroupKey[key];
        }
        return nextRemainingDurations;
    }

    function historyGroup(notification): var {
        const notificationId = root.notificationKey(notification);
        const notificationGroup = root.groupKey(notification);
        const group = [];

        if (!notification.transient) {
            for (const candidate of NotificationService.nonTransientNotifications) {
                if (root.groupKey(candidate) !== notificationGroup)
                    continue;
                if (root.notificationKey(candidate) === notificationId)
                    continue;

                group.push(candidate);
            }
        }

        group.push(notification);
        return group;
    }

    function show(notification) {
        const key = root.notificationKey(notification);
        if (key.length === 0)
            return;

        const shownGroupKey = root.groupKey(notification);
        const nextNotifications = [];
        const shownGroupHistory = [];
        for (const candidate of root.notifications) {
            if (root.notificationKey(candidate) === key)
                continue;
            if (root.groupKey(candidate) === shownGroupKey)
                shownGroupHistory.push(candidate);
            else
                nextNotifications.push(candidate);
        }

        const history = shownGroupHistory.length > 0 ? shownGroupHistory : root.historyGroup(notification);
        for (const historyNotification of history)
            nextNotifications.push(historyNotification);
        if (history.length === 0 || root.notificationKey(history[history.length - 1]) !== key)
            nextNotifications.push(notification);

        const nextExpiresAt = root.retainedGroupExpirations(nextNotifications);
        const nextRemainingDurations = root.retainedGroupRemainingDurations(nextNotifications);
        nextExpiresAt[shownGroupKey] = Date.now() + root.displayDuration;
        if (root.hideTimersPaused)
            nextRemainingDurations[shownGroupKey] = root.displayDuration;
        else
            delete nextRemainingDurations[shownGroupKey];

        root.notifications = nextNotifications;
        root.expiresAtByGroupKey = nextExpiresAt;
        root.remainingDurationByGroupKey = nextRemainingDurations;
        root.expansionRevision++;
        root.scheduleHideTimer();
    }

    function reconcileNotifications() {
        const activeKeys = {};
        for (const notification of NotificationService.notifications)
            activeKeys[root.notificationKey(notification)] = true;

        root.removeWhere(notification => {
            return !activeKeys[root.notificationKey(notification)];
        }, true);
    }

    function removeWhere(predicate, resetExpansionState: bool) {
        const nextNotifications = root.notifications.filter(notification => {
            return !predicate(notification);
        });
        if (nextNotifications.length === root.notifications.length)
            return false;

        root.notifications = nextNotifications;
        root.expiresAtByGroupKey = root.retainedGroupExpirations(nextNotifications);
        root.remainingDurationByGroupKey = root.retainedGroupRemainingDurations(nextNotifications);
        if (resetExpansionState)
            root.expansionRevision++;
        root.scheduleHideTimer();
        return true;
    }

    function hideGroup(key: string) {
        if (key.length === 0)
            return;

        root.removeWhere(notification => {
            return root.groupKey(notification) === key;
        }, true);
    }

    function hideNotification(notification) {
        const key = root.notificationKey(notification);
        if (key.length === 0)
            return;

        root.removeWhere(candidate => {
            return root.notificationKey(candidate) === key;
        }, false);
    }

    function pruneExpired() {
        if (root.hideTimersPaused)
            return;

        const now = Date.now();
        const removed = root.removeWhere(notification => {
            const key = root.groupKey(notification);
            return (root.expiresAtByGroupKey[key] ?? 0) <= now;
        }, true);
        if (!removed)
            root.scheduleHideTimer();
    }

    Connections {
        target: NotificationService

        function onNotificationReceived(notification) {
            root.show(notification);
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
        id: hideTimer

        repeat: false
        onTriggered: root.pruneExpired()
    }
}
