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
    readonly property var defaultPreferredMusicWebsites: [
        "open.spotify.com",
        "music.apple.com",
        "listen.tidal.com",
        "deezer.com",
        "music.youtube.com",
        "soundcloud.com",
        "bandcamp.com"
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
            "websiteFilterMode": {
                type: "enum",
                defaultValue: root.showAll,
                options: [
                    { id: root.showAll, label: qsTr("All websites") },
                    { id: root.showOnlyListed, label: qsTr("Only listed websites") },
                    { id: root.showAllExceptListed, label: qsTr("All except listed websites") }
                ],
                label: qsTr("Website filter"),
                description: qsTr("Choose which websites the media widget can use in browser apps. Native media apps are not affected."),
                group: "source filters",
                order: 30
            },
            "websites": {
                type: "list",
                items: { type: "string" },
                defaultValue: [],
                label: qsTr("Websites"),
                description: qsTr("Exact domains such as music.youtube.com or open.spotify.com. “youtube.com” and “music.youtube.com” are treated separately; use “*.youtube.com” to match every subdomain. Only browser apps are checked."),
                group: "source filters",
                order: 40
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
            "preferredMusicWebsites": {
                type: "list",
                items: { type: "string" },
                defaultValue: root.defaultPreferredMusicWebsites,
                label: qsTr("Preferred music websites"),
                description: qsTr("Prioritize browser media whose track URL matches one of these domains."),
                group: "player priority",
                order: 60
            },
            "browserApplications": {
                type: "list",
                items: { type: "string" },
                defaultValue: root.defaultBrowserApplications,
                label: qsTr("Browser apps"),
                description: qsTr("Treat matches from this list as browsers, so dedicated music apps are preferred when both are available."),
                group: "player priority",
                order: 70
            }
        })

    readonly property string applicationFilterMode: SettingsService.value("media", "applicationFilterMode") || root.showAll
    readonly property var applications: SettingsService.value("media", "applications") || []
    readonly property string websiteFilterMode: SettingsService.value("media", "websiteFilterMode") || root.showAll
    readonly property var websites: SettingsService.value("media", "websites") || []
    readonly property var preferredMusicApplications: SettingsService.value("media", "preferredMusicApplications") || root.defaultPreferredMusicApplications
    readonly property var preferredMusicWebsites: SettingsService.value("media", "preferredMusicWebsites") || root.defaultPreferredMusicWebsites
    readonly property var browserApplications: SettingsService.value("media", "browserApplications") || root.defaultBrowserApplications

    function setApplicationFilterMode(value): bool {
        return SettingsService.setValue("media", "applicationFilterMode", value);
    }

    function setApplications(value): bool {
        return SettingsService.setValue("media", "applications", value);
    }

    function setWebsiteFilterMode(value): bool {
        return SettingsService.setValue("media", "websiteFilterMode", value);
    }

    function setWebsites(value): bool {
        return SettingsService.setValue("media", "websites", value);
    }

    function setPreferredMusicApplications(value): bool {
        return SettingsService.setValue("media", "preferredMusicApplications", value);
    }

    function setPreferredMusicWebsites(value): bool {
        return SettingsService.setValue("media", "preferredMusicWebsites", value);
    }

    function setBrowserApplications(value): bool {
        return SettingsService.setValue("media", "browserApplications", value);
    }
}
