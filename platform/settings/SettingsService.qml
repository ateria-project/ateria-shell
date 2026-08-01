pragma Singleton

import QtQuick
import QtCore
import Quickshell.Io

QtObject {
    id: root

    property var schema: ({})
    property var values: ({})
    property int revision: 0
    property bool ready: false
    property bool dirty: false
    property string lastError: ""

    readonly property string configDirectory: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/ateria"
    readonly property string settingsFile: root.configDirectory + "/settings.json"

    property bool loadInProgress: false
    property bool saveInProgress: false
    property bool directoryCreationInProgress: false
    property string inFlightText: ""

    function isPlainObject(candidate) {
        return candidate !== null && typeof candidate === "object" && !Array.isArray(candidate);
    }

    function hasOwn(object, key) {
        return object !== null && object !== undefined && Object.prototype.hasOwnProperty.call(object, key);
    }

    function compareSettingKeys(left, right) {
        if (left < right)
            return -1;

        if (left > right)
            return 1;

        return 0;
    }

    function sortedSchemaKeys() {
        return Object.keys(root.schema).sort(root.compareSettingKeys);
    }

    function settingKeyIsValid(key) {
        return typeof key === "string" && /^[^.]+\.[^.]+$/.test(key);
    }

    function isFiniteNumber(candidate) {
        return typeof candidate === "number" && Number.isFinite(candidate);
    }

    function definitionIsValid(key, definition) {
        if (!root.isPlainObject(definition)) {
            console.warn("SettingsService: definition for " + key + " must be an object");
            return false;
        }

        if (!root.hasOwn(definition, "type") || !root.hasOwn(definition, "defaultValue")) {
            console.warn("SettingsService: definition for " + key + " must contain type and defaultValue");
            return false;
        }

        const type = definition.type;
        if (["bool", "int", "real", "string", "enum"].indexOf(type) === -1) {
            console.warn("SettingsService: unsupported type for " + key + ": " + type);
            return false;
        }

        if (type === "enum" && (!Array.isArray(definition.options) || definition.options.length === 0)) {
            console.warn("SettingsService: enum " + key + " requires non-empty options");
            return false;
        }

        if (root.hasOwn(definition, "minimum") && !root.isFiniteNumber(definition.minimum)) {
            console.warn("SettingsService: minimum for " + key + " must be finite");
            return false;
        }

        if (root.hasOwn(definition, "maximum") && !root.isFiniteNumber(definition.maximum)) {
            console.warn("SettingsService: maximum for " + key + " must be finite");
            return false;
        }

        if ((root.hasOwn(definition, "minimum") || root.hasOwn(definition, "maximum")) && type !== "int" && type !== "real") {
            console.warn("SettingsService: minimum and maximum only apply to numeric settings");
            return false;
        }

        if (root.hasOwn(definition, "minimum") && root.hasOwn(definition, "maximum") && definition.minimum > definition.maximum) {
            console.warn("SettingsService: minimum exceeds maximum for " + key);
            return false;
        }

        if (!root.defaultMatchesDefinition(definition, definition.defaultValue)) {
            console.warn("SettingsService: invalid defaultValue for " + key);
            return false;
        }

        return true;
    }

    function candidateHasCorrectType(definition, candidate) {
        switch (definition.type) {
        case "bool":
            return typeof candidate === "boolean";
        case "int":
        case "real":
            return root.isFiniteNumber(candidate);
        case "string":
            return typeof candidate === "string";
        case "enum":
            return definition.options.indexOf(candidate) !== -1;
        }

        return false;
    }

    function defaultMatchesDefinition(definition, candidate) {
        if (!root.candidateHasCorrectType(definition, candidate))
            return false;

        return (definition.type !== "int" && definition.type !== "real") || ((!root.hasOwn(definition, "minimum") || candidate >= definition.minimum) && (!root.hasOwn(definition, "maximum") || candidate <= definition.maximum));
    }

    function registerSchema(definitions) {
        if (root.ready || root.loadInProgress) {
            console.warn("SettingsService: registerSchema() must run before load()");
            return false;
        }

        if (!root.isPlainObject(definitions)) {
            console.warn("SettingsService: schema definitions must be an object");
            return false;
        }

        const keys = Object.keys(definitions);
        for (let index = 0; index < keys.length; ++index) {
            const key = keys[index];

            if (!root.settingKeyIsValid(key)) {
                console.warn("SettingsService: invalid setting key: " + key);
                return false;
            }

            if (root.hasOwn(root.schema, key)) {
                console.warn("SettingsService: duplicate setting key: " + key);
                return false;
            }

            if (!root.definitionIsValid(key, definitions[key]))
                return false;
        }

        const nextSchema = Object.assign({}, root.schema);
        for (let index = 0; index < keys.length; ++index)
            nextSchema[keys[index]] = definitions[keys[index]];

        root.schema = nextSchema;
        return true;
    }

    function validate(key, candidate) {
        if (!root.hasOwn(root.schema, key)) {
            console.warn("SettingsService: unknown setting: " + key);
            return undefined;
        }

        const definition = root.schema[key];
        if (!root.candidateHasCorrectType(definition, candidate))
            return definition.defaultValue;

        if (definition.type === "int") {
            let rounded = Math.round(candidate);
            if (root.hasOwn(definition, "minimum"))
                rounded = Math.max(definition.minimum, rounded);
            if (root.hasOwn(definition, "maximum"))
                rounded = Math.min(definition.maximum, rounded);
            return rounded;
        }

        if (definition.type === "real") {
            let bounded = candidate;
            if (root.hasOwn(definition, "minimum"))
                bounded = Math.max(definition.minimum, bounded);
            if (root.hasOwn(definition, "maximum"))
                bounded = Math.min(definition.maximum, bounded);
            return bounded;
        }

        return candidate;
    }

    function reconcileValues(storedValues) {
        const reconciled = {};
        const source = root.isPlainObject(storedValues) ? storedValues : {};
        const keys = root.sortedSchemaKeys();

        for (let index = 0; index < keys.length; ++index) {
            const key = keys[index];
            const definition = root.schema[key];
            const candidate = root.hasOwn(source, key) ? source[key] : definition.defaultValue;

            reconciled[key] = root.validate(key, candidate);
        }

        return reconciled;
    }

    function canonicalValuesObject(sourceValues) {
        return root.reconcileValues(sourceValues);
    }

    function serializeValues(sourceValues) {
        return JSON.stringify(root.canonicalValuesObject(sourceValues), null, 2) + "\n";
    }

    function valuesNeedCanonicalization(sourceValues, canonicalValues) {
        return JSON.stringify(sourceValues) !== JSON.stringify(canonicalValues);
    }

    function load() {
        if (root.ready || root.loadInProgress) {
            console.warn("SettingsService: load() called after initialization began");
            return;
        }

        root.lastError = "";
        root.loadInProgress = true;
        settingsView.path = root.settingsFile;
    }

    function finishLoad(originalText) {
        const trimmedText = originalText.trim();
        let storedValues = {};
        let parsedSuccessfully = true;

        if (trimmedText.length > 0) {
            try {
                const parsed = JSON.parse(trimmedText);
                if (!root.isPlainObject(parsed))
                    throw new Error("settings root must be a JSON object");

                storedValues = parsed;
            } catch (error) {
                parsedSuccessfully = false;
                root.lastError = "Failed to parse settings file: " + error;
                console.warn("SettingsService: " + root.lastError);
            }
        }

        root.values = root.reconcileValues(storedValues);
        root.revision++;
        root.ready = true;
        root.loadInProgress = false;

        if (!parsedSuccessfully)
            return;

        if (originalText !== root.serializeValues(root.values)) {
            root.dirty = true;
            saveTimer.restart();
        }
    }

    function handleLoadFailure(error) {
        root.loadInProgress = false;

        if (error === FileViewError.FileNotFound) {
            root.finishLoad("");
            return;
        }

        root.lastError = "Failed to read settings file: " + FileViewError.toString(error);
        console.warn("SettingsService: " + root.lastError);
        root.values = root.reconcileValues({});
        root.revision++;
        root.ready = true;
    }

    function value(key) {
        const dependency = root.revision;

        if (root.hasOwn(root.values, key))
            return root.values[key];

        if (root.hasOwn(root.schema, key))
            return root.schema[key].defaultValue;

        console.warn("SettingsService: unknown setting: " + key);
        return undefined;
    }

    function setValue(key, newValue) {
        if (!root.ready) {
            console.warn("SettingsService: setValue() called before load() completed");
            return false;
        }

        if (!root.hasOwn(root.schema, key)) {
            console.warn("SettingsService: unknown setting: " + key);
            return false;
        }

        const validated = root.validate(key, newValue);
        if (root.hasOwn(root.values, key) && root.values[key] === validated)
            return true;

        const changed = Object.assign({}, root.values);
        changed[key] = validated;
        root.values = root.canonicalValuesObject(changed);
        root.revision++;
        root.dirty = true;
        saveTimer.restart();
        return true;
    }

    function reset(key) {
        if (!root.hasOwn(root.schema, key)) {
            console.warn("SettingsService: unknown setting: " + key);
            return false;
        }

        return root.setValue(key, root.schema[key].defaultValue);
    }

    function resetAll() {
        if (!root.ready) {
            console.warn("SettingsService: resetAll() called before load() completed");
            return false;
        }

        const resetValues = root.reconcileValues({});
        if (root.serializeValues(resetValues) === root.serializeValues(root.values))
            return true;

        root.values = resetValues;
        root.revision++;
        root.dirty = true;
        saveTimer.restart();
        return true;
    }

    function ensureConfigDirectory() {
        if (root.directoryCreationInProgress)
            return true;

        root.directoryCreationInProgress = true;
        directoryProcess.exec(["mkdir", "-p", "--", root.configDirectory]);
        return true;
    }

    function startWrite() {
        if (!root.dirty || root.saveInProgress)
            return;

        const canonical = root.canonicalValuesObject(root.values);
        if (root.valuesNeedCanonicalization(root.values, canonical)) {
            root.values = canonical;
            root.revision++;
        }

        root.inFlightText = root.serializeValues(root.values);
        root.saveInProgress = true;
        settingsView.setText(root.inFlightText);
    }

    function saveNow() {
        if (!root.dirty || root.saveInProgress)
            return;

        root.ensureConfigDirectory();
    }

    function flush() {
        saveTimer.stop();
        root.saveNow();
    }

    property Timer saveTimer: Timer {

        interval: 250
        repeat: false
        onTriggered: root.saveNow()
    }

    property FileView settingsView: FileView {

        path: ""
        atomicWrites: true
        watchChanges: false
        printErrors: false

        onLoaded: root.finishLoad(settingsView.text())
        onLoadFailed: error => root.handleLoadFailure(error)
        onSaved: {
            root.saveInProgress = false;
            root.lastError = "";
            root.dirty = root.serializeValues(root.values) !== root.inFlightText;

            if (root.dirty)
                saveTimer.restart();
        }
        onSaveFailed: error => {
            root.saveInProgress = false;
            root.lastError = "Failed to save settings file: " + FileViewError.toString(error);
            console.warn("SettingsService: " + root.lastError);

            if (root.serializeValues(root.values) !== root.inFlightText)
                saveTimer.restart();
        }
    }

    property Process directoryProcess: Process {

        onExited: (exitCode, exitStatus) => {
            root.directoryCreationInProgress = false;

            if (exitCode !== 0) {
                root.lastError = "Failed to create settings directory (exit code " + exitCode + ")";
                console.warn("SettingsService: " + root.lastError);
                return;
            }

            root.startWrite();
        }
    }
}
