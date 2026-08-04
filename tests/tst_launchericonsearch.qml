import QtQuick
import QtTest
import "../features/launcher/icons/IconSearch.js" as IconSearch

TestCase {
    name: "LauncherIconSearch"

    function test_standardSearchRoots() {
        compare(IconSearch.searchRoots({
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
        const command = IconSearch.findCommand(["visual-studio-code"], ["/usr/share/icons"]);
        compare(command[0], "find");
        verify(command.includes("visual-studio-code.png"));
        verify(command.includes("visual-studio-code.svg"));
        verify(command.includes("visual-studio-code.xpm"));
        verify(!command.includes("vscode"));
    }

    function test_findCommandBatchesNamesAndEscapesPatterns() {
        const command = IconSearch.findCommand(["example", "Example.svg", "app[beta]*"], ["/usr/share/icons"]);
        compare(command.filter(argument => argument === "example.svg").length, 1);
        verify(command.includes("app\\[beta\\]\\*.png"));
    }

    function test_legacyPixmapDirectoryIsAlwaysIncluded() {
        const directories = IconSearch.searchRoots({
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
        const paths = IconSearch.selectPaths(output, ["example"], ["/usr/share/icons", "/usr/share/pixmaps"], 80);
        compare(paths[IconSearch.cacheKey("example")], "/usr/share/icons/hicolor/48x48/apps/example.png");
    }

    function test_applicationContextAndClosestSizeArePreferred() {
        const output = [
            "/usr/share/icons/Papirus/64x64/categories/example.svg",
            "/usr/share/icons/Papirus/32x32/apps/example.svg",
            "/usr/share/icons/Papirus/64x64/apps/example.svg"
        ].join("\n");
        const paths = IconSearch.selectPaths(output, ["example"], ["/usr/share/icons"], 80);
        compare(paths[IconSearch.cacheKey("example")], "/usr/share/icons/Papirus/64x64/apps/example.svg");
    }

    function test_iconExtensionIsOptional() {
        compare(IconSearch.cacheKey("Example.SVG"), IconSearch.cacheKey("example"));
        const paths = IconSearch.selectPaths("/usr/share/pixmaps/example.png", ["example.svg"], ["/usr/share/pixmaps"], 80);
        compare(paths[IconSearch.cacheKey("example")], "/usr/share/pixmaps/example.png");
    }
}
