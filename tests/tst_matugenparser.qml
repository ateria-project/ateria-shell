import QtQuick
import QtTest
import "../platform/theme/MatugenParser.js" as MatugenParser

TestCase {
    name: "MatugenParser"

    readonly property var roleNames: [
        "primary", "on_primary", "primary_container", "on_primary_container",
        "primary_fixed", "primary_fixed_dim", "on_primary_fixed", "on_primary_fixed_variant",
        "secondary", "on_secondary", "secondary_container", "on_secondary_container",
        "secondary_fixed", "secondary_fixed_dim", "on_secondary_fixed", "on_secondary_fixed_variant",
        "tertiary", "on_tertiary", "tertiary_container", "on_tertiary_container",
        "tertiary_fixed", "tertiary_fixed_dim", "on_tertiary_fixed", "on_tertiary_fixed_variant",
        "error", "on_error", "error_container", "on_error_container", "surface", "surface_dim",
        "surface_bright", "surface_container_lowest", "surface_container_low", "surface_container",
        "surface_container_high", "surface_container_highest", "on_surface", "on_surface_variant",
        "surface_variant", "surface_tint", "outline", "outline_variant", "inverse_surface",
        "inverse_on_surface", "inverse_primary", "scrim", "shadow"
    ]

    function completeOutput(): string {
        const colors = {};
        for (const role of roleNames) {
            colors[role] = {
                light: { color: "#112233" },
                dark: { color: "#ddeeff" }
            };
        }
        return JSON.stringify({ colors });
    }

    function test_mapsMaterialRoles() {
        const result = MatugenParser.parse(completeOutput());

        verify(result.valid);
        compare(result.light.primaryContainer, "#112233");
        compare(result.dark.onSurfaceVariant, "#ddeeff");
        compare(Object.keys(result.light).length, roleNames.length);
    }

    function test_rejectsMissingRole() {
        const document = JSON.parse(completeOutput());
        delete document.colors.primary;

        const result = MatugenParser.parse(JSON.stringify(document));

        verify(!result.valid);
        verify(result.error.includes("primary.light"));
    }

    function test_rejectsInvalidJson() {
        const result = MatugenParser.parse("not json");

        verify(!result.valid);
        verify(result.error.startsWith("Invalid JSON:"));
    }

    function test_acceptsStoredSchemes() {
        const parsed = MatugenParser.parse(completeOutput());
        const restored = MatugenParser.parseSchemes(parsed.light, parsed.dark);

        verify(restored.valid);
        compare(restored.light.primaryContainer, "#112233");
        compare(restored.dark.onSurfaceVariant, "#ddeeff");
    }

    function test_rejectsStoredSchemeWithMissingRole() {
        const parsed = MatugenParser.parse(completeOutput());
        const light = Object.assign({}, parsed.light);
        delete light.primary;

        const restored = MatugenParser.parseSchemes(light, parsed.dark);

        verify(!restored.valid);
        verify(restored.error.includes("light"));
    }

    function test_rejectsStoredSchemeWithInvalidColor() {
        const parsed = MatugenParser.parse(completeOutput());
        const dark = Object.assign({}, parsed.dark);
        dark.primary = "green";

        const restored = MatugenParser.parseSchemes(parsed.light, dark);

        verify(!restored.valid);
    }
}
