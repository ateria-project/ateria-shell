import QtQuick

QtObject {
    id: root

    property string currentPage: "main"
    property var pageStack: []
    property bool editMode: false

    function pushPage(page: string) {
        const stack = root.pageStack.slice();
        stack.push(root.currentPage);
        root.pageStack = stack;
        root.currentPage = page;
    }

    function popPage() {
        if (root.pageStack.length === 0)
            return;

        const stack = root.pageStack.slice();
        root.currentPage = stack.pop();
        root.pageStack = stack;
    }

    function reset() {
        root.currentPage = "main";
        root.pageStack = [];
        root.editMode = false;
    }
}
