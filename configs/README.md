# Ateria configuration presets

Ateria provides optional configuration presets for supported applications.
Each preset is a component in `manifest.toml`.

The configuration manager installs only the component that you select.
It detects applications from the commands in the manifest.
The detection result depends on the applications available on your system.

## Requirements

- Python 3.11 or later
- No third-party Python packages
- The selected application, unless you use `--force`

Run all commands from the Ateria project root.

## Supported components

| Component | Managed files | User-owned files | Generated color file |
| --- | --- | --- | --- |
| Niri | `config.kdl`, `ateria/defaults.kdl`, `ateria/ateria-env.sh`, `ateria/binds.kdl`, `ateria/rules.kdl` | `applications.kdl`, `user-config.kdl` | `ateria/colors.kdl` |
| Kitty | `kitty.conf` | `user.conf` | `ateria-colors.conf` |
| Foot | `foot.ini`, `ateria/defaults.ini`, `ateria/apply-colors` | `user.ini` | `ateria-colors.ini`, `foot-sequences` |
| Fish | `config.fish` | `user.fish`, `user-colors.fish` | `ateria-colors.fish` |

Ateria controls managed files.
Put personal changes in the user-owned files.

The configuration manager creates a user-owned file only when it is missing.
The configuration manager does not replace user-owned files or generated color files.
Matugen replaces generated color files when the wallpaper palette changes.
Ateria runs Matugen through `tools/ateria-matugen`.
The launcher resolves output paths from `XDG_CONFIG_HOME` and `XDG_STATE_HOME`.
It reloads only the installed components after Matugen creates a palette.

## List components

Use this command to show component availability and installation status:

```sh
./tools/ateria-config list
```

`available` means that the required application commands exist.
`not detected` means that one or more required commands do not exist.

## Install a component

Install one component at a time:

```sh
./tools/ateria-config install niri
./tools/ateria-config install kitty
./tools/ateria-config install foot
./tools/ateria-config install fish
```

If the manifest defines validation, the configuration manager validates the component first.
It shows each managed file that it must replace.
It asks for confirmation before it replaces these files.

Use `--yes` for a noninteractive installation:

```sh
./tools/ateria-config install niri --yes
```

Use `--force` when the application is not installed:

```sh
./tools/ateria-config install niri --force
```

## File load order

Each preset loads the generated colors before the user-owned settings.
This order lets personal settings override the preset.

Niri uses this order:

1. `ateria/colors.kdl`
2. `ateria/defaults.kdl`
3. `applications.kdl`
4. `ateria/binds.kdl`
5. `ateria/rules.kdl`
6. `user-config.kdl`

### Runtime environment

The Niri preset also installs `ateria/ateria-env.sh`, which `defaults.kdl` sources
before starting Quickshell. It bounds Quickshell's jemalloc arenas, selects the
low-power VAAPI path when available, and limits GLVND to the EGL driver for the
compositor's GPU so unused GPUs do not cost memory. If the GPU or GLVND driver
cannot be identified, it leaves the system default in place. Set
`ATERIA_EGL_VENDOR=none`, or set `__EGL_VENDOR_LIBRARY_FILENAMES` yourself, to
disable the EGL selection. Applications launched from the launcher always get
the unrestricted environment.

### Niri application keybinds

Edit `~/.config/niri/applications.kdl` to select the applications that Niri opens.
The default commands are:

| Keybind | Application variable | Default command |
| --- | --- | --- |
| `Mod+T` | `ATERIA_TERMINAL` | `kitty` |
| `Mod+W` | `ATERIA_BROWSER` | `firefox` |
| `Mod+C` | `ATERIA_EDITOR` | `code` |
| `Mod+E` | `ATERIA_FILE_MANAGER` | `thunar` |
| `Ctrl+Alt+V` | `ATERIA_AUDIO_SETTINGS` | `pavucontrol` |

The application values can contain command arguments.
Niri reloads the variables and keybinds when the configuration changes.
`Mod+Ctrl+C` centers a column, and `Mod+G` toggles the tabbed column display.

Kitty uses this order:

1. `ateria-colors.conf`
2. Settings in `kitty.conf`
3. `user.conf`

Foot uses this order:

1. `ateria-colors.ini`
2. `ateria/defaults.ini`
3. `user.ini`

Matugen writes Foot's OSC color sequences to the Ateria state directory.
It sends these sequences to open terminals after each palette change.
Fish sends the saved sequences to each new Foot terminal during startup.
Restart Foot to apply changes to settings other than colors.

Fish loads `ateria-colors.fish` before each prompt.
Fish then loads `user-colors.fish` so that personal colors take priority.
Fish loads `user.fish` after the other preset settings during shell startup.

## Show status

Show the status of all components:

```sh
./tools/ateria-config status
```

Show the status of one component:

```sh
./tools/ateria-config status niri
```

The status also shows local changes and available preset updates.

## Update components

Update one installed component:

```sh
./tools/ateria-config update niri
```

Update all installed components:

```sh
./tools/ateria-config update
```

The configuration manager replaces an unchanged managed file when Ateria has a new version.
It preserves a managed file that contains local changes.
For a conflict, it writes the new preset next to the managed file with a `.new` suffix.

Review the `.new` file and merge the changes manually.

## Backups

The configuration manager backs up existing managed files during installation.
It stores backups in this directory:

```text
$XDG_STATE_HOME/ateria/backups/
```

If `XDG_STATE_HOME` is not set, Ateria uses this directory:

```text
~/.local/state/ateria/backups/
```

Each installation gets a directory with a UTC timestamp and a component name.
The `backup.json` file records each original destination.
Ateria keeps the backup after uninstallation.

## Uninstall a component

Uninstall one component:

```sh
./tools/ateria-config uninstall niri
```

Use `--yes` for a noninteractive uninstallation:

```sh
./tools/ateria-config uninstall niri --yes
```

During uninstallation, the configuration manager uses these rules:

1. It removes unchanged managed files.
2. It preserves managed files that contain local changes.
3. It restores original files when their destinations are empty.
4. It restores original symbolic links when their destinations are empty.
5. It keeps user-owned files and generated color files.

## State file

The configuration manager stores component state and installed file hashes here:

```text
$XDG_STATE_HOME/ateria/configs.json
```

If `XDG_STATE_HOME` is not set, Ateria uses this file:

```text
~/.local/state/ateria/configs.json
```

Do not edit the state file while the configuration manager runs.
