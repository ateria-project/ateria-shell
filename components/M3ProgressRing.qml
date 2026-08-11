import QtQuick
import qs.theme

// Material 3 circular progress geometry and "advance" motion, based on the
// Apache-2.0 Android Open Source Project reference implementation.
Item {
    id: root

    property real progress: 0
    property bool indeterminate: false
    property color color: Theme.scheme.primary
    property color trackColor: Theme.scheme.primaryContainer
    readonly property real indicatorSize: 40
    readonly property real indicatorInset: 4
    readonly property real trackThickness: 4
    readonly property real indicatorTrackGapSize: 4
    readonly property bool indeterminateTrackVisible: false
    readonly property int animationDuration: 5400

    property real animationFraction: 0

    implicitWidth: indicatorSize + indicatorInset * 2
    implicitHeight: indicatorSize + indicatorInset * 2
    onProgressChanged: ring.requestPaint()
    onColorChanged: ring.requestPaint()
    onTrackColorChanged: ring.requestPaint()
    onIndeterminateChanged: ring.requestPaint()
    onAnimationFractionChanged: ring.requestPaint()

    Canvas {
        id: ring

        function clamp(value, minimum, maximum) {
            return Math.max(minimum, Math.min(maximum, value));
        }

        // Android's FastOutSlowInInterpolator: cubic-bezier(0.4, 0, 0.2, 1).
        function fastOutSlowIn(value) {
            const x = clamp(value, 0, 1);
            if (x === 0 || x === 1)
                return x;

            let parameter = x;
            for (let iteration = 0; iteration < 8; ++iteration) {
                const inverse = 1 - parameter;
                const estimate = 3 * inverse * inverse * parameter * 0.4 + 3 * inverse * parameter * parameter * 0.2 + parameter * parameter * parameter;
                const derivative = 1.2 * inverse * inverse - 1.2 * inverse * parameter + 2.4 * parameter * parameter;
                if (Math.abs(estimate - x) < 1e-05 || Math.abs(derivative) < 1e-05)
                    break;

                parameter = clamp(parameter - (estimate - x) / derivative, 0, 1);
            }
            const inverse = 1 - parameter;
            return 3 * inverse * parameter * parameter + parameter * parameter * parameter;
        }

        function fractionInRange(playtime, delay, duration) {
            return clamp((playtime - delay) / duration, 0, 1);
        }

        function drawArc(context, centerX, centerY, radius, thickness, startFraction, endFraction, paintColor, startGap, endGap, activeIndicator) {
            let arcFraction = endFraction >= startFraction ? endFraction - startFraction : 1 + endFraction - startFraction;
            startFraction %= 1;
            if (startFraction < 0)
                startFraction += 1;

            const cornerRadius = thickness / 2;
            const cornerDegrees = cornerRadius / radius * 180 / Math.PI;
            const fullCircleThreshold = 0.99;
            const overThreshold = arcFraction - fullCircleThreshold;
            if (overThreshold >= 0) {
                const increase = overThreshold * cornerDegrees / 180 / (1 - fullCircleThreshold);
                arcFraction += increase;
                if (!activeIndicator)
                    startFraction -= increase / 2;
            }

            const startGapDegrees = startGap / radius * 180 / Math.PI;
            const endGapDegrees = endGap / radius * 180 / Math.PI;
            const arcDegrees = arcFraction * 360 - startGapDegrees - endGapDegrees;
            const startDegrees = startFraction * 360 + startGapDegrees;
            if (arcDegrees <= 0)
                return;

            context.fillStyle = paintColor;
            context.strokeStyle = paintColor;
            if (arcDegrees < cornerDegrees * 2) {
                const shrink = arcDegrees / (cornerDegrees * 2);
                const centerDegrees = startDegrees + cornerDegrees * shrink;
                const angle = centerDegrees * Math.PI / 180 - Math.PI / 2;
                context.beginPath();
                context.arc(centerX + Math.cos(angle) * radius, centerY + Math.sin(angle) * radius, cornerRadius * shrink, 0, Math.PI * 2);
                context.fill();
                return;
            }

            const arcStart = (startDegrees + cornerDegrees) * Math.PI / 180 - Math.PI / 2;
            const arcEnd = (startDegrees + arcDegrees - cornerDegrees) * Math.PI / 180 - Math.PI / 2;
            context.lineWidth = thickness;
            context.lineCap = "round";
            context.beginPath();
            context.arc(centerX, centerY, radius, arcStart, arcEnd);
            context.stroke();
        }

        function indeterminateSegment() {
            const playtime = root.animationFraction * root.animationDuration;
            const expandDelays = [0, 1350, 2700, 4050];
            const collapseDelays = [667, 2017, 3367, 4717];
            let startDegrees = 1520 * root.animationFraction - 20;
            let endDegrees = 1520 * root.animationFraction;

            for (let cycle = 0; cycle < 4; ++cycle) {
                endDegrees += fastOutSlowIn(fractionInRange(playtime, expandDelays[cycle], 667)) * 250;
                startDegrees += fastOutSlowIn(fractionInRange(playtime, collapseDelays[cycle], 667)) * 250;
            }

            return [startDegrees / 360, endDegrees / 360];
        }

        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const context = getContext("2d");
            context.reset();

            const scale = Math.min(width, height) / root.implicitWidth;
            const thickness = root.trackThickness * scale;
            const radius = (root.indicatorSize - root.trackThickness) / 2 * scale;
            const gap = root.indicatorTrackGapSize * scale;
            const centerX = width / 2;
            const centerY = height / 2;
            let startFraction = 0;
            let endFraction = clamp(root.progress, 0, 1);
            let trackGap = gap * clamp(endFraction, 0, 0.01) / 0.01;
            if (root.indeterminate) {
                const segment = indeterminateSegment();
                startFraction = segment[0];
                endFraction = segment[1];
                trackGap = gap;
            }

            if (!root.indeterminate || root.indeterminateTrackVisible)
                drawArc(context, centerX, centerY, radius, thickness, endFraction, startFraction + 1, root.trackColor, trackGap, trackGap, false);

            drawArc(context, centerX, centerY, radius, thickness, startFraction, endFraction, root.color, 0, 0, true);
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
