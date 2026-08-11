pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

// Material 3 flat linear progress geometry and disjoint motion, based on the
// Apache-2.0 Android Open Source Project reference implementation.
Item {
    id: root

    property real progress: 0
    property bool indeterminate: false
    property color color: Theme.scheme.primary
    property color trackColor: Theme.scheme.primaryContainer
    property string accessibleName: indeterminate
        ? qsTr("In progress")
        : qsTr("%1% complete").arg(Math.round(Math.max(0, Math.min(1, progress)) * 100))

    // Lets repeated indicators share the same Material motion while beginning
    // at different points in its cycle.
    property real phaseOffset: 0

    readonly property real trackThickness: 4
    readonly property real indicatorTrackGapSize: 4
    readonly property real trackStopIndicatorSize: 4
    readonly property int animationDuration: 1800

    property real animationFraction: 0

    implicitWidth: 240
    implicitHeight: trackThickness

    Accessible.role: Accessible.ProgressBar
    Accessible.name: root.accessibleName

    onProgressChanged: bar.requestPaint()
    onIndeterminateChanged: bar.requestPaint()
    onColorChanged: bar.requestPaint()
    onTrackColorChanged: bar.requestPaint()
    onPhaseOffsetChanged: bar.requestPaint()
    onAnimationFractionChanged: bar.requestPaint()
    onWidthChanged: bar.requestPaint()
    onHeightChanged: bar.requestPaint()

    Canvas {
        id: bar

        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        function clamp(value, minimum, maximum) {
            return Math.max(minimum, Math.min(maximum, value));
        }

        function cubicBezier(value, x1, y1, x2, y2) {
            const x = clamp(value, 0, 1);
            if (x === 0 || x === 1)
                return x;

            let parameter = x;
            for (let iteration = 0; iteration < 8; ++iteration) {
                const inverse = 1 - parameter;
                const estimate = 3 * inverse * inverse * parameter * x1
                    + 3 * inverse * parameter * parameter * x2
                    + parameter * parameter * parameter;
                const derivative = 3 * inverse * inverse * x1
                    + 6 * inverse * parameter * (x2 - x1)
                    + 3 * parameter * parameter * (1 - x2);
                if (Math.abs(estimate - x) < 1e-05 || Math.abs(derivative) < 1e-05)
                    break;

                parameter = clamp(parameter - (estimate - x) / derivative, 0, 1);
            }

            const inverse = 1 - parameter;
            return 3 * inverse * inverse * parameter * y1
                + 3 * inverse * parameter * parameter * y2
                + parameter * parameter * parameter;
        }

        function animatedFraction(playtime, delay, duration, x1, y1, x2, y2) {
            return cubicBezier(clamp((playtime - delay) / duration, 0, 1), x1, y1, x2, y2);
        }

        function drawIndicator(context, startFraction, endFraction, paintColor, thickness) {
            if (Math.abs(endFraction - startFraction) <= 0 || width <= 0 || height <= 0)
                return;

            const centerY = height / 2;
            const rounded = width >= thickness;
            const capOffset = rounded ? thickness / 2 : 0;
            const minimumX = capOffset;
            const maximumX = width - capOffset;
            const startX = clamp(startFraction * width, minimumX, maximumX);
            const endX = clamp(endFraction * width, minimumX, maximumX);

            if (rounded && Math.abs(endX - startX) < 1e-05) {
                context.fillStyle = paintColor;
                context.beginPath();
                context.arc(startX, centerY, thickness / 2, 0, Math.PI * 2);
                context.fill();
                return;
            }

            context.strokeStyle = paintColor;
            context.lineWidth = thickness;
            context.lineCap = rounded ? "round" : "butt";
            context.beginPath();
            context.moveTo(startX, centerY);
            context.lineTo(endX, centerY);
            context.stroke();
        }

        function drawStopIndicator(context, paintColor, thickness) {
            const size = Math.min(root.trackStopIndicatorSize, thickness);
            const offset = (thickness - size) / 2;
            const radius = size / 2;

            context.fillStyle = paintColor;
            context.beginPath();
            context.arc(width - radius - offset, height / 2, radius, 0, Math.PI * 2);
            context.fill();
        }

        function drawDeterminate(context, thickness) {
            const progress = clamp(root.progress, 0, 1);
            // Rounded caps contribute one track thickness to the physical gap.
            const adjustedGap = root.indicatorTrackGapSize + thickness;
            const gapFraction = width > 0 ? adjustedGap / width : 0;
            const trackStart = progress + Math.min(progress, gapFraction);

            if (trackStart <= 1)
                drawIndicator(context, trackStart, 1, root.trackColor, thickness);

            drawIndicator(context, 0, progress, root.color, thickness);
            drawStopIndicator(context, root.color, thickness);
        }

        function drawIndeterminate(context, thickness) {
            const cycle = ((root.animationFraction + root.phaseOffset) % 1 + 1) % 1;
            const playtime = cycle * root.animationDuration;
            const adjustedGap = root.indicatorTrackGapSize + thickness;
            const gapFraction = width > 0 ? adjustedGap / width : 0;

            const firstHead = animatedFraction(playtime, 0, 750, 0.2, 0, 0.8, 1);
            const firstTail = animatedFraction(playtime, 333, 850, 0.4, 0, 1, 1);
            const secondHead = animatedFraction(playtime, 1000, 567, 0, 0, 0.65, 1);
            const secondTail = animatedFraction(playtime, 1267, 533, 0.1, 0, 0.45, 1);

            // These track slices leave the Material gap on both sides of each
            // moving segment without drawing an extra full-width layer beneath it.
            if (firstHead - firstTail > 0) {
                if (firstTail > gapFraction) {
                    const start = secondHead > gapFraction ? secondHead + gapFraction : 0;
                    drawIndicator(context, start, firstTail - gapFraction, root.trackColor, thickness);
                }
                drawIndicator(context, firstHead, firstTail, root.color, thickness);
                if (firstHead < 1 - gapFraction)
                    drawIndicator(context, firstHead + gapFraction, 1, root.trackColor, thickness);
            }

            if (secondHead - secondTail > 0) {
                if (secondTail > gapFraction)
                    drawIndicator(context, 0, secondTail - gapFraction, root.trackColor, thickness);
                drawIndicator(context, secondHead, secondTail, root.color, thickness);
                if (secondHead < 1 - gapFraction) {
                    const end = firstTail < 1 - gapFraction ? firstTail - gapFraction : 1;
                    drawIndicator(context, secondHead + gapFraction, end, root.trackColor, thickness);
                }
            }
        }

        onPaint: {
            const context = getContext("2d");
            context.reset();

            const thickness = Math.min(root.trackThickness, height);
            if (thickness <= 0 || width <= 0)
                return;

            if (root.indeterminate)
                drawIndeterminate(context, thickness);
            else
                drawDeterminate(context, thickness);
        }
    }

    NumberAnimation {
        target: root
        property: "animationFraction"
        from: 0
        to: 1
        duration: root.animationDuration
        loops: Animation.Infinite
        running: root.visible && root.indeterminate
    }
}
