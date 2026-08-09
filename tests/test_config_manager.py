from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[1]
CONFIG_TOOL = REPOSITORY / "tools/ateria-config"
MATUGEN_TOOL = REPOSITORY / "tools/ateria-matugen"


class ConfigManagerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="ateria-config-test-")
        self.root = Path(self.temporary.name)
        self.config_home = self.root / "config"
        self.state_home = self.root / "state"
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()

        fake_niri = self.bin_dir / "niri"
        fake_niri.write_text(
            "#!/bin/sh\n"
            "if [ \"$1\" = validate ] && [ -n \"${FAKE_NIRI_FAIL:-}\" ]; then\n"
            "    echo 'deliberate validation failure' >&2\n"
            "    exit 1\n"
            "fi\n"
            "exit 0\n"
        )
        fake_niri.chmod(0o755)

        fake_fish = self.bin_dir / "fish"
        fake_fish.write_text(
            "#!/bin/sh\n"
            "if [ \"$1\" = -n ]; then\n"
            "    shift\n"
            "    for path do\n"
            "        if [ ! -f \"$path\" ]; then\n"
            "            echo \"missing validation input: $path\" >&2\n"
            "            exit 1\n"
            "        fi\n"
            "    done\n"
            "fi\n"
            "exit 0\n"
        )
        fake_fish.chmod(0o755)

        fake_foot = self.bin_dir / "foot"
        fake_foot.write_text(
            "#!/bin/sh\n"
            "if [ \"$1\" = --check-config ]; then\n"
            "    config=$3\n"
            "    while IFS= read -r line; do\n"
            "        case $line in\n"
            "            include=*)\n"
            "                path=$(printf '%s\\n' \"$line\" | cut -d= -f2-)\n"
            "                [ -f \"$path\" ] || { echo \"missing include: $path\" >&2; exit 1; }\n"
            "                ;;\n"
            "        esac\n"
            "    done < \"$config\"\n"
            "fi\n"
            "exit 0\n"
        )
        fake_foot.chmod(0o755)

        for command in ("kitty", "matugen", "pkill"):
            executable = self.bin_dir / command
            exit_code = 1 if command == "pkill" else 0
            executable.write_text(f"#!/bin/sh\nexit {exit_code}\n")
            executable.chmod(0o755)

        self.environment = {
            **os.environ,
            "XDG_CONFIG_HOME": str(self.config_home),
            "XDG_STATE_HOME": str(self.state_home),
            "PATH": str(self.bin_dir) + os.pathsep + os.environ.get("PATH", ""),
            "PYTHONDONTWRITEBYTECODE": "1",
        }

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_tool(
        self,
        *arguments: str,
        source_root: Path = REPOSITORY,
        check: bool = True,
        extra_environment: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        environment = dict(self.environment)
        environment["ATERIA_SOURCE_ROOT"] = str(source_root)
        if extra_environment:
            environment.update(extra_environment)
        return subprocess.run(
            [sys.executable, str(CONFIG_TOOL), *arguments],
            text=True,
            capture_output=True,
            check=check,
            env=environment,
        )

    def test_install_backs_up_existing_config_and_uninstall_restores_it(self) -> None:
        existing = self.config_home / "niri/config.kdl"
        existing.parent.mkdir(parents=True)
        existing.write_text("// existing user config\n")

        self.run_tool("install", "niri", "--yes")

        self.assertIn('include "./ateria/colors.kdl"', existing.read_text())
        self.assertTrue((self.config_home / "niri/ateria/defaults.kdl").is_file())
        self.assertTrue((self.config_home / "niri/applications.kdl").is_file())
        self.assertTrue((self.config_home / "niri/user-config.kdl").is_file())
        self.assertTrue((self.config_home / "niri/ateria/colors.kdl").is_file())

        state = json.loads((self.state_home / "ateria/configs.json").read_text())
        backup_dir = Path(state["components"]["niri"]["backup"])
        self.assertTrue((backup_dir / "backup.json").is_file())

        self.run_tool("uninstall", "niri", "--yes")
        self.assertEqual(existing.read_text(), "// existing user config\n")
        self.assertFalse((self.config_home / "niri/ateria/defaults.kdl").exists())
        self.assertTrue((self.config_home / "niri/applications.kdl").exists())
        self.assertTrue((self.config_home / "niri/user-config.kdl").exists())
        self.assertTrue((self.config_home / "niri/ateria/colors.kdl").exists())

    def test_seed_files_are_never_overwritten(self) -> None:
        user = self.config_home / "niri/user-config.kdl"
        colors = self.config_home / "niri/ateria/colors.kdl"
        user.parent.mkdir(parents=True)
        colors.parent.mkdir(parents=True)
        user.write_text("// personal overrides\n")
        colors.write_text("// current generated colors\n")

        self.run_tool("install", "niri", "--yes")

        self.assertEqual(user.read_text(), "// personal overrides\n")
        self.assertEqual(colors.read_text(), "// current generated colors\n")

    def test_kitty_has_the_same_backup_and_seed_contract(self) -> None:
        existing = self.config_home / "kitty/kitty.conf"
        existing.parent.mkdir(parents=True)
        existing.write_text("# existing kitty config\n")

        install = self.run_tool("install", "kitty", "--yes")

        self.assertIn("include ateria-colors.conf", existing.read_text())
        self.assertNotIn("could not reload", install.stderr)
        user = self.config_home / "kitty/user.conf"
        colors = self.config_home / "kitty/ateria-colors.conf"
        self.assertTrue(user.is_file())
        self.assertTrue(colors.is_file())
        user.write_text("# personal kitty overrides\n")

        self.run_tool("uninstall", "kitty", "--yes")

        self.assertEqual(existing.read_text(), "# existing kitty config\n")
        self.assertEqual(user.read_text(), "# personal kitty overrides\n")
        self.assertTrue(colors.is_file())

    def test_fish_has_the_same_backup_and_seed_contract(self) -> None:
        existing = self.config_home / "fish/config.fish"
        existing.parent.mkdir(parents=True)
        existing.write_text("# existing fish config\n")
        user = self.config_home / "fish/user.fish"
        user_colors = self.config_home / "fish/user-colors.fish"
        colors = self.config_home / "fish/ateria-colors.fish"
        user.write_text("# personal fish setup\n")
        user_colors.write_text("# personal fish colors\n")
        colors.write_text("# generated fish colors\n")

        self.run_tool("install", "fish", "--yes")

        self.assertIn("ateria-colors.fish", existing.read_text())
        self.assertTrue(user.is_file())
        self.assertTrue(user_colors.is_file())
        self.assertTrue(colors.is_file())

        self.run_tool("uninstall", "fish", "--yes")

        self.assertEqual(existing.read_text(), "# existing fish config\n")
        self.assertEqual(user.read_text(), "# personal fish setup\n")
        self.assertEqual(user_colors.read_text(), "# personal fish colors\n")
        self.assertEqual(colors.read_text(), "# generated fish colors\n")

    def test_foot_has_the_same_backup_and_seed_contract(self) -> None:
        existing = self.config_home / "foot/foot.ini"
        existing.parent.mkdir(parents=True)
        existing.write_text("# existing foot config\n")

        self.run_tool("install", "foot", "--yes")

        self.assertIn("ateria-colors.ini", existing.read_text())
        self.assertIn(str(self.config_home), existing.read_text())
        self.assertNotIn("~/.config", existing.read_text())
        defaults = self.config_home / "foot/ateria/defaults.ini"
        apply_colors = self.config_home / "foot/ateria/apply-colors"
        user = self.config_home / "foot/user.ini"
        colors = self.config_home / "foot/ateria-colors.ini"
        self.assertTrue(defaults.is_file())
        self.assertTrue(apply_colors.is_file())
        self.assertTrue(user.is_file())
        self.assertTrue(colors.is_file())
        user.write_text("# personal foot overrides\n")

        self.run_tool("uninstall", "foot", "--yes")

        self.assertEqual(existing.read_text(), "# existing foot config\n")
        self.assertFalse(defaults.exists())
        self.assertFalse(apply_colors.exists())
        self.assertEqual(user.read_text(), "# personal foot overrides\n")
        self.assertTrue(colors.is_file())

    def test_foot_live_colors_decode_saved_osc_sequences(self) -> None:
        sequences = self.state_home / "ateria/foot-sequences"
        sequences.parent.mkdir(parents=True)
        sequences.write_text(r"\033]10;#abcdef\033\\" + "\n")

        result = subprocess.run(
            [sys.executable, str(REPOSITORY / "configs/foot/ateria/apply-colors"), "--stdout"],
            capture_output=True,
            check=True,
            env=self.environment,
        )

        self.assertEqual(result.stdout, b"\x1b]10;#abcdef\x1b\\")

    def test_matugen_runtime_config_uses_xdg_paths(self) -> None:
        result = subprocess.run(
            [
                sys.executable,
                str(MATUGEN_TOOL),
                "image",
                "wallpaper.jpg",
                "--config",
                str(REPOSITORY / "matugen/config.toml"),
            ],
            capture_output=True,
            text=True,
            check=True,
            env=self.environment,
        )

        runtime = self.state_home / "ateria/matugen.toml"
        content = runtime.read_text()
        self.assertIn(str(self.config_home / "niri/ateria/colors.kdl"), content)
        self.assertIn(str(self.state_home / "ateria/foot-sequences"), content)
        self.assertNotIn("@CONFIG_HOME@", content)
        self.assertNotIn("@STATE_HOME@", content)

    def test_uninstall_restores_an_original_symlink(self) -> None:
        external = self.root / "dotfiles/niri.kdl"
        external.parent.mkdir(parents=True)
        external.write_text("// symlinked user config\n")
        existing = self.config_home / "niri/config.kdl"
        existing.parent.mkdir(parents=True)
        link_target = os.path.relpath(external, existing.parent)
        existing.symlink_to(link_target)

        self.run_tool("install", "niri", "--yes")

        self.assertFalse(existing.is_symlink())
        self.assertEqual(external.read_text(), "// symlinked user config\n")

        self.run_tool("uninstall", "niri", "--yes")

        self.assertTrue(existing.is_symlink())
        self.assertEqual(os.readlink(existing), link_target)
        self.assertEqual(existing.read_text(), "// symlinked user config\n")

    def test_update_fast_forwards_clean_files_and_surfaces_conflicts(self) -> None:
        source = self.root / "source"
        shutil.copytree(REPOSITORY / "configs", source / "configs")
        self.run_tool("install", "niri", "--yes", source_root=source)

        upstream = source / "configs/niri/ateria/defaults.kdl"
        installed = self.config_home / "niri/ateria/defaults.kdl"
        upstream.write_text(upstream.read_text() + "\n// upstream one\n")
        self.run_tool("update", "niri", source_root=source)
        self.assertIn("// upstream one", installed.read_text())

        installed.write_text(installed.read_text() + "// local change\n")
        upstream.write_text(upstream.read_text() + "// upstream two\n")
        self.run_tool("update", "niri", source_root=source)

        self.assertIn("// local change", installed.read_text())
        proposed = installed.with_name("defaults.kdl.new")
        self.assertIn("// upstream two", proposed.read_text())
        status = self.run_tool("status", "niri", source_root=source)
        self.assertIn("modified; update available", status.stdout)

    def test_update_without_source_changes_is_a_no_op(self) -> None:
        self.run_tool("install", "niri", "--yes")

        update = self.run_tool("update", "niri")

        self.assertIn("already up to date", update.stdout)

    def test_validation_failure_does_not_replace_existing_config(self) -> None:
        existing = self.config_home / "niri/config.kdl"
        existing.parent.mkdir(parents=True)
        existing.write_text("// keep me\n")

        result = self.run_tool(
            "install",
            "niri",
            "--yes",
            check=False,
            extra_environment={"FAKE_NIRI_FAIL": "1"},
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("validation failed", result.stderr)
        self.assertEqual(existing.read_text(), "// keep me\n")
        self.assertFalse((self.state_home / "ateria/configs.json").exists())

    def test_noninteractive_install_requires_explicit_confirmation(self) -> None:
        result = self.run_tool("install", "niri", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--yes", result.stderr)


if __name__ == "__main__":
    unittest.main()
