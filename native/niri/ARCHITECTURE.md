# Native Niri IPC

`Ateria.Niri` is the shell's process-free transport for Niri's JSON IPC.
It follows Niri's documented protocol:
<https://github.com/niri-wm/niri/wiki/IPC>.

## Boundary

- `NiriIpc` owns the Unix-domain sockets, newline framing, JSON parsing,
  reconnect backoff, request timeouts, and typed compositor actions.
- `platform/compositor/NiriService.qml` is the QML-facing transport facade.
- `platform/workspace/providers/NiriWorkspaceProvider.qml` translates raw Niri
  events into the compositor-independent workspace contract.
- `WorkspaceService.qml` remains the only owner of canonical workspace and
  window state.

This keeps Niri protocol details out of feature code while avoiding a resident
`niri msg --json event-stream` process and short-lived action processes.

## Connections

Niri accepts one request per IPC connection. The module therefore keeps one
reconnecting socket for `EventStream` and opens short-lived asynchronous sockets
for actions. Cross-output workspace focus is serialized as `FocusMonitor`
followed by `FocusWorkspace` only after the first response succeeds.

The event stream provides a complete initial snapshot before incremental events.
Unknown event variants are intentionally forwarded unchanged so the provider can
ignore or adopt them without changing the transport.
