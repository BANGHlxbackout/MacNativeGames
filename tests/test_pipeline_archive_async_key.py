"""Guard the async PSO worker against borrowing the submit thread's stack state."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "games/totk/third_party/d2r_gfx/gfx/nvn/nvn_mtl.m"


class AsyncPipelineArchiveKey(unittest.TestCase):
    def test_archive_key_is_materialized_before_dispatch(self):
        source = SOURCE.read_text()
        start = source.index("static void pso_pend_kick(")
        end = source.index("\nstatic id<MTLRenderPipelineState> pso_pend_take", start)
        body = source[start:end]
        dispatch = body.index("dispatch_async")
        submit_side = body[:dispatch]
        worker = body[dispatch:]

        self.assertIn("NSString *archive_key = pso_archive_key(k, vs, fs, 0);", submit_side)
        self.assertIn("pso_new(d, archive_key, &e)", worker)
        self.assertNotIn("pso_archive_key(k", worker)


if __name__ == "__main__":
    unittest.main()
