pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var preferredMusicApplications: MediaSettings.preferredMusicApplications
    readonly property var browserApplications: MediaSettings.browserApplications
    readonly property var configuredApplications: MediaSettings.applications.map(value => root.normalizedApplicationName(value)).filter(value => value.length > 0)
    readonly property var players: Mpris.players.values
    readonly property var activePlayer: {
        let selectedPlayer = null;
        let selectedScore = -1;

        for (let index = 0; index < root.players.length; ++index) {
            const player = root.players[index];
            if (!root.playerIsAllowed(player))
                continue;

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

    function normalizedApplicationName(value): string {
        return String(value ?? "").trim().toLowerCase().replace(/\.desktop$/, "");
    }

    function playerApplicationNames(player): var {
        if (player === null || player === undefined)
            return [];

        return [
            root.normalizedApplicationName(player.desktopEntry),
            root.normalizedApplicationName(player.identity),
            root.normalizedApplicationName(player.dbusName)
        ].filter(value => value.length > 0);
    }

    function applicationIsAllowed(player): bool {
        const filterMode = MediaSettings.applicationFilterMode;
        if (filterMode === MediaSettings.showAll)
            return true;

        const applicationNames = root.playerApplicationNames(player);
        const isListed = root.configuredApplications.some(name => applicationNames.indexOf(name) !== -1);

        if (filterMode === MediaSettings.showOnlyListed)
            return isListed;

        return !isListed;
    }



    function playerIsBrowser(player): bool {
        if (player === null || player === undefined)
            return false;

        return root.matchesHint(root.playerKey(player), root.browserApplications);
    }

    function playerIsAllowed(player): bool {
        return root.applicationIsAllowed(player);
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
        if (root.matchesHint(key, root.preferredMusicApplications))
            return 40;
        if (root.playerIsBrowser(player))
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
