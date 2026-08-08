pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

Column {
    id: root

    required property string namespaceName
    required property var group

    readonly property string groupTitle: String(root.group.name).replace(/(^|\s)\S/g, match => match.toUpperCase())

    spacing: Metrics.spacingSm

    // Section header
    M3Text {
        leftPadding: Metrics.spacingXs
        text: root.groupTitle
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.5
        color: Theme.scheme.onSurfaceVariant
        textFormat: Text.PlainText
    }

    // Card container for settings rows
    Rectangle {
        width: root.width
        implicitHeight: rows.implicitHeight
        radius: Metrics.radiusMd
        color: Theme.scheme.surfaceContainer

        Column {
            id: rows

            width: parent.width

            Repeater {
                model: root.group.entries

                delegate: SettingsRow {
                    required property int index
                    required property var modelData

                    width: rows.width
                    height: implicitHeight
                    namespaceName: root.namespaceName
                    settingName: modelData.name
                    definition: modelData.definition
                    showSeparator: index < root.group.entries.length - 1
                }
            }
        }
    }
}
