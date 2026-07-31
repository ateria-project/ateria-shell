pragma Singleton
import QtQuick

/*
 * Material 3 color-role theme singleton.
 */
QtObject {
    id: theme

    // Scheme selection
    property bool darkMode: true
    // Common Material 3 state opacities.
    readonly property real stateHoverOpacity: 0.08
    readonly property real stateFocusOpacity: 0.1
    readonly property real statePressedOpacity: 0.1
    readonly property real stateDraggedOpacity: 0.16
    readonly property real disabledContainerOpacity: 0.12
    readonly property real disabledContentOpacity: 0.38

    readonly property var lightScheme: ({
            "primary": "#006a60",
            "onPrimary": "#ffffff",
            "primaryContainer": "#9ef2e4",
            "onPrimaryContainer": "#00201c",
            "primaryFixed": "#9ef2e4",
            "primaryFixedDim": "#82d5c8",
            "onPrimaryFixed": "#00201c",
            "onPrimaryFixedVariant": "#005048",
            "secondary": "#4a635e",
            "onSecondary": "#ffffff",
            "secondaryContainer": "#cce8e2",
            "onSecondaryContainer": "#06201c",
            "secondaryFixed": "#cce8e2",
            "secondaryFixedDim": "#b1ccc6",
            "onSecondaryFixed": "#06201c",
            "onSecondaryFixedVariant": "#334b47",
            "tertiary": "#446179",
            "onTertiary": "#ffffff",
            "tertiaryContainer": "#cce5ff",
            "onTertiaryContainer": "#001e2f",
            "tertiaryFixed": "#cce5ff",
            "tertiaryFixedDim": "#adcae6",
            "onTertiaryFixed": "#001e2f",
            "onTertiaryFixedVariant": "#2d4961",
            "error": "#ba1a1a",
            "onError": "#ffffff",
            "errorContainer": "#ffdad6",
            "onErrorContainer": "#410002",
            "surface": "#f4fbf8",
            "surfaceDim": "#d5dbd8",
            "surfaceBright": "#f4fbf8",
            "surfaceContainerLowest": "#ffffff",
            "surfaceContainerLow": "#eef5f2",
            "surfaceContainer": "#e9efed",
            "surfaceContainerHigh": "#e3eae7",
            "surfaceContainerHighest": "#dde4e1",
            "onSurface": "#161d1b",
            "onSurfaceVariant": "#3f4947",
            "surfaceVariant": "#bec9c6",
            "surfaceTint": "#006a60",
            "outline": "#6f7976",
            "outlineVariant": "#bec9c6",
            "inverseSurface": "#2b3230",
            "inverseOnSurface": "#ecf2ef",
            "inversePrimary": "#82d5c8",
            "scrim": "#000000",
            "shadow": "#000000"
        })
    readonly property var darkScheme: ({
            "primary": "#82d5c8",
            "onPrimary": "#003731",
            "primaryContainer": "#005048",
            "onPrimaryContainer": "#9ef2e4",
            "primaryFixed": "#9ef2e4",
            "primaryFixedDim": "#82d5c8",
            "onPrimaryFixed": "#00201c",
            "onPrimaryFixedVariant": "#005048",
            "secondary": "#b1ccc6",
            "onSecondary": "#1c3531",
            "secondaryContainer": "#334b47",
            "onSecondaryContainer": "#cce8e2",
            "secondaryFixed": "#cce8e2",
            "secondaryFixedDim": "#b1ccc6",
            "onSecondaryFixed": "#06201c",
            "onSecondaryFixedVariant": "#334b47",
            "tertiary": "#adcae6",
            "onTertiary": "#153349",
            "tertiaryContainer": "#2d4961",
            "onTertiaryContainer": "#cce5ff",
            "tertiaryFixed": "#cce5ff",
            "tertiaryFixedDim": "#adcae6",
            "onTertiaryFixed": "#001e2f",
            "onTertiaryFixedVariant": "#2d4961",
            "error": "#ffb4ab",
            "onError": "#690005",
            "errorContainer": "#93000a",
            "onErrorContainer": "#ffdad6",
            "surface": "#0e1513",
            "surfaceDim": "#0e1513",
            "surfaceBright": "#343b39",
            "surfaceContainerLowest": "#090f0e",
            "surfaceContainerLow": "#161d1c",
            "surfaceContainer": "#1a2120",
            "surfaceContainerHigh": "#252b2a",
            "surfaceContainerHighest": "#303635",
            "onSurface": "#dde4e1",
            "onSurfaceVariant": "#bec9c6",
            "surfaceVariant": "#3f4947",
            "surfaceTint": "#82d5c8",
            "outline": "#899390",
            "outlineVariant": "#3f4947",
            "inverseSurface": "#dde4e1",
            "inverseOnSurface": "#2b3230",
            "inversePrimary": "#006a60",
            "scrim": "#000000",
            "shadow": "#000000"
        })

    // Active semantic roles
    readonly property var scheme: darkMode ? darkScheme : lightScheme

    function setDarkMode(enabled) {
        darkMode = enabled;
    }

    function toggleDarkMode() {
        darkMode = !darkMode;
    }

    // Creates a Material state-layer color from an existing role.
    function stateLayer(colorRole, opacity) {
        return Qt.rgba(colorRole.r, colorRole.g, colorRole.b, opacity);
    }
}
