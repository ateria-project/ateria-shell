import QtQuick
import QtTest
import "../platform/media/MediaSettings.qml" as MediaSettingsModule

TestCase {
    name: "MediaInactiveSettings"

    function test_mediaSettingsSchemaIncludesInactiveSettings() {
        const schema = MediaSettingsModule.MediaSettings.schema;

        verify("hideWhenInactive" in schema);
        compare(schema.hideWhenInactive.type, "bool");
        compare(schema.hideWhenInactive.defaultValue, false);

        verify("inactiveTimeout" in schema);
        compare(schema.inactiveTimeout.type, "int");
        compare(schema.inactiveTimeout.minimum, 1);
        compare(schema.inactiveTimeout.defaultValue, 10);
    }
}
