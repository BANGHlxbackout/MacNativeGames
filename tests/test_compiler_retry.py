"""Test the retry policy used when Metal's compiler service disconnects."""
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / "tests/compiler_retry_probe.m"


@unittest.skipUnless(platform.system() == "Darwin" and shutil.which("xcrun"), "needs macOS and Xcode clang")
class CompilerRetryTests(unittest.TestCase):
    def test_retries_only_xpc_interruptions_and_obeys_limit(self):
        with tempfile.TemporaryDirectory() as tmp:
            exe = Path(tmp) / "compiler-retry"
            built = subprocess.run(
                ["xcrun", "clang", "-fobjc-arc", "-fblocks", "-Wall", "-Wextra", "-Werror",
                 "-mmacosx-version-min=15.0", str(PROBE), "-framework", "Foundation", "-o", str(exe)],
                capture_output=True, text=True,
            )
            self.assertEqual(built.returncode, 0, built.stdout + built.stderr)
            run = subprocess.run([str(exe)], capture_output=True, text=True, timeout=30)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertIn("compiler retry policy ok", run.stdout)


if __name__ == "__main__":
    unittest.main()
