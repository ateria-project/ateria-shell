# Native module build and installation

The shell's compiled QML modules use the `Ateria.*` namespace. CMake builds
them under `.build/native/qml` for development and declares an install layout
for Qt's standard QML module directory. Each installed module contains its
generated plugin, backing library, `qmldir`, and type metadata. The plugin uses
an `$ORIGIN` install RPATH, so it never depends on the checkout's build path.

`tools/ateria-shell` performs an incremental release build, skipping
`cmake --build` entirely when no native source is newer than the last
successful build, and keeps two launch paths working:

- the wrapper prepends the build tree to `QML_IMPORT_PATH`, so it always runs
  the binaries from the current checkout;
- the wrapper also installs changed modules into Qt's standard QML directory,
  so later plain `qs` launches work without wrapper-specific variables.

The system QML directory is discovered from Qt with `qmake6` or `qtpaths`.
Because that directory is normally root-owned, the first install and native
module updates request `sudo` when the wrapper runs in a terminal. A signature
of the built plugins prevents repeated installation and elevation when nothing
changed. Non-interactive launches continue with the build-tree modules and
print a warning if an update still needs an interactive install.

The launcher supports these development overrides:

- `ATERIA_NATIVE_BUILD_DIR` selects another build directory;
- `ATERIA_NATIVE_QML_INSTALL_DIR` selects another QML install directory;
- `ATERIA_SKIP_NATIVE_INSTALL=1` builds without installing;
- `ATERIA_SKIP_NATIVE_BUILD=1` skips both native build and installation.

For a staged non-root installation:

```sh
ATERIA_NATIVE_QML_INSTALL_DIR=/tmp/ateria-qml tools/ateria-shell
```
