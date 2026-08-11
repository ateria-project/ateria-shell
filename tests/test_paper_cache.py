from __future__ import annotations

import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock


REPOSITORY = Path(__file__).resolve().parents[1]
TOOL = REPOSITORY / "tools/ateria-paper-cache"
LOADER = importlib.machinery.SourceFileLoader("ateria_paper_cache", str(TOOL))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
assert SPEC is not None
PAPER_CACHE = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(PAPER_CACHE)


class PaperCacheTests(unittest.TestCase):
    def test_target_dimensions_cover_display_without_upscaling(self) -> None:
        self.assertEqual(PAPER_CACHE.target_dimensions(3840, 2160, 1920, 1080), (1920, 1080))
        self.assertEqual(PAPER_CACHE.target_dimensions(1280, 720, 1920, 1080), (1280, 720))
        self.assertEqual(PAPER_CACHE.target_dimensions(1080, 1920, 1920, 1080), (1080, 1920))
        self.assertEqual(PAPER_CACHE.target_dimensions(3840, 1600, 1920, 1080), (2592, 1080))

    def test_image_target_dimensions_cover_display_without_upscaling(self) -> None:
        self.assertEqual(PAPER_CACHE.image_target_dimensions(6048, 4024, 1920, 1080), (1920, 1278))
        self.assertEqual(PAPER_CACHE.image_target_dimensions(3840, 1600, 1920, 1080), (2592, 1080))
        self.assertEqual(PAPER_CACHE.image_target_dimensions(1280, 720, 1920, 1080), (1280, 720))
        self.assertEqual(PAPER_CACHE.image_target_dimensions(1080, 1920, 1920, 1080), (1080, 1920))

    def test_image_cache_keeps_smaller_original_without_launching_ffmpeg(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "wallpaper.jpg"
            source.write_bytes(b"source")
            args = SimpleNamespace(
                cache_dir=str(root / "cache"),
                width=1920,
                height=1080,
                source=str(source),
            )
            emitted: list[dict[str, object]] = []

            with (
                mock.patch.object(PAPER_CACHE, "probe_image", return_value={"width": 1280, "height": 720}),
                mock.patch.object(PAPER_CACHE.subprocess, "run", side_effect=AssertionError("unexpected ffmpeg")),
                mock.patch.object(PAPER_CACHE, "emit", side_effect=emitted.append),
            ):
                self.assertEqual(PAPER_CACHE.generate_image_cache(args), 0)

            self.assertEqual(emitted[-1]["playbackPath"], str(source))
            self.assertFalse(emitted[-1]["generated"])

    def test_image_cache_generates_lossless_cover_once(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "wallpaper.jpg"
            source.write_bytes(b"source")
            args = SimpleNamespace(
                cache_dir=str(root / "cache"),
                width=1920,
                height=1080,
                source=str(source),
            )
            commands: list[list[str]] = []
            emitted: list[dict[str, object]] = []

            def run_ffmpeg(command, **kwargs):
                commands.append(command)
                Path(command[-1]).write_bytes(b"lossless png")
                return SimpleNamespace(returncode=0, stderr="")

            with (
                mock.patch.object(PAPER_CACHE, "probe_image", return_value={"width": 6048, "height": 4024}),
                mock.patch.object(PAPER_CACHE.subprocess, "run", side_effect=run_ffmpeg),
                mock.patch.object(PAPER_CACHE, "emit", side_effect=emitted.append),
            ):
                self.assertEqual(PAPER_CACHE.generate_image_cache(args), 0)

            self.assertEqual(len(commands), 1)
            self.assertIn("png", commands[0])
            self.assertIn("scale=1920:1278:flags=lanczos+accurate_rnd+full_chroma_int", commands[0])
            cached_path = Path(str(emitted[-1]["playbackPath"]))
            self.assertTrue(cached_path.is_file())
            self.assertTrue(emitted[-1]["generated"])

            emitted.clear()
            with (
                mock.patch.object(PAPER_CACHE, "probe_image", return_value={"width": 6048, "height": 4024}),
                mock.patch.object(PAPER_CACHE.subprocess, "run", side_effect=AssertionError("unexpected ffmpeg")),
                mock.patch.object(PAPER_CACHE, "emit", side_effect=emitted.append),
            ):
                self.assertEqual(PAPER_CACHE.generate_image_cache(args), 0)

            self.assertEqual(Path(str(emitted[-1]["playbackPath"])), cached_path)

    def test_image_cache_identity_changes_with_source_target_and_version(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "wallpaper.jpg"
            source.write_bytes(b"first")
            first = PAPER_CACHE.image_cache_identity(source, source.stat(), 1920, 1278)

            source.write_bytes(b"different contents")
            changed_source = PAPER_CACHE.image_cache_identity(source, source.stat(), 1920, 1278)
            changed_target = PAPER_CACHE.image_cache_identity(source, source.stat(), 2560, 1704)
            with mock.patch.object(
                PAPER_CACHE, "IMAGE_CACHE_VERSION", PAPER_CACHE.IMAGE_CACHE_VERSION + 1
            ):
                changed_version = PAPER_CACHE.image_cache_identity(
                    source, source.stat(), 2560, 1704
                )

            self.assertNotEqual(first, changed_source)
            self.assertNotEqual(changed_source, changed_target)
            self.assertNotEqual(changed_target, changed_version)

    def test_cache_identity_changes_with_source_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "wallpaper.mp4"
            source.write_bytes(b"first")
            first_stat = source.stat()
            first = PAPER_CACHE.cache_identity(source, first_stat, 1920, 1080)

            source.write_bytes(b"different contents")
            second = PAPER_CACHE.cache_identity(source, source.stat(), 1920, 1080)
            resized = PAPER_CACHE.cache_identity(source, source.stat(), 1280, 720)
            lower_frame_rate = PAPER_CACHE.cache_identity(source, source.stat(), 1280, 720, "24")
            with mock.patch.object(PAPER_CACHE, "CACHE_VERSION", PAPER_CACHE.CACHE_VERSION + 1):
                upgraded_encoder = PAPER_CACHE.cache_identity(source, source.stat(), 1280, 720, "24")

            self.assertNotEqual(first, second)
            self.assertNotEqual(second, resized)
            self.assertNotEqual(resized, lower_frame_rate)
            self.assertNotEqual(lower_frame_rate, upgraded_encoder)

    def test_output_frame_rate_preserves_lower_rates_and_caps_higher_rates(self) -> None:
        self.assertEqual(str(PAPER_CACHE.output_frame_rate("24000/1001")), "24000/1001")
        self.assertEqual(str(PAPER_CACHE.output_frame_rate("25/1")), "25")
        self.assertEqual(str(PAPER_CACHE.output_frame_rate("60/1")), "30")

    def test_scan_reuses_manifest_metadata_and_cached_video_without_probing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cache_dir = root / "cache"
            source = root / "wallpaper.mp4"
            source.write_bytes(b"source")
            stat = source.stat()
            metadata = {
                "width": 3840,
                "height": 2160,
                "duration": 12.5,
                "frameRate": "24000/1001",
            }
            target_width, target_height = PAPER_CACHE.target_dimensions(3840, 2160, 1920, 1080)
            target_frame_rate = PAPER_CACHE.output_frame_rate(metadata["frameRate"])
            cache_path = cache_dir / (
                PAPER_CACHE.cache_identity(
                    source, stat, target_width, target_height, target_frame_rate
                )
                + ".mp4"
            )
            cache_path.parent.mkdir(parents=True)
            cache_path.write_bytes(b"cached video")
            preview_path = PAPER_CACHE.thumbnail_path(cache_dir, source, stat)
            manifest = {
                "version": PAPER_CACHE.MANIFEST_VERSION,
                "entries": {
                    str(source): PAPER_CACHE.stored_entry(
                        stat,
                        metadata,
                        target_width,
                        target_height,
                        target_frame_rate,
                        cache_path,
                        preview_path,
                    )
                },
            }
            PAPER_CACHE.write_manifest(cache_dir, manifest)
            args = SimpleNamespace(
                cache_dir=str(cache_dir),
                rebuild=False,
                width=1920,
                height=1080,
                sources=[str(source)],
            )
            emitted: list[dict[str, object]] = []

            with (
                mock.patch.object(PAPER_CACHE, "probe_video", side_effect=AssertionError("unexpected ffprobe")),
                mock.patch.object(PAPER_CACHE, "find_vaapi_device", return_value=""),
                mock.patch.object(PAPER_CACHE, "emit", side_effect=emitted.append),
            ):
                self.assertEqual(PAPER_CACHE.scan(args), 0)

            result = emitted[-1]["entries"][0]
            self.assertEqual(result["status"], "ready")
            self.assertEqual(result["sourceFrameRate"], "24000/1001")
            self.assertEqual(result["thumbnailStatus"], "queued")

    def test_existing_thumbnail_does_not_launch_ffmpeg(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cache_dir = root / "cache"
            source = root / "wallpaper.mp4"
            source.write_bytes(b"source")
            preview_path = PAPER_CACHE.thumbnail_path(cache_dir, source, source.stat())
            preview_path.parent.mkdir(parents=True)
            preview_path.write_bytes(b"jpeg")
            emitted: list[dict[str, object]] = []
            args = SimpleNamespace(cache_dir=str(cache_dir), source=str(source), input=None)

            with (
                mock.patch.object(PAPER_CACHE.subprocess, "run", side_effect=AssertionError("unexpected ffmpeg")),
                mock.patch.object(PAPER_CACHE, "emit", side_effect=emitted.append),
            ):
                self.assertEqual(PAPER_CACHE.generate_thumbnail(args), 0)

            self.assertEqual(emitted, [{"type": "thumbnailReady", "thumbnailPath": str(preview_path)}])

    def test_rebuild_reuses_source_metadata_but_removes_generated_media(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cache_dir = root / "cache"
            source = root / "wallpaper.mp4"
            source.write_bytes(b"source")
            stat = source.stat()
            metadata = {
                "width": 3840,
                "height": 2160,
                "duration": 12.5,
                "frameRate": "24",
            }
            target_width, target_height = PAPER_CACHE.target_dimensions(3840, 2160, 1920, 1080)
            target_frame_rate = PAPER_CACHE.output_frame_rate(metadata["frameRate"])
            cache_path = cache_dir / (
                PAPER_CACHE.cache_identity(
                    source, stat, target_width, target_height, target_frame_rate
                )
                + ".mp4"
            )
            preview_path = PAPER_CACHE.thumbnail_path(cache_dir, source, stat)
            cache_path.parent.mkdir(parents=True)
            preview_path.parent.mkdir(parents=True)
            cache_path.write_bytes(b"cached video")
            preview_path.write_bytes(b"jpeg")
            PAPER_CACHE.write_manifest(
                cache_dir,
                {
                    "version": PAPER_CACHE.MANIFEST_VERSION,
                    "entries": {
                        str(source): PAPER_CACHE.stored_entry(
                            stat,
                            metadata,
                            target_width,
                            target_height,
                            target_frame_rate,
                            cache_path,
                            preview_path,
                        )
                    },
                },
            )
            args = SimpleNamespace(
                cache_dir=str(cache_dir),
                rebuild=True,
                width=1920,
                height=1080,
                sources=[str(source)],
            )
            emitted: list[dict[str, object]] = []

            with (
                mock.patch.object(PAPER_CACHE, "probe_video", side_effect=AssertionError("unexpected ffprobe")),
                mock.patch.object(PAPER_CACHE, "find_vaapi_device", return_value=""),
                mock.patch.object(PAPER_CACHE, "emit", side_effect=emitted.append),
            ):
                self.assertEqual(PAPER_CACHE.scan(args), 0)

            result = emitted[-1]["entries"][0]
            self.assertEqual(result["status"], "queued")
            self.assertEqual(result["thumbnailStatus"], "queued")
            self.assertFalse(cache_path.exists())
            self.assertFalse(preview_path.exists())

    def test_manifest_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory)
            manifest = {
                "version": PAPER_CACHE.MANIFEST_VERSION,
                "entries": {"/wallpaper.mp4": {"cachePath": "/cache/video.mp4"}},
            }
            PAPER_CACHE.write_manifest(cache_dir, manifest)
            self.assertEqual(PAPER_CACHE.load_manifest(cache_dir), manifest)


if __name__ == "__main__":
    unittest.main()
