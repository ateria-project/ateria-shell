pragma Singleton

import QtQuick
import qs.features.example
import qs.features.wallpaper
import qs.platform.settings

QtObject {
    property bool initialized: false

    function initialize() {
        if (initialized)
            return;

        initialized = true;

        // All active schemas must be registered before SettingsService.load().
        // Unknown JSON keys are removed during reconciliation, so omitting a
        // schema here will remove its persisted settings.
        let registrationSucceeded = true;
        registrationSucceeded = SettingsService.registerSchema(ExampleSettings.schema) && registrationSucceeded;
        registrationSucceeded = SettingsService.registerSchema(WallpaperSettings.schema) && registrationSucceeded;

        if (!registrationSucceeded) {
            console.error("SettingsBootstrap: schema registration failed");
            return;
        }

        SettingsService.load();
    }
}
