# Metal 3 fork optimizations

This branch keeps the macOS 15 / Metal 3 path. It does not import MetalFX Frame Interpolation, MetalFX Temporal AA, or Metal 4 command-buffer / residency APIs from Main.

## Resolution

- `TOTK_RENDER_RES` remains the resolution/dimension control; it is not restricted to 1080p.
- No fixed output resolution is imposed; `TOTK_RENDER_RES` continues to select the render dimensions.

## Runtime controls

| Variable | Default | Effect |
|---|---:|---|
| `TOTK_DIRTY_FAST` | on | Thread-local range lookup caching and 64-page generation blocks for dirty-page checks. Set to `0` to disable the hash/block fast paths and use page-by-page generation checks. |
| `TOTK_HEAP_REUSE` | off | Reuse placement heaps for eligible private render-target textures. Set to `1` to enable. Heap resources use tracked hazard mode so Metal 3's automatic hazard tracking remains active. |
| `TOTK_PIPELINE_ARCHIVE` | on | Persist ordinary render/compute pipelines in Metal binary archives. Set to `0` to disable. Archive misses fall back to normal compilation. |

The pipeline archive intentionally excludes border-specialized, merged, host-owned, and MetalFX pipeline variants. The archive identity is scoped to GPU, OS version, and the Metal 3 fork's PSO-key schema. A cache miss is never treated as a valid pipeline: the creation path uses `MTLPipelineOptionFailOnBinaryArchiveMiss` and recompiles normally.

## Validation

The added macOS/Xcode tests cover:

- dirty-page protection versus pool-retirement race;
- 64-page dirty-generation skip behavior;
- placement-heap reuse and idle trimming;
- pipeline-archive identity, publication, and mapped archive reads.

These are test additions, not a claim of completed M2/macOS 15 runtime validation. Build and gameplay validation on the target machine is still required before enabling heap reuse or treating performance changes as measured.
