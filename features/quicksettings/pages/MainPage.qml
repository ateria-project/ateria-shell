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

                onClicked: powerMenu.open()

                Popup {
                    id: powerMenu

                    x: 0
                    y: -height - 8
                    width: 160
                    padding: 6
                    modal: true
                    dim: false
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                    background: Rectangle {
                        radius: 16
                        color: Theme.scheme.surfaceContainerHigh
                        border.width: 1
                        border.color: Theme.scheme.outlineVariant
                    }

                    contentItem: ColumnLayout {
                        spacing: 2

                        M3Button {
                            text: "Lock"
                            iconName: "lock"
                            iconSize: 18
                            Layout.fillWidth: true
                            style: M3Button.Text
                            contentColor: Theme.scheme.onSurface
                            onClicked: {
                                powerMenu.close();
                                PowerService.lock();
                            }
                        }

                        M3Button {
                            text: "Reboot"
                            iconName: "restart_alt"
                            iconSize: 18
                            Layout.fillWidth: true
                            style: M3Button.Text
                            contentColor: Theme.scheme.onSurface
                            onClicked: {
                                powerMenu.close();
                                PowerService.reboot();
                            }
                        }

                        M3Button {
                            text: "Shutdown"
                            iconName: "power_settings_new"
                            iconSize: 18
                            Layout.fillWidth: true
                            style: M3Button.Text
                            contentColor: Theme.scheme.error
                            onClicked: {
                                powerMenu.close();
                                PowerService.shutdown();
                            }
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
}
