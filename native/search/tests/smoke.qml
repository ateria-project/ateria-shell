import QtQuick
import Ateria.Search

Item {
    id: root

    property QtObject calculator: QtObject {
        property string name: "Calculator"
        property string id: "calculator.desktop"
        property string genericName: "Utility"
        property string comment: ""
        property var keywords: ["math"]
        property var categories: ["Utility"]
        property string startupClass: "Calculator"
        property var command: ["calculator"]
        property string execString: "calculator"
    }

    property LauncherSearchModel searchModel: LauncherSearchModel {
        applications: [root.calculator]
        query: "calc"
    }

    Component.onCompleted: {
        if (root.searchModel.results.length !== 1
                || root.searchModel.results[0].name !== "Calculator")
            throw new Error("native launcher search failed")
        if (LauncherSearch.applicationKey(root.calculator) !== "desktop:calculator.desktop")
            throw new Error("native launcher key failed")
        Qt.quit()
    }
}
