pragma Singleton

import QtQuick

QtObject {
    property bool bluetoothPageActive: false
    property bool inlinePromptAvailable: false

    readonly property bool useInlinePrompt: bluetoothPageActive && inlinePromptAvailable
}
