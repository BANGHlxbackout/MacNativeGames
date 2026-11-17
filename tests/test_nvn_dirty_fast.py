"""Exercise the dirty-page block-generation fast path against the real C implementation."""
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
DIRTY = REPO / "games/totk/third_party/d2r_gfx/gfx/nvn/nvn_dirty.c"
HARNESS = Path(__file__).with_name("nvn_dirty_fast_probe.c")


@unittest.skipUnless(platform.system() == "Darwin" and shutil.which("xcrun"), "macOS with clang")
class DirtyFastPath(unittest.TestCase):
    def test_clean_blocks_are_skipped_and_dirty_pages_are_found(self):
        with tempfile.TemporaryDirectory() as tmp:
            exe = Path(tmp) / "dirty-fast"
            subprocess.run(
                ["xcrun", "clang", "-std=gnu11", "-O1", "-g", "-Wall",
                 f'-DDIRTY_C="{DIRTY}"', str(HARNESS), "-o", str(exe)],
                check=True, capture_output=True, text=True,
            )
            run = subprocess.run([str(exe)], capture_output=True, text=True, timeout=30)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertIn("dirty fast path ok", run.stdout)


class DirtyInitializationTests(unittest.TestCase):
    def test_fault_hooks_and_page_geometry_use_pthread_once(self):
        source = DIRTY.read_text()
        self.assertIn("static pthread_once_t g_dirty_init_once = PTHREAD_ONCE_INIT;", source)
        self.assertIn("pthread_once(&g_dirty_init_once, dirty_init);", source)
        self.assertNotIn("static int inited;", source)


if __name__ == "__main__":
    unittest.main()
