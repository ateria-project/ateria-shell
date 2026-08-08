pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Stable host for a transient layer-shell surface. `open` is requested state;
// `mounted` is actual window/content lifetime. Motion can be attached to the
// transitionRequested signal later without changing the hosted component.
PanelWindow {
    id: root

    property bool open: false
    property var targetScreen: null
    property var fallbackScreen: null
    property bool transitionsEnabled: false
    property var interactiveMask: null

    readonly property bool mounted: surfaceLifecycle.mounted
    readonly property bool interactive: surfaceLifecycle.interactive
    readonly property int phase: surfaceLifecycle.phase
    readonly property bool entering: surfaceLifecycle.entering
    readonly property bool exiting: surfaceLifecycle.exiting
    readonly property int transitionGeneration: surfaceLifecycle.generation

    signal transitionRequested(bool entering, int generation)
    signal fullyOpened()
    signal fullyClosed()

    screen: root.targetScreen ?? root.fallbackScreen
    visible: root.mounted
    mask: root.interactive ? root.interactiveMask : emptyInputRegion

    function completeTransition(generation: int) {
        surfaceLifecycle.completeTransition(generation);
    }

    Region {
        id: emptyInputRegion
    }

    SurfaceLifecycle {
        id: surfaceLifecycle

        requested: root.open
        transitionsEnabled: root.transitionsEnabled
        onTransitionRequested: (entering, generation) => root.transitionRequested(entering, generation)
        onBecameShown: root.fullyOpened()
        onBecameHidden: root.fullyClosed()
    }
}
