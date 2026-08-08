import QtQuick
import qs.theme

Item {
    id: root

    default property alias contentData: swipeContent.data
    property bool swipeEnabled: true
    property bool showSeparator: false
    readonly property real dismissThreshold: root.width / 3
    property bool dismissing: false

    signal dismissed

    clip: true

    function resetPosition() {
        root.dismissing = false;
        swipeAnimation.stop();
        swipeContent.x = 0;
    }

    function finishSwipe() {
        if (Math.abs(swipeContent.x) < root.dismissThreshold) {
            swipeAnimation.to = 0;
            swipeAnimation.start();
            return;
        }

        root.dismissing = true;
        swipeAnimation.to = swipeContent.x > 0 ? root.width : -root.width;
        swipeAnimation.start();
    }

    onSwipeEnabledChanged: {
        if (!swipeEnabled)
            root.resetPosition();
    }
    onWidthChanged: {
        if (!swipeHandler.active && !root.dismissing)
            root.resetPosition();
    }

    Item {
        id: swipeContent

        width: parent.width
        height: parent.height
    }

    DragHandler {
        id: swipeHandler

        enabled: root.swipeEnabled && !root.dismissing
        target: swipeContent
        xAxis.enabled: true
        xAxis.minimum: -root.width
        xAxis.maximum: root.width
        yAxis.enabled: false
        onActiveChanged: {
            if (active)
                swipeAnimation.stop();
            else if (root.swipeEnabled)
                root.finishSwipe();
        }
    }

    NumberAnimation {
        id: swipeAnimation

        target: swipeContent
        property: "x"
        duration: Motion.durationMedium
        easing.type: Motion.easingStandard
        easing.bezierCurve: Motion.standardCurve
        onFinished: {
            if (root.dismissing)
                root.dismissed();
        }
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
