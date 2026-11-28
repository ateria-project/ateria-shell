import QtQuick
import qs.platform.settings

QtObject {
    id: root

    property string query: ""
    property string selectedNamespace: ""

    readonly property var categories: {
        const preferredOrder = ["wallpaper", "bar", "media", "launcher"];
        const names = Object.keys(SettingsService.schema);
        names.sort((left, right) => {
            const leftIndex = preferredOrder.indexOf(left);
            const rightIndex = preferredOrder.indexOf(right);
            if (leftIndex < 0 && rightIndex < 0)
                return left.localeCompare(right);
            if (leftIndex < 0)
                return 1;
            if (rightIndex < 0)
                return -1;
            return leftIndex - rightIndex;
        });
        return names.map(name => root.category(name));
    }
    readonly property var filteredCategories: root.categories.filter(category => root.categoryMatches(category))

    function category(namespaceName: string): var {
        switch (namespaceName) {
        case "wallpaper":
            return { namespaceName, title: qsTr("Wallpaper & style"), description: qsTr("Folders, images, appearance"), icon: "palette", tone: "tertiary", group: "appearance" };
        case "bar":
            return { namespaceName, title: qsTr("Bar & workspaces"), description: qsTr("Workspaces, windows, taskbar"), icon: "dock_to_bottom", tone: "primary", group: "shell" };
        case "media":
            return { namespaceName, title: qsTr("Media"), description: qsTr("Players, filters, visibility"), icon: "volume_up", tone: "secondary", group: "shell" };
        case "launcher":
            return { namespaceName, title: qsTr("Apps"), description: qsTr("Launcher search and history"), icon: "apps", tone: "tertiary", group: "shell" };
        default:
            return {
                namespaceName,
                title: namespaceName.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/(^|\s)\S/g, match => match.toUpperCase()),
                description: qsTr("Shell configuration"),
                icon: "tune",
                tone: "primary",
                group: "advanced"
            };
        }
    }

    function categoryMatches(category): bool {
        const normalizedQuery = root.query.trim().toLowerCase();
        if (normalizedQuery.length === 0)
            return true;
        if ((category.title + " " + category.description).toLowerCase().includes(normalizedQuery))
            return true;

        const definitions = SettingsService.schema[category.namespaceName] ?? {};
        return Object.keys(definitions).some(name => root.definitionMatches(name, definitions[name], normalizedQuery));
    }

    function definitionMatches(name: string, definition, normalizedQuery: string): bool {
        return (name + " " + String(definition.label ?? "") + " " + String(definition.description ?? "") + " " + String(definition.group ?? "")).toLowerCase().includes(normalizedQuery);
    }

    function entries(namespaceName: string): var {
        const definitions = SettingsService.schema[namespaceName] ?? {};
        const categoryData = root.category(namespaceName);
        const normalizedQuery = root.query.trim().toLowerCase();
        const categoryMatchesQuery = normalizedQuery.length === 0 || (categoryData.title + " " + categoryData.description).toLowerCase().includes(normalizedQuery);
        const names = Object.keys(definitions).filter(name => categoryMatchesQuery || root.definitionMatches(name, definitions[name], normalizedQuery));

        names.sort((left, right) => {
            const orderDifference = Number(definitions[left].order ?? 0) - Number(definitions[right].order ?? 0);
            return orderDifference !== 0 ? orderDifference : left.localeCompare(right);
        });

        return names.map(name => ({ name, definition: definitions[name] }));
    }

    function groups(namespaceName: string): var {
        const groupedEntries = [];
        const flatEntries = root.entries(namespaceName);

        for (const entry of flatEntries) {
            const groupName = String(entry.definition.group ?? qsTr("general"));
            let group = groupedEntries.length > 0 ? groupedEntries[groupedEntries.length - 1] : null;

            if (!group || group.name !== groupName) {
                group = { name: groupName, entries: [] };
                groupedEntries.push(group);
            }

            group.entries.push(entry);
        }

        return groupedEntries;
    }

    function ensureSelection() {
        if (root.filteredCategories.length === 0)
            return;
        if (root.filteredCategories.some(category => category.namespaceName === root.selectedNamespace))
            return;
        root.selectedNamespace = root.filteredCategories[0].namespaceName;
    }

    function selectNamespace(namespaceName: string) {
        if (root.categories.some(category => category.namespaceName === namespaceName))
            root.selectedNamespace = namespaceName;
    }

    onFilteredCategoriesChanged: root.ensureSelection()
    Component.onCompleted: root.ensureSelection()
}
