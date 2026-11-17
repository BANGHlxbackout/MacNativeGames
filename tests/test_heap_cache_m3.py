"""Smoke-test the placement-heap cache with Metal 3 APIs (no Metal 4 command queue required)."""
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
HARNESS = Path(__file__).with_name("heap_cache_m3_probe.m")


@unittest.skipUnless(platform.system() == "Darwin" and shutil.which("xcrun"), "macOS with Xcode clang")
class Metal3HeapCache(unittest.TestCase):
    def test_private_texture_heap_is_reused_and_trimmed(self):
        with tempfile.TemporaryDirectory() as tmp:
            exe = Path(tmp) / "heap-cache"
            subprocess.run(
                ["xcrun", "clang", "-std=gnu11", "-fobjc-arc", "-fblocks", "-O1", "-Wall",
                 "-I", str(REPO), str(HARNESS), "-framework", "Metal", "-framework", "Foundation",
                 "-o", str(exe)],
                check=True, capture_output=True, text=True,
            )
            run = subprocess.run([str(exe)], capture_output=True, text=True, timeout=30)
            if run.returncode == 77:
                self.skipTest(run.stdout.strip() or "no Metal device")
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertIn("Metal 3 heap reuse ok", run.stdout)


if __name__ == "__main__":
    unittest.main()
