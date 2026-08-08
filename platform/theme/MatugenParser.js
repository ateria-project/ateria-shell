.pragma library

const roleNames = {
    "primary": "primary",
    "onPrimary": "on_primary",
    "primaryContainer": "primary_container",
    "onPrimaryContainer": "on_primary_container",
    "primaryFixed": "primary_fixed",
    "primaryFixedDim": "primary_fixed_dim",
    "onPrimaryFixed": "on_primary_fixed",
    "onPrimaryFixedVariant": "on_primary_fixed_variant",
    "secondary": "secondary",
    "onSecondary": "on_secondary",
    "secondaryContainer": "secondary_container",
    "onSecondaryContainer": "on_secondary_container",
    "secondaryFixed": "secondary_fixed",
    "secondaryFixedDim": "secondary_fixed_dim",
    "onSecondaryFixed": "on_secondary_fixed",
    "onSecondaryFixedVariant": "on_secondary_fixed_variant",
    "tertiary": "tertiary",
    "onTertiary": "on_tertiary",
    "tertiaryContainer": "tertiary_container",
    "onTertiaryContainer": "on_tertiary_container",
    "tertiaryFixed": "tertiary_fixed",
    "tertiaryFixedDim": "tertiary_fixed_dim",
    "onTertiaryFixed": "on_tertiary_fixed",
    "onTertiaryFixedVariant": "on_tertiary_fixed_variant",
    "error": "error",
    "onError": "on_error",
    "errorContainer": "error_container",
    "onErrorContainer": "on_error_container",
    "surface": "surface",
    "surfaceDim": "surface_dim",
    "surfaceBright": "surface_bright",
    "surfaceContainerLowest": "surface_container_lowest",
    "surfaceContainerLow": "surface_container_low",
    "surfaceContainer": "surface_container",
    "surfaceContainerHigh": "surface_container_high",
    "surfaceContainerHighest": "surface_container_highest",
    "onSurface": "on_surface",
    "onSurfaceVariant": "on_surface_variant",
    "surfaceVariant": "surface_variant",
    "surfaceTint": "surface_tint",
    "outline": "outline",
    "outlineVariant": "outline_variant",
    "inverseSurface": "inverse_surface",
    "inverseOnSurface": "inverse_on_surface",
    "inversePrimary": "inverse_primary",
    "scrim": "scrim",
    "shadow": "shadow"
};

function hasOwn(object, key) {
    return object !== null && object !== undefined && Object.prototype.hasOwnProperty.call(object, key);
}

function scheme(colors, mode) {
    const result = {};

    for (const role of Object.keys(roleNames)) {
        const matugenRole = roleNames[role];
        if (!hasOwn(colors, matugenRole)
                || !hasOwn(colors[matugenRole], mode)
                || typeof colors[matugenRole][mode].color !== "string"
                || !/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(colors[matugenRole][mode].color))
            return { valid: false, error: "Missing or invalid color role: " + matugenRole + "." + mode };

        result[role] = colors[matugenRole][mode].color;
    }

    return { valid: true, value: result };
}

function parse(text) {
    let document;
    try {
        document = JSON.parse(String(text));
    } catch (error) {
        return { valid: false, error: "Invalid JSON: " + String(error) };
    }

    if (document === null || typeof document !== "object" || document.colors === null || typeof document.colors !== "object")
        return { valid: false, error: "Matugen output does not contain colors" };

    const light = scheme(document.colors, "light");
    if (!light.valid)
        return light;

    const dark = scheme(document.colors, "dark");
    if (!dark.valid)
        return dark;

    return { valid: true, light: light.value, dark: dark.value };
}
