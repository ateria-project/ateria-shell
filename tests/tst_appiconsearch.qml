import QtQuick
import QtTest
import "../platform/appicons/AppIconSearch.js" as AppIconSearch

TestCase {
    name: "AppIconSearch"

    function test_standardSearchRoots() {
        compare(AppIconSearch.searchRoots({
            "HOME": "/home/tester",
            "XDG_DATA_HOME": "/home/tester/.data",
            "XDG_DATA_DIRS": "/opt/share:/usr/share"
        }), [
            "/home/tester/.icons",
            "/home/tester/.data/icons",
            "/opt/share/icons",
            "/usr/share/icons",
            "/opt/share/pixmaps",
            "/usr/share/pixmaps"
        ]);
    }

    function test_findCommandSearchesExactDeclaredName() {
        const command = AppIconSearch.findCommand(["visual-studio-code"], ["/usr/share/icons"]);
        compare(command[0], "find");
        verify(command.includes("visual-studio-code.png"));
        verify(command.includes("visual-studio-code.svg"));
        verify(command.includes("visual-studio-code.xpm"));
        verify(!command.includes("vscode"));
    }

    function test_findCommandBatchesNamesAndEscapesPatterns() {
        const command = AppIconSearch.findCommand(["example", "Example.svg", "app[beta]*"], ["/usr/share/icons"]);
        compare(command.filter(argument => argument === "example.svg").length, 1);
        verify(command.includes("app\\[beta\\]\\*.png"));
    }

    function test_legacyPixmapDirectoryIsAlwaysIncluded() {
        const directories = AppIconSearch.searchRoots({
            "HOME": "/home/tester",
            "XDG_DATA_DIRS": "/opt/share"
        });
        verify(directories.includes("/usr/share/pixmaps"));
    }

    function test_hicolorAndUnthemedIconsPrecedeUnrelatedThemes() {
        const output = [
            "/usr/share/icons/Papirus/80x80/apps/example.svg",
            "/usr/share/pixmaps/example.png",
            "/usr/share/icons/hicolor/48x48/apps/example.png"
        ].join("\n");
        const paths = AppIconSearch.selectPaths(output, ["example"], ["/usr/share/icons", "/usr/share/pixmaps"], 80);
        compare(paths[AppIconSearch.cacheKey("example")], "/usr/share/icons/hicolor/48x48/apps/example.png");
    }

    function test_applicationContextAndClosestSizeArePreferred() {
        const output = [
            "/usr/share/icons/Papirus/64x64/categories/example.svg",
            "/usr/share/icons/Papirus/32x32/apps/example.svg",
            "/usr/share/icons/Papirus/64x64/apps/example.svg"
        ].join("\n");
        const paths = AppIconSearch.selectPaths(output, ["example"], ["/usr/share/icons"], 80);
        compare(paths[AppIconSearch.cacheKey("example")], "/usr/share/icons/Papirus/64x64/apps/example.svg");
    }

    function test_candidatesCanBeReusedForDifferentSizes() {
        const output = [
            "/usr/share/icons/Papirus/32x32/apps/example.svg",
            "/usr/share/icons/Papirus/64x64/apps/example.svg"
        ].join("\n");
        const candidates = AppIconSearch.candidatePaths(output, ["example"]);
        const paths = candidates[AppIconSearch.cacheKey("example")];
        compare(AppIconSearch.bestPath(paths, ["/usr/share/icons"], 36), "/usr/share/icons/Papirus/32x32/apps/example.svg");
        compare(AppIconSearch.bestPath(paths, ["/usr/share/icons"], 80), "/usr/share/icons/Papirus/64x64/apps/example.svg");
    }

    function test_iconExtensionIsOptional() {
        compare(AppIconSearch.cacheKey("Example.SVG"), AppIconSearch.cacheKey("example"));
        const paths = AppIconSearch.selectPaths("/usr/share/pixmaps/example.png", ["example.svg"], ["/usr/share/pixmaps"], 80);
        compare(paths[AppIconSearch.cacheKey("example")], "/usr/share/pixmaps/example.png");
    }
}
