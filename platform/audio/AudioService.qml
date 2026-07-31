pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    /*
     * Volume values use 0.0–1.0 by default.
     * Raise maxOutputVolume to 1.5 if you want to allow amplification.
     */
    property real volumeStep: 0.05
    property real maxOutputVolume: 1
    property real maxInputVolume: 1
    property bool unmuteOnVolumeChange: true
    readonly property bool ready: Pipewire.ready
    readonly property var outputNode: Pipewire.defaultAudioSink
    readonly property var inputNode: Pipewire.defaultAudioSource
    readonly property bool outputReady: root.outputNode !== null && root.outputNode.ready && root.outputNode.audio !== null
    readonly property bool inputReady: root.inputNode !== null && root.inputNode.ready && root.inputNode.audio !== null
    readonly property var outputAudio: root.outputReady ? root.outputNode.audio : null
    readonly property var inputAudio: root.inputReady ? root.inputNode.audio : null
    // Output state
    readonly property real outputVolume: root.outputAudio !== null ? root.outputAudio.volume : 0
    readonly property int outputVolumePercent: Math.round(root.outputVolume * 100)
    readonly property bool outputMuted: root.outputAudio !== null && root.outputAudio.muted
    readonly property string outputIconName: {
        if (root.outputMuted || root.outputVolume <= 0)
            return "volume_off";

        return "volume_up";
    }
    readonly property string outputName: root.nodeLabel(root.outputNode)
    // Input state
    readonly property real inputVolume: root.inputAudio !== null ? root.inputAudio.volume : 0
    readonly property int inputVolumePercent: Math.round(root.inputVolume * 100)
    readonly property bool inputMuted: root.inputAudio !== null && root.inputAudio.muted
    readonly property string inputName: root.nodeLabel(root.inputNode)
    /*
     * Hardware devices only. Application streams are excluded.
     *
     * PipeWire sinks are output devices.
     * PipeWire sources are input devices.
     */
    readonly property var outputDevices: Pipewire.nodes.values.filter(node => {
        return root.isOutputDevice(node);
    })
    readonly property var inputDevices: Pipewire.nodes.values.filter(node => {
        return root.isInputDevice(node);
    })

    function clamp(value: real, minimum: real, maximum: real): real {
        return Math.max(minimum, Math.min(maximum, value));
    }

    function isOutputDevice(node): bool {
        return node !== null && node !== undefined && node.audio !== null && !node.isStream && node.isSink;
    }

    function isInputDevice(node): bool {
        return node !== null && node !== undefined && node.audio !== null && !node.isStream && !node.isSink;
    }

    function nodeLabel(node): string {
        if (node === null || node === undefined)
            return "";

        const description = String(node.description ?? "").trim();
        if (description.length > 0)
            return description;

        const nickname = String(node.nickname ?? "").trim();
        if (nickname.length > 0)
            return nickname;

        const name = String(node.name ?? "").trim();
        return name.length > 0 ? name : "Unknown audio device";
    }

    // Output controls
    function setOutputVolume(value: real): bool {
        if (root.outputAudio === null)
            return false;

        const maximum = Math.max(0, root.maxOutputVolume);
        const nextVolume = Math.round(root.clamp(value, 0, maximum) * 1000) / 1000;
        root.outputAudio.volume = nextVolume;
        if (root.unmuteOnVolumeChange && nextVolume > 0 && root.outputAudio.muted)
            root.outputAudio.muted = false;

        return true;
    }

    function changeOutputVolume(delta: real): bool {
        return root.setOutputVolume(root.outputVolume + delta);
    }

    function increaseOutputVolume(): bool {
        return root.changeOutputVolume(root.volumeStep);
    }

    function decreaseOutputVolume(): bool {
        return root.changeOutputVolume(-root.volumeStep);
    }

    function setOutputMuted(muted: bool): bool {
        if (root.outputAudio === null)
            return false;

        root.outputAudio.muted = muted;
        return true;
    }

    function toggleOutputMute(): bool {
        return root.setOutputMuted(!root.outputMuted);
    }

    function setOutputDevice(node): bool {
        if (!root.isOutputDevice(node))
            return false;

        Pipewire.preferredDefaultAudioSink = node;
        return true;
    }

    // Input controls
    function setInputVolume(value: real): bool {
        if (root.inputAudio === null)
            return false;

        const maximum = Math.max(0, root.maxInputVolume);
        const nextVolume = Math.round(root.clamp(value, 0, maximum) * 1000) / 1000;
        root.inputAudio.volume = nextVolume;
        return true;
    }

    function changeInputVolume(delta: real): bool {
        return root.setInputVolume(root.inputVolume + delta);
    }

    function increaseInputVolume(): bool {
        return root.changeInputVolume(root.volumeStep);
    }

    function decreaseInputVolume(): bool {
        return root.changeInputVolume(-root.volumeStep);
    }

    function setInputMuted(muted: bool): bool {
        if (root.inputAudio === null)
            return false;

        root.inputAudio.muted = muted;
        return true;
    }

    function toggleInputMute(): bool {
        return root.setInputMuted(!root.inputMuted);
    }

    function setInputDevice(node): bool {
        if (!root.isInputDevice(node))
            return false;

        Pipewire.preferredDefaultAudioSource = node;
        return true;
    }

    /*
     * PwObjectTracker binds the default nodes so their volume and mute
     * properties can be read and changed.
     */
    PwObjectTracker {
        objects: [root.outputNode, root.inputNode]
    }
}
