# Native wallpaper architecture

Wallpaper caching is a compiled Qt QML module. QML still renders wallpapers,
owns transitions, and supplies shell policy such as the current power mode.
Media discovery and processing do not run through a Python helper.

## Layers

```text
Wallpaper UI and renderer
  WallpaperController.qml / WallpaperSwitcherPanel.qml
        |
Stable shell facade
  WallpaperCacheService.qml
        |
QML module: Ateria.Wallpaper
  WallpaperManager / MatugenRunner
        |
QtCore / QtGui                  FFprobe / FFmpeg
manifest, jobs, QImage          video metadata and encoding
```

`WallpaperCacheService.qml` keeps translations and maps `PowerService` state
onto the native policy inputs. Its public API is unchanged. Cache state is held
as typed C++ entries and looked up on demand; a lightweight revision signal
makes individual lookups observable without copying the full entry map through
the QML engine after every FFmpeg progress event.

`WallpaperManager` owns the debounce timers, queues, cache manifest, atomic
writes, cache cleanup, FFprobe/FFmpeg processes, hardware-encoder detection,
and bounded thumbnail/transcode scheduling. Still images use `QImageReader`
and `QImageWriter` on the global Qt thread pool, so preparing an image no longer
starts Python, FFprobe, and FFmpeg processes. Oversized images are decoded near
their display-sized target and installed through `QSaveFile`.

Video processes remain external because FFmpeg provides the codecs and VA-API
pipeline, but they are started and monitored directly by Qt. Hardware failure
falls back to a low-priority, single-threaded software encode. Work retains the
existing power rules: power saver pauses conversion, software conversion waits
for external power, and on-battery hardware conversion only prepares the
selected wallpaper. Thumbnails remain available in bounded bursts. Native
child-process scheduling replaces separate `nice` and `ionice` wrapper
processes for background FFmpeg work.

`MatugenService` uses a short debounce and waits for native cache revisions. It
consumes the same video thumbnail when it is ready and prefers the existing
display-sized cache for still images, falling back to the original after a
bounded wait on a first-time cache miss. `MatugenRunner` starts the wrapper at
background CPU priority and idle I/O priority on Linux; Matugen and its reload
hooks inherit that scheduling policy. Shader transitions therefore retain
priority without a fixed timing delay. Valid Matugen JSON is applied as soon as
it reaches the shell, while external compositor and terminal reload hooks
finish in the wrapper process. This avoids polling, fixed visual delays,
duplicate FFmpeg decoding, basename collisions in `/tmp`, and unbounded
temporary preview files. If native thumbnail generation fails or times out,
the existing color scheme remains in place and the normal generation error
signal is emitted.

Existing manifest fingerprints are read at nanosecond precision. A compatible
cached video is adopted even when it was created by a different cache-version
number, provided its source fingerprint, display profile, output file size,
and output modification time all match. Moving to the native module therefore
does not trigger an unnecessary rebuild of valid user caches.

The module URI is `Ateria.Wallpaper`; the shared native launcher builds it,
uses the generated QML import root for the current process, and installs
changed modules for plain `qs` launches. Building needs Qt 6.6 or newer with
Core, Concurrent, Gui, and Qml. Runtime video preparation also needs FFmpeg and
FFprobe. See [`native/ARCHITECTURE.md`](../ARCHITECTURE.md) for the shared
installation rules.

Native tests are opt-in so normal builds do not require Qt Test:

```sh
cmake -S native -B .build/native-tests -DATERIA_BUILD_TESTS=ON
cmake --build .build/native-tests --parallel
ctest --test-dir .build/native-tests --output-on-failure
```

The generated QML singleton can also be checked independently:

```sh
qml6 -I .build/native/qml native/wallpaper/tests/smoke.qml
```
