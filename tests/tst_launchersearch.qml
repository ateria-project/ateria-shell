import QtQuick
import QtTest
import "../features/launcher/LauncherSearch.js" as LauncherSearch

TestCase {
    name: "LauncherSearch"

    readonly property double now: 1785772800000

    function application(name, id, extra) {
        return Object.assign({
            "name": name,
            "id": id || name.toLocaleLowerCase().replace(/\s+/g, "-") + ".desktop",
            "genericName": "",
            "comment": "",
            "keywords": [],
            "categories": [],
            "startupClass": "",
            "command": [],
            "execString": ""
        }, extra || {});
    }

    function names(results) {
        return results.map(entry => entry.name);
    }

    function test_prefixAndWordMatches() {
        const apps = [application("Visual Studio Code"), application("Code"), application("VSCodium")];
        compare(names(LauncherSearch.rankApplications(apps, "code", {}, now)), ["Code", "Visual Studio Code"]);
    }

    function test_fuzzyMissingLetterAndTransposition() {
        const apps = [application("Calculator"), application("Calendar")];
        compare(names(LauncherSearch.rankApplications(apps, "calclator", {}, now)), ["Calculator"]);
        compare(names(LauncherSearch.rankApplications(apps, "caluclator", {}, now)), ["Calculator"]);
    }

    function test_editDistanceOperations() {
        compare(LauncherSearch.editDistance("calculator", "calclator", 2), 1);
        compare(LauncherSearch.editDistance("calculator", "caluclator", 2), 1);
        compare(LauncherSearch.editDistance("calculator", "calculattor", 2), 1);
        compare(LauncherSearch.editDistance("calculator", "calculatpr", 2), 1);
        compare(LauncherSearch.editDistance("calculator", "calendar", 2), 3);
    }

    function test_prebuiltIndexCanBeReused() {
        const apps = [application("Calculator"), application("Calendar")];
        const index = LauncherSearch.createApplicationIndex(apps);
        const applicationUsage = LauncherSearch.createUsageData(index, {}, now);

        compare(names(LauncherSearch.rankPreparedApplicationIndex(index, "calc", applicationUsage)), ["Calculator"]);
        compare(names(LauncherSearch.rankPreparedApplicationIndex(index, "calen", applicationUsage)), ["Calendar"]);
    }

    function test_subsequenceAndAcronym() {
        const apps = [application("Visual Studio Code"), application("Virtual Machine Manager"), application("Firefox")];
        compare(names(LauncherSearch.rankApplications(apps, "vsc", {}, now)), ["Visual Studio Code"]);
        compare(names(LauncherSearch.rankApplications(apps, "frfx", {}, now)), ["Firefox"]);
    }

    function test_accentsAndDesktopMetadata() {
        const apps = [
            application("Résumé Builder"),
            application("Firefox", "firefox.desktop", { "keywords": ["browser", "internet", "web"] }),
            application("GNOME Terminal", "org.gnome.Terminal.desktop")
        ];

        compare(names(LauncherSearch.rankApplications(apps, "resume", {}, now)), ["Résumé Builder"]);
        compare(names(LauncherSearch.rankApplications(apps, "browser", {}, now)), ["Firefox"]);
        compare(names(LauncherSearch.rankApplications(apps, "org terminal", {}, now)), ["GNOME Terminal"]);
    }

    function test_everyQueryTermMustMatch() {
        const apps = [application("Firefox"), application("Files")];
        compare(LauncherSearch.rankApplications(apps, "fire music", {}, now).length, 0);
        compare(LauncherSearch.rankApplications(apps, "zzzz", {}, now).length, 0);
    }

    function test_usageRanksSimilarMatchesHigher() {
        const code = application("Visual Studio Code", "code.desktop");
        const codium = application("Visual Studio Codium", "codium.desktop");
        const history = {
            "desktop:codium.desktop": { "count": 20, "lastLaunched": now - 60000 }
        };

        compare(names(LauncherSearch.rankApplications([code, codium], "visual stud", history, now)), ["Visual Studio Codium", "Visual Studio Code"]);
    }

    function test_frequencyBreaksTiesBetweenSimilarMatches() {
        const alpha = application("Alpha", "alpha.desktop");
        const alpine = application("Alpine", "alpine.desktop");
        const history = {
            "desktop:alpine.desktop": { "count": 12, "lastLaunched": now }
        };

        compare(names(LauncherSearch.rankApplications([alpha, alpine], "al", history, now)), ["Alpine", "Alpha"]);
    }

    function test_exactNameStillWinsOverUsage() {
        const exact = application("Code", "code.desktop");
        const frequent = application("Visual Studio Code", "visual-studio-code.desktop");
        const history = {
            "desktop:visual-studio-code.desktop": { "count": 1000, "lastLaunched": now }
        };

        compare(names(LauncherSearch.rankApplications([frequent, exact], "code", history, now)), ["Code", "Visual Studio Code"]);
    }

    function test_frequentAndRecentAppsLeadEmptySearch() {
        const calculator = application("Calculator", "calculator.desktop");
        const calendar = application("Calendar", "calendar.desktop");
        const firefox = application("Firefox", "firefox.desktop");
        const history = {
            "desktop:calendar.desktop": { "count": 8, "lastLaunched": now - 30 * 86400000 },
            "desktop:firefox.desktop": { "count": 8, "lastLaunched": now - 60000 }
        };

        compare(names(LauncherSearch.rankApplications([calculator, calendar, firefox], "", history, now)), ["Firefox", "Calendar", "Calculator"]);
    }

    function test_initialListSortsByLaunchCountBeforeRecency() {
        const oldFavorite = application("Old Favorite", "old.desktop");
        const recentChoice = application("Recent Choice", "recent.desktop");
        const history = {
            "desktop:old.desktop": { "count": 1000, "lastLaunched": now - 365 * 86400000 },
            "desktop:recent.desktop": { "count": 1, "lastLaunched": now }
        };

        compare(names(LauncherSearch.rankApplications([oldFavorite, recentChoice], "", history, now)), ["Old Favorite", "Recent Choice"]);
    }
}
