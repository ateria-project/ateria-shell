# Native Bluetooth pairing architecture

Bluetooth discovery, adapter state, and device operations continue to use
Quickshell's BlueZ model. The pairing agent is a compiled QtDBus QML module;
there is no resident Python/GLib bridge or JSON protocol.

## Layers

```text
Bluetooth pages and pairing prompts
        |
Stable shell facade
  BluetoothService.qml
        |
QML module: Ateria.Bluetooth
  BluetoothAgent
        |
QtDBus system bus / org.bluez.Agent1
```

`BluetoothAgent` registers `/org/ateria/BluetoothAgent` with
`org.bluez.AgentManager1` using the `KeyboardDisplay` capability and requests
default-agent status asynchronously. It watches the BlueZ service owner and
uses bounded exponential retries after daemon restarts or registration
failures. Registration errors are translated into stable user-facing text.

Agent methods that require user input use QtDBus delayed replies. The incoming
D-Bus call is retained while QML presents the PIN, passkey, confirmation, or
authorization prompt. Accepting sends the correctly typed reply; rejecting,
canceling, timing out, or losing BlueZ sends the appropriate
`org.bluez.Error.Rejected` or `org.bluez.Error.Canceled` response. Requests time
out after two minutes.

Device names and addresses are enriched by `BluetoothService.qml` from its
existing live device model. The native D-Bus handler deliberately avoids a
blocking `Properties.GetAll` call, so a disappearing device cannot stall the
shell for the D-Bus default timeout.

Builds require Qt 6.6 or newer with Core, DBus, and Qml. Native tests exercise
the public state, display formatting, D-Bus method signatures, delayed void and
typed replies, and BlueZ rejection errors on an isolated session-bus object:

```sh
cmake -S native -B .build/native-tests -DATERIA_BUILD_TESTS=ON
cmake --build .build/native-tests --parallel
ctest --test-dir .build/native-tests --output-on-failure
```

The generated singleton has a module-only smoke check:

```sh
qml6 -I .build/native/qml native/bluetooth/tests/smoke.qml
```
