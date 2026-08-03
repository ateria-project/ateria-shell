import QtQuick
import qs.theme

Text {
    id: root

    property string name: ""
    property int size: 24
    property bool filled: false
    property real weight: 400
    property real grade: 0
    property real opticalSize: root.size

    text: root.name
    textFormat: Text.PlainText
    renderType: root.filled ? Text.CurveRendering : Text.QtRendering
    color: Theme.scheme.onSurface
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    maximumLineCount: 1
    wrapMode: Text.NoWrap
    font.family: "Material Symbols Rounded"
    font.pixelSize: root.size
    font.features: {
        "liga": 1
    }
    font.variableAxes: {
        "FILL": root.filled ? 1 : 0,
        "wght": Math.max(100, Math.min(700, root.weight)),
        "GRAD": Math.max(-50, Math.min(200, root.grade)),
        "opsz": Math.max(20, Math.min(48, root.opticalSize))
    }
}
