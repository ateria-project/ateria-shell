import QtQuick
import qs.theme

// Owns the complete gesture lifecycle. The backing model is changed only
// after this component has finished its visual exit, so layouts never need to
// guess the size of an item that is already being removed.
Item {
    id: root

    default property alias contentData: swipeContent.data
    property bool swipeEnabled: true
    property bool dismissLeftEnabled: true
    property bool showSeparator: false
    property bool collapseOnDismiss: true
    property bool animateContentResize: true
    property real contentHeight: 0
    property real removalProgress: 1
    property bool geometryReady: false
    property real horizontalExitTarget: 0
    readonly property real dismissThreshold: root.width / 3
    readonly property bool dismissing: horizontalExit.running || verticalExit.running
    readonly property bool resizing: contentResizeAnimation.running

    signal dismissed

    implicitHeight: root.contentHeight * root.removalProgress
    // Clipping inside view delegates hurts batching. It is only required while
    // content is actually crossing this item's bounds.
    clip: root.resizing || swipeHandler.active || root.dismissing

    function resetPosition() {
        root.geometryReady = false;
        horizontalExit.stop();
        verticalExit.stop();
        root.horizontalExitTarget = 0;
        root.removalProgress = 1;
        swipeContent.x = 0;
        root.geometryReady = true;
    }

    function finishSwipe() {
        const dismissRight = swipeContent.x >= root.dismissThreshold;
        const dismissLeft = root.dismissLeftEnabled && swipeContent.x <= -root.dismissThreshold;
        root.horizontalExitTarget = dismissRight ? root.width : dismissLeft ? -root.width : 0;
        horizontalExit.restart();
    }

    function dismissAnimated(direction: int) {
        if (root.dismissing)
            return;

        root.horizontalExitTarget = direction < 0 ? -root.width : root.width;
        horizontalExit.restart();
    }

    Component.onCompleted: root.geometryReady = true

    onSwipeEnabledChanged: {
        if (!root.swipeEnabled && !root.dismissing)
            root.resetPosition();
    }

    Behavior on implicitHeight {
        enabled: root.animateContentResize && root.geometryReady && !root.dismissing

        NumberAnimation {
            id: contentResizeAnimation

            duration: Motion.durationNotification
            easing.type: Motion.easingEmphasized
            easing.bezierCurve: Motion.emphasizedCurve
        }
    }

    Item {
        id: swipeContent

        width: parent.width
        height: Math.max(0, parent.height - (root.showSeparator ? 1 : 0))

        DragHandler {
            id: swipeHandler

            enabled: root.swipeEnabled && !root.dismissing
            target: swipeContent
            xAxis.enabled: true
            xAxis.minimum: root.dismissLeftEnabled ? -root.width : 0
            xAxis.maximum: root.width
            yAxis.enabled: false
            onActiveChanged: {
                if (active)
                    horizontalExit.stop();
                else if (root.swipeEnabled)
                    root.finishSwipe();
            }
        }
    }

    // XAnimator runs the settle/exit transform on the scene-graph render
    // thread when a threaded render loop is available. Geometry-changing
    // vertical collapse intentionally remains a NumberAnimation.
    XAnimator {
        id: horizontalExit

        target: swipeContent
        from: swipeContent.x
        to: root.horizontalExitTarget
        duration: Motion.durationMedium
        easing.type: Motion.easingEmphasized
        easing.bezierCurve: Motion.emphasizedCurve
        onFinished: {
            if (Math.abs(root.horizontalExitTarget) < root.width - 0.5)
                return;

            if (root.collapseOnDismiss)
                verticalExit.restart();
            else
                root.dismissed();
        }
    }

    NumberAnimation {
        id: verticalExit

        target: root
        property: "removalProgress"
        from: 1
        to: 0
        duration: Motion.durationNotification
        easing.type: Motion.easingEmphasized
        easing.bezierCurve: Motion.emphasizedCurve
        onFinished: root.dismissed()
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 1
        color: Theme.scheme.outlineVariant
        opacity: 0.6
        visible: root.showSeparator
    }
}
