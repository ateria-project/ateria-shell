pragma Singleton

import QtQuick
import qs.platform.settings

QtObject {
    id: root

    readonly property string allApplications: "All apps"
    readonly property string onlyListedApplications: "Only listed apps"
    readonly property string allExceptListedApplications: "All except listed apps"
    readonly property string allWebsites: "All websites"
    readonly property string onlyListedWebsites: "Only listed websites"
    readonly property string allExceptListedWebsites: "All except listed websites"

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
            "media.applicationFilterMode": {
                type: "enum",
                defaultValue: root.allApplications,
                options: [root.allApplications, root.onlyListedApplications, root.allExceptListedApplications],
                label: qsTr("App filter"),
                description: qsTr("Choose which apps the media widget can use."),
                group: "source filters",
                order: 10
            },
            "media.applications": {
                type: "string",
                defaultValue: "",
                label: qsTr("Apps"),
                description: qsTr("Enter app names or desktop entry IDs, separated by commas or new lines. Used by the app filter above."),
                group: "source filters",
                order: 20
            },
            "media.websiteFilterMode": {
                type: "enum",
                defaultValue: root.allWebsites,
                options: [root.allWebsites, root.onlyListedWebsites, root.allExceptListedWebsites],
                label: qsTr("Website filter"),
                description: qsTr("Choose which websites the media widget can use in browser apps. Native media apps are not affected."),
                group: "source filters",
                order: 30
            },
            "media.websites": {
                type: "string",
                defaultValue: "",
                label: qsTr("Websites"),
                description: qsTr("Enter exact domains such as music.youtube.com or open.spotify.com, separated by commas or new lines. “youtube.com” and “music.youtube.com” are treated separately; use “*.youtube.com” to match every subdomain. Only browser apps are checked."),
                group: "source filters",
                order: 40
            },
            "media.preferredMusicApplications": {
                type: "string",
                defaultValue: root.defaultPreferredMusicApplications.join("\n"),
                label: qsTr("Preferred music apps"),
                description: qsTr("When several apps have media, prioritize matches from this list. Enter app names or desktop entry IDs, separated by commas or new lines."),
                group: "player priority",
                order: 50
            },
            "media.preferredMusicWebsites": {
                type: "string",
                defaultValue: root.defaultPreferredMusicWebsites.join("\n"),
                label: qsTr("Preferred music websites"),
                description: qsTr("Prioritize browser media whose track URL matches one of these websites. Enter domains separated by commas or new lines."),
                group: "player priority",
                order: 60
            },
            "media.browserApplications": {
                type: "string",
                defaultValue: root.defaultBrowserApplications.join("\n"),
                label: qsTr("Browser apps"),
                description: qsTr("Treat matches from this list as browsers, so dedicated music apps are preferred when both are available."),
                group: "player priority",
                order: 70
            }
        })

    readonly property string applicationFilterMode: SettingsService.value("media.applicationFilterMode") || root.allApplications
    readonly property string applications: SettingsService.value("media.applications") || ""
    readonly property string websiteFilterMode: SettingsService.value("media.websiteFilterMode") || root.allWebsites
    readonly property string websites: SettingsService.value("media.websites") || ""
    readonly property var preferredMusicApplications: root.parseList(SettingsService.value("media.preferredMusicApplications"), root.defaultPreferredMusicApplications)
    readonly property var preferredMusicWebsites: root.parseList(SettingsService.value("media.preferredMusicWebsites"), root.defaultPreferredMusicWebsites)
    readonly property var browserApplications: root.parseList(SettingsService.value("media.browserApplications"), root.defaultBrowserApplications)

    function parseList(value, fallback): var {
        if (value === undefined || value === null)
            return fallback;

        return String(value).split(/[,\n]/).map(item => item.trim().toLowerCase()).filter(item => item.length > 0);
    }

    function setApplicationFilterMode(value): bool {
        return SettingsService.setValue("media.applicationFilterMode", value);
    }

    function setApplications(value): bool {
        return SettingsService.setValue("media.applications", String(value || ""));
    }

    function setWebsiteFilterMode(value): bool {
        return SettingsService.setValue("media.websiteFilterMode", value);
    }

    function setWebsites(value): bool {
        return SettingsService.setValue("media.websites", String(value || ""));
    }

    function setPreferredMusicApplications(value): bool {
        return SettingsService.setValue("media.preferredMusicApplications", String(value || ""));
    }

    function setPreferredMusicWebsites(value): bool {
        return SettingsService.setValue("media.preferredMusicWebsites", String(value || ""));
    }

    function setBrowserApplications(value): bool {
        return SettingsService.setValue("media.browserApplications", String(value || ""));
    }
}
