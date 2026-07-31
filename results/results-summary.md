# FARO Gate 4C-2A aggregate results

## Structural result

For deterministic, target-generated oracle candidates:

| Check | Relation |
| --- | --- |
| DS4 base commit | MATCH |
| Oracle candidates | VALID |
| Frontier position | MATCH |
| Compressor counters | MATCH |
| Raw KV state | DIFFERENT |
| Attention compressor state | DIFFERENT |
| Index compressor state | DIFFERENT |
| Final logits after rollback and exact replay | EXACT MATCH |

The four diagnostic cases reported 41–43 raw-KV mismatch layers out of 43,
41 attention-compressor mismatch layers out of 41, and 21 index-compressor
mismatch layers out of 21. No tensor value or per-layer checksum is published.

The clean publication probe recorded 1,548 routed-expert selections across
the six candidate rows and 903 per-layer unique experts. This aggregate
confirms reuse within the layer-major block without revealing expert IDs.

## Block-size 6 timing

| Metric | P50 |
| --- | ---: |
| `T_core` | 145.308 ms |
| `T_verify` | 145.867 ms |
| `T_replay` | 269.311 ms |
| `T_safe_total` | 414.902 ms |
| warm oracle ceiling | about 41.13 candidate/s |
| theoretical budget at 30 token/s | about 54.13 ms |

> **Warm, oracle, draft-free lower-bound projection. Not end-to-end
> speculative decoding throughput.**

Thirty token/s was not achieved. The ceiling only shows that the warm target
verification measurement is below 200 ms for six candidates. A correct batch
state commit and a real draft would still have to fit in the remaining budget.

The CSV and JSON files in this directory contain aggregates only. Their schema
and interpretation are described in `docs/METHODOLOGY.md`.
