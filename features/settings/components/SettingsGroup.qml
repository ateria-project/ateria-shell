pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

Column {
    id: root

    required property string namespaceName
    required property var group

    signal editListRequested(string settingName, var definition)

    readonly property string groupTitle: String(root.group.name).replace(/(^|\s)\S/g, match => match.toUpperCase())

    spacing: Metrics.spacingSm

    // Section header
    M3Text {
        leftPadding: Metrics.spacingXs
        text: root.groupTitle
        font.pixelSize: 13
        font.weight: Font.Medium
        color: Theme.scheme.onSurfaceVariant
        textFormat: Text.PlainText
    }

    // Compact, individually surfaced settings rows
    Column {
        id: rows

        width: root.width
        spacing: Metrics.spacingXs

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
                firstInGroup: index === 0
                lastInGroup: index === root.group.entries.length - 1
                onEditListRequested: (settingName, definition) => root.editListRequested(settingName, definition)
            }
        }
    }
}
