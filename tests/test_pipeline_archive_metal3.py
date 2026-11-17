"""Compile and exercise render/compute MTLBinaryArchive on the macOS 15 Metal 3 runner."""
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / "tests/pipeline_archive_metal3_probe.m"


@unittest.skipUnless(platform.system() == "Darwin" and shutil.which("xcrun"), "needs macOS 15 and Xcode clang")
class Metal3PipelineArchive(unittest.TestCase):
    def test_render_and_compute_archives_round_trip(self):
        with tempfile.TemporaryDirectory() as tmp:
            exe = Path(tmp) / "pipeline-archive"
            built = subprocess.run(
                ["xcrun", "clang", "-fobjc-arc", "-fblocks", "-Wall", "-Wextra", "-Werror",
                 "-mmacosx-version-min=15.0", "-I", str(ROOT), str(PROBE),
                 "-framework", "Metal", "-framework", "Foundation", "-o", str(exe)],
                capture_output=True, text=True,
            )
            self.assertEqual(built.returncode, 0, built.stdout + built.stderr)
            run = subprocess.run([str(exe)], capture_output=True, text=True, timeout=120)
            if run.returncode == 77:
                self.skipTest(run.stdout.strip() or "no Metal device")
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertIn("Metal 3 binary archive render+compute ok", run.stdout)


if __name__ == "__main__":
    unittest.main()
