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

    readonly property int schemaVersion: 1
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

    function copiedValue(value) {
        if (Array.isArray(value) || root.isPlainObject(value))
            return JSON.parse(JSON.stringify(value));

        return value;
    }

    function compareKeys(left, right) {
        if (left < right)
            return -1;
        if (left > right)
            return 1;

        return 0;
    }

    function nameIsValid(name) {
        return typeof name === "string" && /^[A-Za-z][A-Za-z0-9]*$/.test(name);
    }

    function enumOptionIds(definition) {
        return definition.options.map(option => option.id);
    }

    function enumOptionsAreValid(options) {
        if (!Array.isArray(options) || options.length === 0)
            return false;

        const ids = [];
        for (let index = 0; index < options.length; ++index) {
            const option = options[index];
            if (!root.isPlainObject(option) || typeof option.id !== "string" || option.id.length === 0 || typeof option.label !== "string" || option.label.length === 0)
                return false;
            if (ids.indexOf(option.id) !== -1)
                return false;

            ids.push(option.id);
        }

        return true;
    }

    function requiredPropertiesAreValid(definition) {
        if (!root.hasOwn(definition, "required"))
            return true;
        if (!Array.isArray(definition.required))
            return false;

        const seen = [];
        for (let index = 0; index < definition.required.length; ++index) {
            const name = definition.required[index];
            if (typeof name !== "string" || !root.hasOwn(definition.properties, name) || seen.indexOf(name) !== -1)
                return false;

            seen.push(name);
        }

        return true;
    }

    function definitionIsValid(path, definition, defaultRequired) {
        if (!root.isPlainObject(definition)) {
            console.warn("SettingsService: definition for " + path + " must be an object");
            return false;
        }
        if (typeof definition.type !== "string") {
            console.warn("SettingsService: definition for " + path + " requires a type");
            return false;
        }
        if (defaultRequired && !root.hasOwn(definition, "defaultValue")) {
            console.warn("SettingsService: setting " + path + " requires a defaultValue");
            return false;
        }

        const supportedTypes = ["bool", "int", "real", "string", "enum", "list", "object", "map"];
        if (supportedTypes.indexOf(definition.type) === -1) {
            console.warn("SettingsService: unsupported type for " + path + ": " + definition.type);
            return false;
        }

        if (definition.type === "enum" && !root.enumOptionsAreValid(definition.options)) {
            console.warn("SettingsService: enum " + path + " requires unique options with stable ids and labels");
            return false;
        }

        if (definition.type === "list") {
            if (!root.hasOwn(definition, "items") || !root.definitionIsValid(path + "[]", definition.items, false)) {
                console.warn("SettingsService: list " + path + " requires a valid items schema");
                return false;
            }
        }

        if (definition.type === "object") {
            if (!root.isPlainObject(definition.properties)) {
                console.warn("SettingsService: object " + path + " requires properties");
                return false;
            }

            const propertyNames = Object.keys(definition.properties);
            for (let index = 0; index < propertyNames.length; ++index) {
                const propertyName = propertyNames[index];
                if (!root.nameIsValid(propertyName) || !root.definitionIsValid(path + "." + propertyName, definition.properties[propertyName], false))
                    return false;
            }

            if (!root.requiredPropertiesAreValid(definition)) {
                console.warn("SettingsService: object " + path + " has invalid required properties");
                return false;
            }
        }

        if (definition.type === "map") {
            if (!root.hasOwn(definition, "values") || !root.definitionIsValid(path + ".*", definition.values, false)) {
                console.warn("SettingsService: map " + path + " requires a valid values schema");
                return false;
            }
        }

        if (root.hasOwn(definition, "minimum") && (typeof definition.minimum !== "number" || !Number.isFinite(definition.minimum))) {
            console.warn("SettingsService: minimum for " + path + " must be finite");
            return false;
        }
        if (root.hasOwn(definition, "maximum") && (typeof definition.maximum !== "number" || !Number.isFinite(definition.maximum))) {
            console.warn("SettingsService: maximum for " + path + " must be finite");
            return false;
        }
        if ((root.hasOwn(definition, "minimum") || root.hasOwn(definition, "maximum")) && definition.type !== "int" && definition.type !== "real") {
            console.warn("SettingsService: minimum and maximum only apply to numeric settings");
            return false;
        }
        if (root.hasOwn(definition, "minimum") && root.hasOwn(definition, "maximum") && definition.minimum > definition.maximum) {
            console.warn("SettingsService: minimum exceeds maximum for " + path);
            return false;
        }

        if (root.hasOwn(definition, "defaultValue")) {
            const validatedDefault = root.validatedValue(definition, definition.defaultValue, true);
            if (!validatedDefault.valid || JSON.stringify(validatedDefault.value) !== JSON.stringify(definition.defaultValue)) {
                console.warn("SettingsService: invalid defaultValue for " + path);
                return false;
            }
        }

        return true;
    }

    function validatedValue(definition, candidate, strict) {
        switch (definition.type) {
        case "bool":
            return { valid: typeof candidate === "boolean", value: candidate };
        case "string":
            return { valid: typeof candidate === "string", value: candidate };
        case "enum":
            return { valid: typeof candidate === "string" && root.enumOptionIds(definition).indexOf(candidate) !== -1, value: candidate };
        case "int":
        case "real": {
            if (typeof candidate !== "number" || !Number.isFinite(candidate))
                return { valid: false };
            if (strict && definition.type === "int" && !Number.isInteger(candidate))
                return { valid: false };
            if (strict && root.hasOwn(definition, "minimum") && candidate < definition.minimum)
                return { valid: false };
            if (strict && root.hasOwn(definition, "maximum") && candidate > definition.maximum)
                return { valid: false };

            let value = definition.type === "int" ? Math.round(candidate) : candidate;
            if (root.hasOwn(definition, "minimum"))
                value = Math.max(definition.minimum, value);
            if (root.hasOwn(definition, "maximum"))
                value = Math.min(definition.maximum, value);

            return { valid: true, value: value };
        }
        case "list": {
            if (!Array.isArray(candidate))
                return { valid: false };

            const list = [];
            for (let index = 0; index < candidate.length; ++index) {
                const item = root.validatedValue(definition.items, candidate[index], strict);
                if (item.valid)
                    list.push(item.value);
                else if (strict)
                    return { valid: false };
            }

            return { valid: true, value: list };
        }
        case "object": {
            if (!root.isPlainObject(candidate))
                return { valid: false };

            const result = {};
            const propertyNames = Object.keys(definition.properties).sort(root.compareKeys);
            if (strict && Object.keys(candidate).some(name => propertyNames.indexOf(name) === -1))
                return { valid: false };

            const required = root.hasOwn(definition, "required") ? definition.required : [];
            for (let index = 0; index < propertyNames.length; ++index) {
                const propertyName = propertyNames[index];
                const propertyDefinition = definition.properties[propertyName];

                if (!root.hasOwn(candidate, propertyName)) {
                    if (root.hasOwn(propertyDefinition, "defaultValue"))
                        result[propertyName] = root.copiedValue(propertyDefinition.defaultValue);
                    else if (required.indexOf(propertyName) !== -1)
                        return { valid: false };
                    continue;
                }

                const property = root.validatedValue(propertyDefinition, candidate[propertyName], strict);
                if (property.valid)
                    result[propertyName] = property.value;
                else if (strict)
                    return { valid: false };
                else if (root.hasOwn(propertyDefinition, "defaultValue"))
                    result[propertyName] = root.copiedValue(propertyDefinition.defaultValue);
                else if (required.indexOf(propertyName) !== -1)
                    return { valid: false };
            }

            return { valid: true, value: result };
        }
        case "map": {
            if (!root.isPlainObject(candidate))
                return { valid: false };

            const result = {};
            const keys = Object.keys(candidate).sort(root.compareKeys);
            for (let index = 0; index < keys.length; ++index) {
                const entry = root.validatedValue(definition.values, candidate[keys[index]], strict);
                if (entry.valid)
                    result[keys[index]] = entry.value;
                else if (strict)
                    return { valid: false };
            }

            return { valid: true, value: result };
        }
        }

        return { valid: false };
    }

    function registerSchema(namespace, definitions) {
        if (root.ready || root.loadInProgress) {
            console.warn("SettingsService: registerSchema() must run before load()");
            return false;
        }
        if (!root.nameIsValid(namespace)) {
            console.warn("SettingsService: invalid schema namespace: " + namespace);
            return false;
        }
        if (!root.isPlainObject(definitions)) {
            console.warn("SettingsService: schema namespace " + namespace + " must be an object");
            return false;
        }
        if (root.hasOwn(root.schema, namespace)) {
            console.warn("SettingsService: duplicate schema namespace: " + namespace);
            return false;
        }

        const settingNames = Object.keys(definitions);
        for (let index = 0; index < settingNames.length; ++index) {
            const settingName = settingNames[index];
            if (!root.nameIsValid(settingName)) {
                console.warn("SettingsService: invalid setting name: " + namespace + "." + settingName);
                return false;
            }
            if (!root.definitionIsValid(namespace + "." + settingName, definitions[settingName], true))
                return false;
        }

        const nextSchema = Object.assign({}, root.schema);
        nextSchema[namespace] = definitions;
        root.schema = nextSchema;
        return true;
    }

    function settingDefinition(namespace, settingName) {
        if (!root.hasOwn(root.schema, namespace) || !root.hasOwn(root.schema[namespace], settingName))
            return undefined;

        return root.schema[namespace][settingName];
    }

    function reconciledValues(storedValues) {
        const source = root.isPlainObject(storedValues) ? storedValues : {};
        const result = {};
        const namespaces = Object.keys(root.schema).sort(root.compareKeys);

        for (let namespaceIndex = 0; namespaceIndex < namespaces.length; ++namespaceIndex) {
            const namespace = namespaces[namespaceIndex];
            const definitions = root.schema[namespace];
            const storedNamespace = root.isPlainObject(source[namespace]) ? source[namespace] : {};
            const namespaceValues = {};
            const settingNames = Object.keys(definitions).sort(root.compareKeys);

            for (let settingIndex = 0; settingIndex < settingNames.length; ++settingIndex) {
                const settingName = settingNames[settingIndex];
                const definition = definitions[settingName];
                const candidate = root.hasOwn(storedNamespace, settingName) ? storedNamespace[settingName] : definition.defaultValue;
                const validated = root.validatedValue(definition, candidate, false);
                namespaceValues[settingName] = validated.valid ? validated.value : root.copiedValue(definition.defaultValue);
            }

            result[namespace] = namespaceValues;
        }

        return result;
    }

    function storageObject(sourceValues) {
        const canonical = root.reconciledValues(sourceValues);
        const stored = { "$schemaVersion": root.schemaVersion };
        const namespaces = Object.keys(canonical).sort(root.compareKeys);

        for (let index = 0; index < namespaces.length; ++index)
            stored[namespaces[index]] = canonical[namespaces[index]];

        return stored;
    }

    function serializeValues(sourceValues) {
        return JSON.stringify(root.storageObject(sourceValues), null, 2) + "\n";
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

        if (trimmedText.length > 0) {
            try {
                const parsed = JSON.parse(trimmedText);
                if (!root.isPlainObject(parsed))
                    throw new Error("settings root must be an object");

                if (parsed["$schemaVersion"] !== root.schemaVersion)
                    throw new Error("incompatible settings schema version");

                storedValues = parsed;
            } catch (error) {
                root.lastError = "Reset incompatible settings file: " + error;
                console.warn("SettingsService: " + root.lastError);
            }
        }

        root.values = root.reconciledValues(storedValues);
        root.revision++;
        root.ready = true;
        root.loadInProgress = false;

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
        root.values = root.reconciledValues({});
        root.revision++;
        root.ready = true;
    }

    function value(namespace, settingName) {
        const dependency = root.revision;
        const definition = root.settingDefinition(namespace, settingName);

        if (root.hasOwn(root.values, namespace) && root.hasOwn(root.values[namespace], settingName))
            return root.copiedValue(root.values[namespace][settingName]);
        if (definition !== undefined)
            return root.copiedValue(definition.defaultValue);
        if (!root.ready)
            return undefined;

        console.warn("SettingsService: unknown setting: " + namespace + "." + settingName);
        return undefined;
    }

    function setValue(namespace, settingName, newValue) {
        if (!root.ready) {
            console.warn("SettingsService: setValue() called before load() completed");
            return false;
        }

        const definition = root.settingDefinition(namespace, settingName);
        if (definition === undefined) {
            console.warn("SettingsService: unknown setting: " + namespace + "." + settingName);
            return false;
        }

        const validated = root.validatedValue(definition, newValue, true);
        if (!validated.valid) {
            console.warn("SettingsService: rejected invalid value for " + namespace + "." + settingName);
            return false;
        }

        const value = validated.value;
        const currentNamespace = root.hasOwn(root.values, namespace) ? root.values[namespace] : {};
        if (root.hasOwn(currentNamespace, settingName) && JSON.stringify(currentNamespace[settingName]) === JSON.stringify(value))
            return true;

        const changedNamespace = Object.assign({}, currentNamespace);
        changedNamespace[settingName] = value;
        const changedValues = Object.assign({}, root.values);
        changedValues[namespace] = changedNamespace;
        root.values = changedValues;
        root.revision++;
        root.dirty = true;
        saveTimer.restart();
        return true;
    }

    function reset(namespace, settingName) {
        const definition = root.settingDefinition(namespace, settingName);
        if (definition === undefined) {
            console.warn("SettingsService: unknown setting: " + namespace + "." + settingName);
            return false;
        }

        return root.setValue(namespace, settingName, definition.defaultValue);
    }

    function resetAll() {
        if (!root.ready) {
            console.warn("SettingsService: resetAll() called before load() completed");
            return false;
        }

        const resetValues = root.reconciledValues({});
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

        const canonical = root.reconciledValues(root.values);
        if (JSON.stringify(root.values) !== JSON.stringify(canonical)) {
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
