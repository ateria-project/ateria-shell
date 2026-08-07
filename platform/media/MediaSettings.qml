pragma Singleton

import QtQuick
import qs.platform.settings

QtObject {
    id: root

    readonly property string showAll: "all"
    readonly property string showOnlyListed: "only-listed"
    readonly property string showAllExceptListed: "all-except-listed"

    readonly property var defaultPreferredMusicApplications: [
        "spotify",
        "ncspot",
        "cider",
        "apple-music",
        "apple music",
        "youtube-music",
        "youtube music",
        "tidal",
        "deezer",
        "rhythmbox",
        "lollypop",
        "amberol",
        "elisa",
        "audacious",
        "strawberry",
        "cantata",
        "quodlibet",
        "quod libet",
        "tauon",
        "gnome-music",
        "gnome.music",
        "g4music",
        "nuclear",
        "feishin",
        "cmus",
        "pithos",
        "shortwave",
        "gpodder",
        "kasts",
        "pocket-casts",
        "pocket casts",
        "music player daemon"
    ]

    readonly property var defaultBrowserApplications: [
        "chromium",
        "chrome",
        "firefox",
        "brave",
        "vivaldi",
        "helium",
        "opera",
        "microsoft-edge",
        "zen-browser",
        "floorp"
    ]

    readonly property var schema: ({
            "applicationFilterMode": {
                type: "enum",
                defaultValue: root.showAll,
                options: [
                    { id: root.showAll, label: qsTr("All apps") },
                    { id: root.showOnlyListed, label: qsTr("Only listed apps") },
                    { id: root.showAllExceptListed, label: qsTr("All except listed apps") }
                ],
                label: qsTr("App filter"),
                description: qsTr("Choose which apps the media widget can use."),
                group: "source filters",
                order: 10
            },
            "applications": {
                type: "list",
                items: { type: "string" },
                defaultValue: [],
                label: qsTr("Apps"),
                description: qsTr("App names or desktop entry IDs used by the app filter above."),
                group: "source filters",
                order: 20
            },

            "preferredMusicApplications": {
                type: "list",
                items: { type: "string" },
                defaultValue: root.defaultPreferredMusicApplications,
                label: qsTr("Preferred music apps"),
                description: qsTr("When several apps have media, prioritize app names or desktop entry IDs in this list."),
                group: "player priority",
                order: 50
            },

            "browserApplications": {
                type: "list",
                items: { type: "string" },
                defaultValue: root.defaultBrowserApplications,
                label: qsTr("Browser apps"),
                description: qsTr("Treat matches from this list as browsers, so dedicated music apps are preferred when both are available."),
                group: "player priority",
                order: 70
            },
            "hideWhenInactive": {
                type: "bool",
                defaultValue: true,
                label: qsTr("Hide when inactive"),
                description: qsTr("Automatically hide the media widget after being paused for a specified duration."),
                group: "visibility",
                order: 80
            },
            "inactiveTimeout": {
                type: "int",
                minimum: 1,
                defaultValue: 300,
                label: qsTr("Inactivity timeout (seconds)"),
                description: qsTr("How many seconds to wait after playback is paused before hiding the media widget."),
                group: "visibility",
                order: 90
            }
        })

    readonly property string applicationFilterMode: SettingsService.value("media", "applicationFilterMode") || root.showAll
    readonly property var applications: SettingsService.value("media", "applications") || []
    readonly property var preferredMusicApplications: SettingsService.value("media", "preferredMusicApplications") || root.defaultPreferredMusicApplications
    readonly property var browserApplications: SettingsService.value("media", "browserApplications") || root.defaultBrowserApplications
    readonly property bool hideWhenInactive: SettingsService.value("media", "hideWhenInactive") ?? false
    readonly property int inactiveTimeout: SettingsService.value("media", "inactiveTimeout") ?? 10

    function setApplicationFilterMode(value): bool {
        return SettingsService.setValue("media", "applicationFilterMode", value);
    }

    function setApplications(value): bool {
        return SettingsService.setValue("media", "applications", value);
    }

    function setPreferredMusicApplications(value): bool {
        return SettingsService.setValue("media", "preferredMusicApplications", value);
    }

    function setBrowserApplications(value): bool {
        return SettingsService.setValue("media", "browserApplications", value);
    }

    function setHideWhenInactive(value): bool {
        return SettingsService.setValue("media", "hideWhenInactive", value);
    }

    function setInactiveTimeout(value): bool {
        return SettingsService.setValue("media", "inactiveTimeout", value);
    }
}
