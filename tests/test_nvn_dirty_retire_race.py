"""Race regression for dirty-page protection versus pool retirement.

The protector must hold the pool-slot mutex from lookup through mprotect. If a
pool is retired in that window, its memory must be writable and untracked when
retirement returns. Runs on macOS because the implementation uses Mach timing.
"""
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
DIRTY = REPO / "games/totk/third_party/d2r_gfx/gfx/nvn/nvn_dirty.c"
HARNESS = Path(__file__).with_name("nvn_dirty_retire_race.c")


@unittest.skipUnless(platform.system() == "Darwin" and shutil.which("xcrun"), "macOS with clang")
class RetireRace(unittest.TestCase):
    def test_retirement_waits_for_protection(self):
        with tempfile.TemporaryDirectory() as tmp:
            exe = Path(tmp) / "race"
            subprocess.run(
                ["xcrun", "clang", "-std=gnu11", "-O1", "-g", "-Wall",
                 f'-DDIRTY_C="{DIRTY}"', str(HARNESS), "-o", str(exe)],
                check=True, capture_output=True, text=True,
            )
            run = subprocess.run([str(exe)], capture_output=True, text=True, timeout=60)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertEqual(run.stdout.strip().splitlines(),
                             ["the retirement was held off by the slot mutex", "ok"])


if __name__ == "__main__":
    unittest.main()
