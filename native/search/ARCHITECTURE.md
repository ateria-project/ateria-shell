# Native search architecture

The `Ateria.Search` QML module owns search work that is expensive enough to
block Qt Quick when implemented in JavaScript. UI controllers continue to own
selection and presentation state.

`LauncherSearchModel` builds a normalized application index only when the
desktop-entry collection changes. Query updates reuse that index and execute
Unicode normalization, bounded optimal-string-alignment distance, acronym and
subsequence matching, usage weighting, and result sorting in compiled C++.
Original desktop-entry objects are returned unchanged, so launcher delegates
retain the same API.

Small UI filters remain in QML. Moving them would add QVariant conversion and
signal overhead without reducing meaningful work.

Native tests are included in the shared test build:

```sh
cmake -S native -B .build/native-tests -DATERIA_BUILD_TESTS=ON
cmake --build .build/native-tests --parallel
ctest --test-dir .build/native-tests --output-on-failure
```

The QML object boundary can be checked independently:

```sh
qml6 -I .build/native/qml native/search/tests/smoke.qml
```
