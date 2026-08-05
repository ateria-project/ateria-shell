import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.components
import qs.features.quicksettings.components
import qs.features.quicksettings.tiles
import qs.platform.audio
import qs.platform.bluetooth
import qs.platform.display
import qs.platform.network
import qs.platform.power
import Quickshell.Services.UPower
import qs.shell
import qs.theme

M3Panel {
    id: root

    property var controller: null

    implicitWidth: 396
    implicitHeight: mainLayout.implicitHeight + 32

    ColumnLayout {
        id: mainLayout

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 16
            rightMargin: 16
            topMargin: 16
            bottomMargin: 16
        }

        spacing: 24

        // Quicksettings buttons
        GridLayout {
            id: tileGrid

            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            QuickSettingsTile {
                active: NetworkService.wifiEnabled
                iconName: NetworkService.wifiIconName
                title: "Wi-Fi"
                subtitle: NetworkService.wifiStatusText
                showDetails: true
                Layout.fillWidth: true
                onClicked: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
            }

            QuickSettingsTile {
                active: false
                iconName: "screen_record"
                title: "Screen record"
                subtitle: "Ready"
                showDetails: false
                Layout.fillWidth: true
            }

            QuickSettingsTile {
                active: BluetoothService.enabled
                iconName: BluetoothService.iconName
                title: "Bluetooth"
                subtitle: BluetoothService.statusText
                showDetails: true
                Layout.fillWidth: true
                onClicked: BluetoothService.toggleEnabled()
            }

            QuickSettingsTile {
                active: false
                iconName: "do_not_disturb_on"
                title: "Do Not Disturb"
                subtitle: "Off"
                showDetails: false
                Layout.fillWidth: true
            }
        }

        // Volume and brightness slider area
        ColumnLayout {
            spacing: 8

            RowLayout {
                spacing: 32

                M3Slider {
                    iconName: AudioService.outputIconName
                    iconFilled: false
                    iconSize: 24

                    from: 0
                    to: AudioService.maxOutputVolume
                    value: AudioService.outputVolume

                    live: true

                    Layout.fillWidth: true

                    onValueChangeRequested: requestedValue => AudioService.setOutputVolume(requestedValue)
                }

                M3Button {
                    iconName: "chevron_right"
                    iconSize: 24

                    style: M3Button.Text
                    onClicked: {
                        if (root.controller)
                            root.controller.pushPage("audio");
                    }
                }
            }

            RowLayout {
                spacing: 32

                M3Slider {
                    iconName: "brightness_7"
                    iconFilled: false
                    iconSize: 24

                    from: 0
                    to: 1
                    value: {
                        return BrightnessService.brightnessForScreen(SurfaceController.activeScreen);
                    }

                    live: true

                    Layout.fillWidth: true

                    onValueChangeRequested: requestedValue => BrightnessService.setScreenBrightness(SurfaceController.activeScreen, requestedValue)
                }

                M3Button {
                    iconName: "chevron_right"
                    iconSize: 24

                    style: M3Button.Text
                    onClicked: {
                        if (root.controller)
                            root.controller.pushPage("brightness");
                    }
                }
            }
        }

        // Footer
        RowLayout {
            spacing: 8

            M3Button {
                id: powerButton

                iconName: "power_settings_new"
                iconSize: 22

                style: M3Button.Tonal
                containerColor: Theme.scheme.surfaceContainerHighest
                Accessible.name: "Power menu"

                onClicked: powerMenu.open()

                Popup {
                    id: powerMenu

                    x: 0
                    y: -height - Metrics.spacingXs
                    width: 176
                    padding: Metrics.spacingXs
                    modal: true
                    dim: false
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    transformOrigin: Item.BottomLeft

                    enter: Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Motion.durationShort
                                easing.type: Motion.easingStandardDecelerate
                                easing.bezierCurve: Motion.standardDecelerateCurve
                            }

                            NumberAnimation {
                                property: "scale"
                                from: 0.96
                                to: 1
                                duration: Motion.durationShort
                                easing.type: Motion.easingStandardDecelerate
                                easing.bezierCurve: Motion.standardDecelerateCurve
                            }
                        }
                    }

                    exit: Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                property: "opacity"
                                from: 1
                                to: 0
                                duration: Motion.durationShort
                                easing.type: Motion.easingStandardAccelerate
                                easing.bezierCurve: Motion.standardAccelerateCurve
                            }

                            NumberAnimation {
                                property: "scale"
                                from: 1
                                to: 0.96
                                duration: Motion.durationShort
                                easing.type: Motion.easingStandardAccelerate
                                easing.bezierCurve: Motion.standardAccelerateCurve
                            }
                        }
                    }

                    background: Rectangle {
                        radius: Metrics.radiusSm
                        color: Theme.scheme.surfaceContainerHigh
                    }

                    contentItem: ColumnLayout {
                        spacing: 0

                        PowerMenuItem {
                            label: "Lock"
                            menuIcon: "lock"
                            onActivated: {
                                powerMenu.close();
                                PowerService.lock();
                            }
                            Layout.fillWidth: true
                        }

                        PowerMenuItem {
                            label: "Reboot"
                            menuIcon: "restart_alt"
                            onActivated: {
                                powerMenu.close();
                                PowerService.reboot();
                            }
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            Layout.bottomMargin: 2
                            Layout.preferredHeight: 1
                            color: Theme.scheme.outlineVariant
                            opacity: 0.5
                        }

                        PowerMenuItem {
                            label: "Shutdown"
                            menuIcon: "power_settings_new"
                            itemColor: Theme.scheme.error
                            onActivated: {
                                powerMenu.close();
                                PowerService.shutdown();
                            }
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            M3Button {
                iconName: {
                    switch (PowerService.powerProfile) {
                    case PowerProfile.Performance:
                        return "speed";
                    case PowerProfile.PowerSaver:
                        return "energy_savings_leaf";
                    default:
                        return "balance";
                    }
                }
                iconSize: 18
                text: PowerService.powerProfileName

                Layout.preferredHeight: 34
                Layout.preferredWidth: implicitWidth

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: Motion.durationMedium
                        easing.type: Easing.OutCubic
                    }
                }

                style: M3Button.Tonal
                containerColor: Theme.scheme.surfaceContainerHighest

                onClicked: PowerService.cyclePowerProfile()
            }

            Item {
                Layout.fillWidth: true
            }

            M3Text {
                text: {
                    if (!PowerService.hasBattery)
                        return "AC Power";

                    const pct = `${PowerService.percentageRounded}%`;

                    if (PowerService.fullyCharged)
                        return `Fully charged`;

                    if (PowerService.charging) {
                        if (PowerService.timeRemainingText.length > 0)
                            return `${pct} \u00B7 ${PowerService.timeRemainingText} until full`;
                        return `${pct} \u00B7 Charging`;
                    }

                    if (PowerService.discharging) {
                        if (PowerService.timeRemainingText.length > 0)
                            return `${pct} \u00B7 ${PowerService.timeRemainingText} left`;
                        return `${pct} \u00B7 Discharging`;
                    }

                    return `${pct} \u00B7 ${PowerService.stateText}`;
                }
                font.weight: Font.Medium
                font.pixelSize: 13
                color: Theme.scheme.onSurfaceVariant
            }

            Item {}

            M3Button {
                iconName: "settings"
                iconSize: 22

                style: M3Button.Tonal
                containerColor: Theme.scheme.surfaceContainerHighest
            }
        }
    }

    component PowerMenuItem: AbstractButton {
        id: menuItem

        property string label: ""
        property string menuIcon: ""
        property color itemColor: Theme.scheme.onSurfaceVariant

        signal activated

        implicitHeight: 34
        Layout.fillWidth: true
        padding: 0
        hoverEnabled: true
        Accessible.name: menuItem.label

        background: Rectangle {
            radius: Metrics.radiusSm
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: menuItem.itemColor
                opacity: {
                    if (menuItem.down)
                        return Theme.statePressedOpacity;
                    if (menuItem.hovered)
                        return Theme.stateHoverOpacity;
                    if (menuItem.visualFocus)
                        return Theme.stateFocusOpacity;
                    return 0;
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.durationShort
                        easing.type: Motion.easingStandard
                        easing.bezierCurve: Motion.standardCurve
                    }
                }
            }
        }

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Metrics.spacingSm
            anchors.rightMargin: Metrics.spacingSm
            spacing: Metrics.spacingSm

            M3Icon {
                name: menuItem.menuIcon
                size: 20
                color: menuItem.itemColor
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
            }

            M3Text {
                text: menuItem.label
                color: menuItem.itemColor
                font.pixelSize: 14
                font.weight: Font.Medium
                Layout.fillWidth: true
            }
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        onClicked: menuItem.activated()
    }
}
