pragma Singleton

import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property var notificationModel: server.trackedNotifications
    readonly property var trackedNotifications: root.notificationModel.values
    readonly property var notifications: root.dismissalBatchActive ? root.dismissalBatchSnapshot : root.trackedNotifications
    readonly property var nonTransientNotifications: root.notifications.filter(notification => {
        return !notification.transient;
    })
    readonly property int count: root.notifications.length
    readonly property int nonTransientCount: root.nonTransientNotifications.length
    readonly property bool hasNotifications: root.count > 0
    readonly property bool hasNonTransientNotifications: root.nonTransientCount > 0
    readonly property bool doNotDisturb: NotificationSettings.doNotDisturb

    property bool initialized: false
    property bool dismissalBatchActive: false
    property var dismissalBatchSnapshot: []

    signal notificationReceived(var notification)
    signal operationFailed(string operation, string message)

    function initialize() {
        // Calling this function explicitly constructs the singleton and its
        // NotificationServer. Construction claims org.freedesktop.Notifications.
        root.initialized = true;
    }

    function setDoNotDisturb(value: bool): bool {
        return NotificationSettings.setDoNotDisturb(value);
    }

    function toggleDoNotDisturb(): bool {
        return root.setDoNotDisturb(!root.doNotDisturb);
    }

    function isValidNotification(notification): bool {
        return notification !== null && notification !== undefined && typeof notification.dismiss === "function";
    }

    function dismiss(notification): bool {
        if (!root.isValidNotification(notification))
            return false;

        try {
            notification.dismiss();
            return true;
        } catch (error) {
            root.fail("dismiss", error);
            return false;
        }
    }

    function expire(notification): bool {
        if (!root.isValidNotification(notification) || typeof notification.expire !== "function")
            return false;

        try {
            notification.expire();
            return true;
        } catch (error) {
            root.fail("expire", error);
            return false;
        }
    }

    function dismissAll(): bool {
        return root.dismissMany(root.notifications);
    }

    function dismissMany(notifications): bool {
        const currentNotifications = notifications ? notifications.slice() : [];
        if (currentNotifications.length === 0)
            return true;
        if (currentNotifications.length === 1)
            return root.dismiss(currentNotifications[0]);

        const dismissedIds = {};
        for (const notification of currentNotifications) {
            if (notification)
                dismissedIds[String(notification.id)] = true;
        }

        root.dismissalBatchSnapshot = root.notifications.filter(notification => {
            return !dismissedIds[String(notification.id)];
        });
        root.dismissalBatchActive = true;

        let succeeded = true;
        try {
            for (const notification of currentNotifications)
                succeeded = root.dismiss(notification) && succeeded;
        } finally {
            root.dismissalBatchActive = false;
            root.dismissalBatchSnapshot = [];
        }

        return succeeded;
    }

    function invokeAction(action): bool {
        if (action === null || action === undefined || typeof action.invoke !== "function")
            return false;

        try {
            action.invoke();
            return true;
        } catch (error) {
            root.fail("invokeAction", error);
            return false;
        }
    }

    function fail(operation: string, error) {
        const message = String(error);
        console.warn("NotificationService: " + operation + " failed:", message);
        root.operationFailed(operation, message);
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: false

        onNotification: notification => {
            // Notification objects are discarded after this handler unless
            // they are explicitly tracked by the server.
            notification.tracked = true;
            root.notificationReceived(notification);
        }
    }
}
