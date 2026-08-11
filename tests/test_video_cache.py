from __future__ import annotations

import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock


REPOSITORY = Path(__file__).resolve().parents[1]
TOOL = REPOSITORY / "tools/ateria-video-cache"
LOADER = importlib.machinery.SourceFileLoader("ateria_video_cache", str(TOOL))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
assert SPEC is not None
VIDEO_CACHE = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(VIDEO_CACHE)


class VideoCacheTests(unittest.TestCase):
    def test_target_dimensions_cover_display_without_upscaling(self) -> None:
        self.assertEqual(VIDEO_CACHE.target_dimensions(3840, 2160, 1920, 1080), (1920, 1080))
        self.assertEqual(VIDEO_CACHE.target_dimensions(1280, 720, 1920, 1080), (1280, 720))
        self.assertEqual(VIDEO_CACHE.target_dimensions(1080, 1920, 1920, 1080), (1080, 1920))
        self.assertEqual(VIDEO_CACHE.target_dimensions(3840, 1600, 1920, 1080), (2592, 1080))

    def test_cache_identity_changes_with_source_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "wallpaper.mp4"
            source.write_bytes(b"first")
            first_stat = source.stat()
            first = VIDEO_CACHE.cache_identity(source, first_stat, 1920, 1080)

            source.write_bytes(b"different contents")
            second = VIDEO_CACHE.cache_identity(source, source.stat(), 1920, 1080)
            resized = VIDEO_CACHE.cache_identity(source, source.stat(), 1280, 720)
            lower_frame_rate = VIDEO_CACHE.cache_identity(source, source.stat(), 1280, 720, "24")
            with mock.patch.object(VIDEO_CACHE, "CACHE_VERSION", VIDEO_CACHE.CACHE_VERSION + 1):
                upgraded_encoder = VIDEO_CACHE.cache_identity(source, source.stat(), 1280, 720, "24")

            self.assertNotEqual(first, second)
            self.assertNotEqual(second, resized)
            self.assertNotEqual(resized, lower_frame_rate)
            self.assertNotEqual(lower_frame_rate, upgraded_encoder)

    def test_output_frame_rate_preserves_lower_rates_and_caps_higher_rates(self) -> None:
        self.assertEqual(str(VIDEO_CACHE.output_frame_rate("24000/1001")), "24000/1001")
        self.assertEqual(str(VIDEO_CACHE.output_frame_rate("25/1")), "25")
        self.assertEqual(str(VIDEO_CACHE.output_frame_rate("60/1")), "30")

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
            target_width, target_height = VIDEO_CACHE.target_dimensions(3840, 2160, 1920, 1080)
            target_frame_rate = VIDEO_CACHE.output_frame_rate(metadata["frameRate"])
            cache_path = cache_dir / (
                VIDEO_CACHE.cache_identity(
                    source, stat, target_width, target_height, target_frame_rate
                )
                + ".mp4"
            )
            cache_path.parent.mkdir(parents=True)
            cache_path.write_bytes(b"cached video")
            preview_path = VIDEO_CACHE.thumbnail_path(cache_dir, source, stat)
            manifest = {
                "version": VIDEO_CACHE.MANIFEST_VERSION,
                "entries": {
                    str(source): VIDEO_CACHE.stored_entry(
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
            VIDEO_CACHE.write_manifest(cache_dir, manifest)
            args = SimpleNamespace(
                cache_dir=str(cache_dir),
                rebuild=False,
                width=1920,
                height=1080,
                sources=[str(source)],
            )
            emitted: list[dict[str, object]] = []

            with (
                mock.patch.object(VIDEO_CACHE, "probe_video", side_effect=AssertionError("unexpected ffprobe")),
                mock.patch.object(VIDEO_CACHE, "find_vaapi_device", return_value=""),
                mock.patch.object(VIDEO_CACHE, "emit", side_effect=emitted.append),
            ):
                self.assertEqual(VIDEO_CACHE.scan(args), 0)

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
            preview_path = VIDEO_CACHE.thumbnail_path(cache_dir, source, source.stat())
            preview_path.parent.mkdir(parents=True)
            preview_path.write_bytes(b"jpeg")
            emitted: list[dict[str, object]] = []
            args = SimpleNamespace(cache_dir=str(cache_dir), source=str(source), input=None)

            with (
                mock.patch.object(VIDEO_CACHE.subprocess, "run", side_effect=AssertionError("unexpected ffmpeg")),
                mock.patch.object(VIDEO_CACHE, "emit", side_effect=emitted.append),
            ):
                self.assertEqual(VIDEO_CACHE.generate_thumbnail(args), 0)

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
            target_width, target_height = VIDEO_CACHE.target_dimensions(3840, 2160, 1920, 1080)
            target_frame_rate = VIDEO_CACHE.output_frame_rate(metadata["frameRate"])
            cache_path = cache_dir / (
                VIDEO_CACHE.cache_identity(
                    source, stat, target_width, target_height, target_frame_rate
                )
                + ".mp4"
            )
            preview_path = VIDEO_CACHE.thumbnail_path(cache_dir, source, stat)
            cache_path.parent.mkdir(parents=True)
            preview_path.parent.mkdir(parents=True)
            cache_path.write_bytes(b"cached video")
            preview_path.write_bytes(b"jpeg")
            VIDEO_CACHE.write_manifest(
                cache_dir,
                {
                    "version": VIDEO_CACHE.MANIFEST_VERSION,
                    "entries": {
                        str(source): VIDEO_CACHE.stored_entry(
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
                mock.patch.object(VIDEO_CACHE, "probe_video", side_effect=AssertionError("unexpected ffprobe")),
                mock.patch.object(VIDEO_CACHE, "find_vaapi_device", return_value=""),
                mock.patch.object(VIDEO_CACHE, "emit", side_effect=emitted.append),
            ):
                self.assertEqual(VIDEO_CACHE.scan(args), 0)

            result = emitted[-1]["entries"][0]
            self.assertEqual(result["status"], "queued")
            self.assertEqual(result["thumbnailStatus"], "queued")
            self.assertFalse(cache_path.exists())
            self.assertFalse(preview_path.exists())

    def test_manifest_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory)
            manifest = {
                "version": VIDEO_CACHE.MANIFEST_VERSION,
                "entries": {"/wallpaper.mp4": {"cachePath": "/cache/video.mp4"}},
            }
            VIDEO_CACHE.write_manifest(cache_dir, manifest)
            self.assertEqual(VIDEO_CACHE.load_manifest(cache_dir), manifest)


if __name__ == "__main__":
    unittest.main()
