pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var preferredMusicPlayerHints: [
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
    readonly property var preferredMusicUrlHints: [
        "open.spotify.com",
        "music.apple.com",
        "listen.tidal.com",
        "deezer.com",
        "music.youtube.com",
        "soundcloud.com",
        "bandcamp.com"
    ]
    readonly property var browserPlayerHints: [
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
    readonly property var players: Mpris.players.values
    readonly property var activePlayer: {
        let selectedPlayer = null;
        let selectedScore = -1;

        for (let index = 0; index < root.players.length; ++index) {
            const player = root.players[index];
            const score = root.playerScore(player);
            if (score > selectedScore) {
                selectedPlayer = player;
                selectedScore = score;
            }
        }

        return selectedPlayer;
    }
    readonly property bool available: root.activePlayer !== null
    readonly property bool isPlaying: root.available && root.activePlayer.isPlaying
    readonly property bool canTogglePlayback: root.available && (root.activePlayer.canTogglePlaying || (root.isPlaying ? root.activePlayer.canPause : root.activePlayer.canPlay))
    readonly property bool canGoNext: root.available && root.activePlayer.canGoNext
    readonly property string identity: root.available ? String(root.activePlayer.identity ?? "").trim() : ""
    readonly property string artist: {
        if (!root.available)
            return "";

        const trackArtist = String(root.activePlayer.trackArtist ?? "").trim();
        return trackArtist.length > 0 ? trackArtist : root.identity || qsTr("Unknown artist");
    }
    readonly property string title: {
        if (!root.available)
            return "";

        const trackTitle = String(root.activePlayer.trackTitle ?? "").trim();
        return trackTitle.length > 0 ? trackTitle : qsTr("Unknown title");
    }
    readonly property string artworkUrl: root.available ? String(root.activePlayer.trackArtUrl ?? "") : ""
    readonly property string displayText: root.available ? root.artist + " - " + root.title : ""

    function playerKey(player): string {
        return [
            player.identity ?? "",
            player.desktopEntry ?? "",
            player.dbusName ?? ""
        ].join(" ").toLowerCase();
    }

    function matchesHint(value: string, hints): bool {
        for (const hint of hints) {
            if (value.includes(hint))
                return true;
        }

        return false;
    }

    function playerKindScore(player): int {
        const key = root.playerKey(player);
        const metadata = player.metadata ?? {};
        const trackUrl = String(metadata["xesam:url"] ?? "").toLowerCase();
        if (root.matchesHint(key, root.preferredMusicPlayerHints) || root.matchesHint(trackUrl, root.preferredMusicUrlHints))
            return 40;
        if (root.matchesHint(key, root.browserPlayerHints))
            return -10;

        return 0;
    }

    function playerScore(player): int {
        if (player === null || player === undefined)
            return -1;

        let score;
        switch (player.playbackState) {
        case MprisPlaybackState.Playing:
            score = 300;
            break;
        case MprisPlaybackState.Paused:
            score = 200;
            break;
        default:
            score = 100;
            break;
        }

        score += root.playerKindScore(player);
        if (player.canControl)
            score += 4;
        if (String(player.trackTitle ?? "").trim().length > 0)
            score += 2;
        if (String(player.trackArtist ?? "").trim().length > 0)
            score += 1;
        if (String(player.trackArtUrl ?? "").length > 0)
            score += 1;

        return score;
    }

    function togglePlayback(): bool {
        const player = root.activePlayer;
        if (player === null)
            return false;

        if (player.canTogglePlaying) {
            player.togglePlaying();
            return true;
        }
        if (player.isPlaying && player.canPause) {
            player.pause();
            return true;
        }
        if (!player.isPlaying && player.canPlay) {
            player.play();
            return true;
        }

        return false;
    }

    function nextTrack(): bool {
        const player = root.activePlayer;
        if (player === null || !player.canGoNext)
            return false;

        player.next();
        return true;
    }
}
