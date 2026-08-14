# Native Wi-Fi architecture

The Wi-Fi implementation is a compiled Qt QML module backed directly by
libnm. It does not import or call `Quickshell.Networking`, and it does not use
`nmcli`.

## Layers

```text
Material 3 feature QML
  WifiPage.qml
        |
Shell-facing facade
  NetworkService.qml
        |
QML module: Ateria.Network
  WifiManager (commands and aggregate state)
  WifiNetworkModel (typed, read-only list model)
        |
libnm / NetworkManager D-Bus API
```

`WifiManager` is the only QML singleton exported by the native module. It owns
the `NMClient`, all cancellables, operation state, adapter selection, and the
available and saved network models. libnm pointers never cross into QML.
Available network rows use stable IDs derived from SSID bytes and security
type; saved rows use the NetworkManager profile UUID. Commands resolve those
IDs back to the current native objects immediately before an operation.

`NetworkService.qml` is the stable application contract. The bar, quick
settings tile, and Wi-Fi page depend on this facade rather than on the C++ type.
This keeps UI naming and icon policy out of the native layer and lets the
native API evolve without changing every consumer.

## State and operations

The native layer subscribes to `NMClient`, device, access-point, and saved
connection signals. Related notifications are coalesced into one reconciliation
pass after 50 ms, so the models stay current without an idle polling timer.
Connection attempts use one additional three-second one-shot check to cover a
device returning to `DISCONNECTED` before NetworkManager emits another state
change. Model updates are reconciled by stable ID through row inserts, moves,
removals, and `dataChanged` signals. This preserves QML delegates and their open
menus while scan data changes. Access points with the same SSID and security are
grouped, with the strongest BSSID representing the group. The saved model is
populated from every visible NetworkManager infrastructure profile, even when
its access point is currently out of range.

All mutating libnm work is asynchronous. Only one connection/profile mutation
can run at a time; scans and connectivity checks have their own asynchronous
paths. A cancellable and a 60-second timeout bound every mutation. The model
marks the pending network as connecting until NetworkManager reports the Wi-Fi
device as activated or failed.

Native failures are translated from `GError` domains/codes and device-state
reasons into user-facing messages. Raw daemon messages are used only for a
small set of conservative fallback classifications and are never shown in the
UI. The add-network and saved-network pages keep errors local to operations
they started, so unrelated failures cannot leak into those flows.

The current public command surface covers:

- radio enable/disable and hardware-block state;
- adapter discovery and explicit adapter selection;
- one-shot and periodic scanning;
- activation of saved profiles;
- creation and activation of open, OWE, WEP, WPA/WPA2 Personal, and WPA3-SAE
  profiles, including hidden SSIDs;
- disconnect, forget, and auto-connect changes;
- NetworkManager connectivity checks and portal/limited/full state.

Existing enterprise profiles can be activated because NetworkManager owns
their secrets. Creating a new 802.1X profile is intentionally routed to system
network settings for now: a correct enterprise UI needs EAP method,
certificate, domain, and secret-agent flows rather than a password-only form.
That flow can be added behind `WifiManager` without changing the page model.

## Build and launch

The module URI is `Ateria.Network`. CMake writes the generated `qmldir`, type
metadata, and plugin to one import root at `.build/native/qml`.
Building requires CMake 3.24 or newer, Qt 6.6 or newer, and libnm 1.26 or
newer.

Run the shell through:

```sh
tools/ateria-shell
```

The launcher configures the native tree only when its cache is missing or has
incompatible runtime options, then incrementally builds the five runtime QML
plugins through the `ateria_native_modules` target. Development test targets
are disabled for normal shell launches. It uses the generated import root for
the current process and installs changed modules for plain `qs` launches. See
[`native/ARCHITECTURE.md`](../ARCHITECTURE.md) for the install layout and
development overrides.

For a module-only smoke check:

```sh
qml6 -I .build/native/qml native/network/tests/smoke.qml
```
