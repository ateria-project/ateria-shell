pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import qs.theme

Slider {
    id: root

    // Visual configuration
    property real trackHeight: 4
    property color inactiveTrackColor: Theme.scheme.outlineVariant
    property color activeTrackColor: Theme.scheme.primaryContainer
    property color focusRingColor: root.activeTrackColor

    // Optional leading icon rendered inside the active track.
    //
    // The icon remains visible at the minimum value because the active track
    // always has at least one handle diameter of width.
    property string iconName: ""
    property int iconSize: 22
    property color iconColor: Theme.scheme.onPrimaryContainer
    property bool iconFilled: false
    property real iconWeight: 500
    property real iconGrade: 0
    property real iconOpticalSize: Math.max(20, root.iconSize)
    property real iconInset: Math.max(0, (geometry.handleDiameter - root.iconSize) / 2)

    // Debounces requests emitted while dragging when `live` is enabled.
    // The final value is always emitted immediately when interaction ends.
    property int liveUpdateInterval: 100

    // Animates programmatic/backend value changes, but never pointer dragging.
    property bool animateValueChanges: true

    readonly property bool hasIcon: root.iconName.length > 0

    signal valueChangeRequested(real requestedValue)

    implicitWidth: 180
    implicitHeight: 34

    padding: 0
    orientation: Qt.Horizontal

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    wheelEnabled: true

    // Five percent of the configured range by default.
    // Callers can override this for domain-specific increments.
    stepSize: Math.abs(root.to - root.from) * 0.05

    opacity: root.enabled ? 1 : 0.38

    /*
     * Request lifecycle
     *
     * - live == false: one request when interaction finishes
     * - live == true: debounced requests while interacting, followed by an
     *   immediate final request when necessary
     * - wheel interaction: immediate request per effective value change
     */
    onMoved: {
        if (root.pressed) {
            requestState.pendingValue = root.value;
            requestState.hasPendingValue = true;

            if (root.live)
                requestState.schedule(root.value);

            return;
        }

        requestState.emitValue(root.value);
    }

    onPressedChanged: {
        if (root.pressed) {
            requestState.interactionActive = true;
            requestState.hasPendingValue = false;
            requestState.emittedDuringInteraction = false;

            liveUpdateTimer.stop();
            return;
        }

        if (!requestState.interactionActive)
            return;

        requestState.interactionActive = false;
        liveUpdateTimer.stop();

        const finalValue = root.value;

        if (!requestState.emittedDuringInteraction || requestState.lastEmittedValue !== finalValue) {
            requestState.emitValue(finalValue);
        }

        requestState.hasPendingValue = false;
    }

    QtObject {
        id: requestState

        property bool interactionActive: false
        property bool hasPendingValue: false
        property bool emittedDuringInteraction: false

        property real pendingValue: root.value
        property real lastEmittedValue: root.value

        function emitValue(requestedValue: real): void {
            requestState.lastEmittedValue = requestedValue;
            requestState.emittedDuringInteraction = true;

            root.valueChangeRequested(requestedValue);
        }

        function schedule(requestedValue: real): void {
            requestState.pendingValue = requestedValue;
            requestState.hasPendingValue = true;

            if (root.liveUpdateInterval <= 0) {
                liveUpdateTimer.stop();
                requestState.emitValue(requestedValue);
                return;
            }

            liveUpdateTimer.restart();
        }
    }

    Timer {
        id: liveUpdateTimer

        interval: Math.max(0, root.liveUpdateInterval)
        repeat: false

        onTriggered: {
            if (requestState.hasPendingValue)
                requestState.emitValue(requestState.pendingValue);
        }
    }

    /*
     * Animate the normalized position rather than the fill width.
     *
     * This avoids animating when the control itself is resized. During direct
     * interaction, the animation is disabled so the slider follows the input
     * without lag.
     */
    QtObject {
        id: visualState

        property real position: root.position

        Behavior on position {
            enabled: root.animateValueChanges && !root.pressed

            SpringAnimation {
                spring: Motion.fastSpatialSpring
                damping: Motion.fastSpatialDamping
                mass: Motion.fastSpatialMass
                epsilon: Motion.fastSpatialEpsilon
            }
        }
    }

    QtObject {
        id: geometry

        readonly property real handleDiameter: Math.min(root.availableHeight, root.availableWidth)
        readonly property real handleTravel: Math.max(0, root.availableWidth - geometry.handleDiameter)
        readonly property real activeTrackWidth: Math.min(root.availableWidth, geometry.handleDiameter + geometry.handleTravel * visualState.position)
    }

    background: Item {
        implicitWidth: 180
        implicitHeight: 34

        Rectangle {
            id: inactiveTrack

            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }

            height: Math.min(Math.max(0, root.trackHeight), parent.height)

            radius: height / 2
            color: root.inactiveTrackColor

            Behavior on color {
                ColorAnimation {
                    duration: Motion.durationMedium
                }
            }
        }

        Rectangle {
            id: activeTrack

            anchors {
                left: root.mirrored ? undefined : parent.left
                right: root.mirrored ? parent.right : undefined
                verticalCenter: parent.verticalCenter
            }

            width: geometry.activeTrackWidth
            height: geometry.handleDiameter

            radius: height / 2
            clip: true

            color: root.activeTrackColor

            Behavior on color {
                ColorAnimation {
                    duration: Motion.durationMedium
                }
            }

            M3Icon {
                anchors {
                    left: root.mirrored ? undefined : parent.left
                    right: root.mirrored ? parent.right : undefined
                    verticalCenter: parent.verticalCenter
                }

                anchors.leftMargin: (root.mirrored ? 0 : root.iconInset)

                anchors.rightMargin: (root.mirrored ? root.iconInset : 0)

                visible: root.hasIcon

                name: root.iconName
                size: Math.min(root.iconSize, parent.height)
                filled: root.iconFilled
                weight: root.iconWeight
                grade: root.iconGrade
                opticalSize: root.iconOpticalSize
                color: root.iconColor
            }
        }
    }

    /*
     * Slider uses this item's dimensions to calculate pointer mapping.
     * The visible active track already renders the circular handle, so this
     * item only supplies geometry and the keyboard-focus indicator.
     */
    handle: Item {
        implicitWidth: geometry.handleDiameter
        implicitHeight: geometry.handleDiameter

        x: root.leftPadding + root.visualPosition * Math.max(0, root.availableWidth - width)

        y: root.topPadding + (root.availableHeight - height) / 2

        Rectangle {
            anchors.fill: parent

            visible: root.visualFocus
            radius: width / 2

            color: "transparent"
            border.width: 2
            border.color: root.focusRingColor
        }
    }

    HoverHandler {
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
