# Minimal patch scope

The minimal patch is generated against DS4
`54b36ed9ba42da31b24f2d1a5feb075c2475dbb1`. It contains four modified files.

| File/hunk | Why indispensable | What happens if removed |
| --- | --- | --- |
| `ds4.c`: opt-in verifier allocations | Allocates batch logits and frontier snapshots without loading a support model | The target-only oracle harness cannot call the batch verifier safely |
| `ds4.c`: SSD branch in `metal_graph_verify_suffix_tops_impl` | Maps target spans layer by layer and invokes the existing selected-address batch path | The resident verifier cannot service routed-expert misses |
| `ds4.c`: layer-major loop and output-head mapping | Runs all candidate rows together and produces per-position target decisions | No multi-token verification result exists |
| `ds4.c`: `ds4_session_oracle_verify_block` | Generates known-correct candidates, snapshots, compares state, rolls back and replays | Draft quality is no longer isolated and exact fallback cannot be checked |
| `ds4.c`: bounded state-digest helpers | Compares raw KV and recurrent compressor values without exporting tensors | Only counters are compared; the observed value divergence disappears |
| `ds4.h`: result structure and oracle API | Gives the external bounded harness a narrow opt-in interface | Reproducer would need invasive CLI or private-structure access |
| `ds4_gpu.h`: aggregate expert-cache statistics | Reports hits, misses, evictions and bytes without per-expert logging | Deduplication and I/O effects cannot be observed |
| `ds4_metal.m`: cache statistics snapshot | Exposes already maintained aggregate counters | Public API has no Metal implementation |
| `ds4_metal.m`: bounded cache release hook | Completes the existing declared cache-control contract used by diagnostics | Link/build or controlled cache state fails |

## Removed from the minimal patch

- Gate 2/3 expert paging and certification;
- Gate 3 activation tracing;
- Gate 4A routing trace, cache replay and prefetch;
- DSpark support-model loading changes from Gate 4B;
- CLI timing additions;
- general routing histograms;
- detailed per-stage streaming-expert timers;
- cleanup and laboratory management code;
- documentation unrelated to the reproducer.

The remaining timing fields mark scientific boundaries required to distinguish
batch verification from replay. The larger cumulative patch is retained only
for provenance and completeness.
