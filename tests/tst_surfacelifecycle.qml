import QtQuick
import QtTest
import "../components"

TestCase {
    name: "SurfaceLifecycle"

    SurfaceLifecycle {
        id: lifecycle
    }

    function init() {
        lifecycle.transitionsEnabled = false;
        lifecycle.requested = false;
        compare(lifecycle.phase, SurfaceLifecycle.Hidden);
    }

    function cleanup() {
        lifecycle.transitionsEnabled = false;
        lifecycle.requested = false;
    }

    function test_immediateLifecycle() {
        lifecycle.requested = true;
        compare(lifecycle.phase, SurfaceLifecycle.Shown);
        verify(lifecycle.mounted);
        verify(lifecycle.interactive);

        lifecycle.requested = false;
        compare(lifecycle.phase, SurfaceLifecycle.Hidden);
        verify(!lifecycle.mounted);
        verify(!lifecycle.interactive);
    }

    function test_exitRetainsMountUntilCompletion() {
        lifecycle.transitionsEnabled = true;
        lifecycle.requested = true;
        const enterGeneration = lifecycle.generation;
        lifecycle.completeTransition(enterGeneration);

        lifecycle.requested = false;
        const exitGeneration = lifecycle.generation;
        compare(lifecycle.phase, SurfaceLifecycle.Exiting);
        verify(lifecycle.mounted);
        verify(!lifecycle.interactive);

        lifecycle.completeTransition(exitGeneration);
        compare(lifecycle.phase, SurfaceLifecycle.Hidden);
        verify(!lifecycle.mounted);
    }

    function test_staleCompletionCannotFinishReversedTransition() {
        lifecycle.transitionsEnabled = true;
        lifecycle.requested = true;
        const firstEnter = lifecycle.generation;

        lifecycle.requested = false;
        const exitGeneration = lifecycle.generation;

        lifecycle.requested = true;
        const secondEnter = lifecycle.generation;
        verify(secondEnter > exitGeneration);
        compare(lifecycle.phase, SurfaceLifecycle.Entering);

        lifecycle.completeTransition(firstEnter);
        lifecycle.completeTransition(exitGeneration);
        compare(lifecycle.phase, SurfaceLifecycle.Entering);
        verify(lifecycle.mounted);

        lifecycle.completeTransition(secondEnter);
        compare(lifecycle.phase, SurfaceLifecycle.Shown);
        verify(lifecycle.interactive);
    }
}
