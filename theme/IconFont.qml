pragma Singleton

import QtQuick

// Memory-efficient subset of Material Symbols Outlined.
//
// Qt keeps one mapped copy of a variable font per distinct variable-axis
// combination it renders. The full Material Symbols font is ~10 MB, so a bar
// and the lazily loaded panels can end up mapping it a dozen times. This subset
// keeps only the icon glyphs used by the shell and preserves the variable
// axes, which makes rendering pixel-identical while keeping each mapping small.
//
// Regenerate it with tools/ateria-icon-font after adding or renaming icons.
// Source: Material Symbols Outlined, Copyright Google LLC, Apache-2.0.
QtObject {
    id: root

    readonly property string family: iconFontLoader.name.length > 0
        ? iconFontLoader.name
        : "Material Symbols Outlined"

    property FontLoader iconFontLoader: FontLoader {
        source: Qt.resolvedUrl("../assets/MaterialSymbolsOutlined-Ateria.ttf")
    }
}
