import QtQuick
import QtTest
import qs.features.notifications
import qs.features.notifications.components

TestCase {
    id: testCase

    name: "NotificationPresentation"
    when: windowShown

    width: 480
    height: 480

    Component {
        id: swipeComponent

        SwipeToDismiss {
            width: 400
        }
    }

    SignalSpy {
        id: dismissedSpy

        signalName: "dismissed"
    }

    function notification(id, appName, summary) {
        return {
            id: id,
            appName: appName,
            desktopEntry: appName,
            appIcon: "",
            body: "Body",
            summary: summary,
            transient: false
        };
    }

    function test_group_state_has_stable_key_index() {
        const first = notification(1, "Alpha", "First");
        const second = notification(2, "Alpha", "Second");
        const third = notification(3, "Beta", "Third");
        const state = NotificationController.groupNotificationState([first, second, third]);

        compare(state.keys.length, 2);
        compare(state.groups.length, 2);
        compare(state.byKey[state.keys[0]], state.groups[0]);
        compare(state.byKey[state.keys[1]], state.groups[1]);
        compare(state.groups[1].notifications.length, 2);
    }

    function test_initial_height_is_not_animated() {
        const item = createTemporaryObject(swipeComponent, testCase, { contentHeight: 160 });
        verify(item);
        compare(item.implicitHeight, 160);
    }

    function test_dismissal_commits_after_geometry_exit() {
        const item = createTemporaryObject(swipeComponent, testCase, { contentHeight: 160 });
        verify(item);
        dismissedSpy.target = item;
        dismissedSpy.clear();

        item.dismissAnimated(1);
        compare(dismissedSpy.count, 0);
        tryCompare(dismissedSpy, "count", 1, 1000);
        compare(item.implicitHeight, 0);
    }
}
