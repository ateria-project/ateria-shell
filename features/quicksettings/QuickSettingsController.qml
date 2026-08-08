import QtQuick

QtObject {
    id: root

    property var screen: null

    readonly property var validPages: ({
        "audio": true,
        "brightness": true
    })

    signal pageRequested(string page)
    signal backRequested
    signal resetRequested

    function pushPage(page: string) {
        if (!root.validPages[page])
            return;

        root.pageRequested(page);
    }

    function popPage() {
        root.backRequested();
    }

    function reset() {
        root.resetRequested();
    }
}
