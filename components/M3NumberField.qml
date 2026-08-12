pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.theme

Item {
    id: root

    property real value: 0
    property real from: -Number.MAX_VALUE
    property real to: Number.MAX_VALUE
    property real stepSize: 1
    property int decimals: 0
    property string accessibleName: ""
    property string draftText: root.formattedValue(root.value)

    readonly property bool canIncrease: root.value < root.to
    readonly property bool canDecrease: root.value > root.from
    readonly property real effectiveStepSize: Number.isFinite(root.stepSize) && root.stepSize > 0 ? root.stepSize : 1
    readonly property int effectiveDecimals: Number.isFinite(root.decimals)
        ? Math.max(0, Math.min(12, Math.round(root.decimals)))
        : 0

    signal valueModified(real value)

    function clampedValue(candidate: real): real {
        const clamped = Math.max(root.from, Math.min(root.to, candidate));
        if (root.effectiveDecimals === 0)
            return Math.round(clamped);
        const scale = Math.pow(10, root.effectiveDecimals);
        return Math.round(clamped * scale) / scale;
    }

    function formattedValue(candidate: real): string {
        if (!Number.isFinite(candidate))
            return "0";
        if (root.effectiveDecimals === 0)
            return String(Math.round(candidate));
        return String(Number(candidate.toFixed(root.effectiveDecimals)));
    }

    function commit(): void {
        const normalizedText = root.draftText.trim();
        const candidate = Number(normalizedText);
        if (normalizedText.length === 0 || !Number.isFinite(candidate)) {
            root.draftText = root.formattedValue(root.value);
            return;
        }

        const nextValue = root.clampedValue(candidate);
        root.draftText = root.formattedValue(nextValue);
        if (nextValue !== root.value)
            root.valueModified(nextValue);
    }

    function adjust(direction: int): void {
        const normalizedText = root.draftText.trim();
        const candidate = Number(normalizedText);
        const baseValue = normalizedText.length > 0 && Number.isFinite(candidate)
            ? root.clampedValue(candidate)
            : root.value;
        const nextValue = root.clampedValue(baseValue + direction * root.effectiveStepSize);
        root.draftText = root.formattedValue(nextValue);
        if (nextValue !== root.value)
            root.valueModified(nextValue);
    }

    implicitWidth: controlRow.implicitWidth
    implicitHeight: 32

    component StepButton: AbstractButton {
        id: stepButton

        property string iconName: ""

        implicitWidth: 28
        implicitHeight: 28
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        opacity: enabled ? 1 : Theme.disabledContentOpacity

        background: Rectangle {
            radius: Metrics.radiusSm
            color: Theme.scheme.surfaceContainerHighest

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.scheme.onSurface
                opacity: stepButton.down
                    ? Theme.statePressedOpacity
                    : stepButton.hovered
                        ? Theme.stateHoverOpacity
                        : stepButton.visualFocus
                            ? Theme.stateFocusOpacity
                            : 0

                Behavior on opacity {
                    NumberAnimation { duration: Motion.durationShort }
                }
            }
        }

        contentItem: M3Icon {
            name: stepButton.iconName
            size: 18
            color: Theme.scheme.onSurfaceVariant
        }

        HoverHandler {
            cursorShape: stepButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }

    RowLayout {
        id: controlRow

        anchors.verticalCenter: parent.verticalCenter
        spacing: Metrics.spacingXs

        TextField {
            id: valueInput

            Layout.preferredWidth: Math.max(44, Math.min(120, valueMetrics.advanceWidth + leftPadding + rightPadding))
            Layout.preferredHeight: 28
            leftPadding: Metrics.spacingMd
            rightPadding: Metrics.spacingMd
            topPadding: 0
            bottomPadding: 0

            text: root.draftText
            color: Theme.scheme.onSurface
            selectionColor: Theme.scheme.primary
            selectedTextColor: Theme.scheme.onPrimary
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            font.family: Typography.family
            font.pixelSize: 13
            Accessible.name: root.accessibleName

            TextMetrics {
                id: valueMetrics

                font: valueInput.font
                text: valueInput.text.length > 0 ? valueInput.text : "0"
            }

            validator: DoubleValidator {
                bottom: root.from
                top: root.to
                decimals: root.effectiveDecimals
                notation: DoubleValidator.StandardNotation
            }

            background: Rectangle {
                radius: Metrics.radiusFull
                color: Theme.scheme.surfaceContainerHigh
                border.width: valueInput.activeFocus ? 1 : 0
                border.color: Theme.scheme.primary
            }

            onTextEdited: root.draftText = text
            onEditingFinished: root.commit()
            onAccepted: root.commit()

            Keys.onUpPressed: event => {
                root.adjust(1);
                event.accepted = true;
            }
            Keys.onDownPressed: event => {
                root.adjust(-1);
                event.accepted = true;
            }
            Keys.onEscapePressed: event => {
                root.draftText = root.formattedValue(root.value);
                valueInput.focus = false;
                event.accepted = true;
            }
        }

        StepButton {
            iconName: "keyboard_arrow_up"
            enabled: root.canIncrease
            Accessible.name: qsTr("Increase %1").arg(root.accessibleName)
            onClicked: root.adjust(1)
        }

        StepButton {
            iconName: "keyboard_arrow_down"
            enabled: root.canDecrease
            Accessible.name: qsTr("Decrease %1").arg(root.accessibleName)
            onClicked: root.adjust(-1)
        }
    }

    onValueChanged: {
        if (!valueInput.activeFocus)
            root.draftText = root.formattedValue(root.value);
    }
}
