pragma ComponentBehavior: Bound

import QtQuick

// Owns the lifetime of a transient surface independently from the state that
// requests it. A presentation may complete a transition later without making
// window visibility, content lifetime, and animation progress share one bool.
QtObject {
    id: root

    enum Phase {
        Hidden,
        Entering,
        Shown,
        Exiting
    }

    property bool requested: false
    property bool transitionsEnabled: false

    readonly property int phase: root._phase
    readonly property bool mounted: root._phase !== SurfaceLifecycle.Hidden
    readonly property bool interactive: root.requested && root.mounted
    readonly property bool entering: root._phase === SurfaceLifecycle.Entering
    readonly property bool exiting: root._phase === SurfaceLifecycle.Exiting
    readonly property int generation: root._generation

    property int _phase: SurfaceLifecycle.Hidden
    property int _generation: 0

    signal transitionRequested(bool entering, int generation)
    signal becameShown()
    signal becameHidden()

    function reconcile() {
        if (root.requested) {
            if (root._phase === SurfaceLifecycle.Shown
                    || root._phase === SurfaceLifecycle.Entering)
                return;

            root._generation += 1;
            root._phase = SurfaceLifecycle.Entering;
            const currentGeneration = root._generation;
            root.transitionRequested(true, currentGeneration);
            if (!root.transitionsEnabled)
                root.completeTransition(currentGeneration);
            return;
        }

        if (root._phase === SurfaceLifecycle.Hidden
                || root._phase === SurfaceLifecycle.Exiting)
            return;

        root._generation += 1;
        root._phase = SurfaceLifecycle.Exiting;
        const currentGeneration = root._generation;
        root.transitionRequested(false, currentGeneration);
        if (!root.transitionsEnabled)
            root.completeTransition(currentGeneration);
    }

    // Completion is accepted only for the current request. This makes a late
    // callback from an interrupted transition harmless.
    function completeTransition(completedGeneration: int) {
        if (completedGeneration !== root._generation)
            return;

        if (root.requested && root._phase === SurfaceLifecycle.Entering) {
            root._phase = SurfaceLifecycle.Shown;
            root.becameShown();
        } else if (!root.requested && root._phase === SurfaceLifecycle.Exiting) {
            root._phase = SurfaceLifecycle.Hidden;
            root.becameHidden();
        }
    }

    onRequestedChanged: root.reconcile()
    onTransitionsEnabledChanged: {
        if (!root.transitionsEnabled
                && (root._phase === SurfaceLifecycle.Entering
                    || root._phase === SurfaceLifecycle.Exiting))
            root.completeTransition(root._generation);
    }
    Component.onCompleted: root.reconcile()
}
