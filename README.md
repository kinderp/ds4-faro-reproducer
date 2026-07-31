# FARO DS4 Gate 4C-2A reproducer

This is a bounded research reproducer for DS4 Metal SSD streaming. It is not a
production patch, a model distribution, or a claim that speculative decoding
currently reaches 30 token/s.

## Objective

The repository lets a reviewer inspect and reproduce six observations:

1. DS4 documentation at the tested revision says DSpark may use Metal
   `--ssd-streaming`, while the runtime rejects a support model in that mode;
2. a small FARO adapter can run the existing layer-major target verifier with
   bounded SSD expert loading;
3. selected experts are reused across candidate rows instead of being loaded
   once per row;
4. the causal multi-row path advances the right frontier and compressor
   counters but produces different raw KV and compressor values from
   single-token decode;
5. rollback followed by exact autoregressive replay restores authoritative
   final logits;
6. Gate 4C-2A timing boundaries separate batch verification from replay.

## Exact DS4 revision

```text
54b36ed9ba42da31b24f2d1a5feb075c2475dbb1
```

At preparation time this was also the fetched `origin/main`.

## Tested environment

- MacBook Pro `Mac16,5`;
- Apple M4 Max;
- 14 CPU cores and 32 GPU cores;
- 36 GiB unified memory;
- macOS arm64 and Apple clang 17;
- Metal with explicit DS4 SSD streaming;
- context 1,024 for the reproducer;
- routed-expert cache budget: 1,521 experts;
- warm-cache bounded run; no cache purge.

Official target used:

```text
DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf
SHA-256: efc7ed607ff27076e3e501fc3fefefa33c0ed8cf1eff483a2b7fdc0c2e616668
```

The model is not included.

## Start here

> **Start with `patches/faro-minimal-reproducer.patch`. The cumulative patch
> is provided only for research completeness.**

The cumulative research patch is provided for completeness. It contains
instrumentation and experimental work unrelated to the minimal reproducer and
is not the recommended starting point for review.

## Requirements

- macOS on Apple Silicon;
- Xcode Command Line Tools and Metal;
- Git, Make, a C compiler and Python 3;
- an official local copy of the q2-imatrix target above;
- at least 24 GiB process-memory allowance and 10 GiB free storage;
- DS4 source checked out at the exact revision.

No support model is needed for the oracle reproducer.

## Commands

```bash
git clone https://github.com/antirez/ds4.git ds4-clean
git -C ds4-clean checkout 54b36ed9ba42da31b24f2d1a5feb075c2475dbb1

export DS4_MODEL=/absolute/path/to/the/official/q2-imatrix.gguf

./scripts/check-environment.sh ./ds4-clean
./scripts/apply-minimal-patch.sh ./ds4-clean
./scripts/build.sh ./ds4-clean
./scripts/run-reproducer.sh ./ds4-clean
./scripts/verify-results.sh
```

Set `FARO_FULL_MODEL_HASH=1` for the environment check to recompute the full
model SHA-256. The default avoids rereading 86.7 GB on every bounded run.

## Expected structural result

```text
DS4 base commit: MATCH
Oracle candidates: VALID
Frontier position: MATCH
Compressor counters: MATCH
Raw KV state: DIFFERENT
Attention compressor state: DIFFERENT
Index compressor state: DIFFERENT
Replay-safe final logits: EXACT MATCH
```

`MATCH` means the compared relation is equal under the stated check.
`DIFFERENT` means at least one relevant per-layer digest differs; it does not
publish tensor values. Exact digest numbers are not required to match across
machines.

## Timing result

For block size 6 on the tested machine:

| Measurement | P50 |
| --- | ---: |
| `T_core` | 145.308 ms |
| `T_verify` | 145.867 ms |
| `T_replay` | 269.311 ms |
| `T_safe_total` | 414.902 ms |
| warm oracle ceiling | about 41.13 candidate/s |
| theoretical 30 token/s budget | about 54.13 ms |

This is a **warm, oracle, draft-free lower-bound projection. Not end-to-end
speculative decoding throughput.** Thirty token/s was not obtained.

## Minimal and cumulative patches

- `faro-minimal-reproducer.patch` contains only the oracle API, SSD-aware
  layer-major verifier branch, bounded expert-cache statistics, state digests,
  rollback/replay correctness path and essential timing boundaries.
- `faro-gates4b-4c2a-cumulative.patch` preserves the accumulated research
  instrumentation from Gates 4B through 4C-2A. It is intentionally larger and
  is not the review starting point.

See `docs/MINIMAL_PATCH_SCOPE.md`.

## Privacy and exclusions

No GGUF, private trace, complete KV dump, generated answer, token identifier,
shell history, credential or local absolute path is included. The fixed inputs
under `fixtures/` are synthetic and public. Run:

```bash
./scripts/privacy-audit.sh
```

See `docs/PRIVACY_AND_EXCLUSIONS.md`.

## What this does not establish

- It does not prove that DS4 has an upstream bug.
- It does not prove bit-identical behavior on every GPU or compiler.
- It does not implement a correct no-replay state commit.
- It does not benchmark a draft model.
- It does not demonstrate 30 token/s.

## Reporting a reproducer problem

When this repository is public, report a minimal problem against this
repository and include the DS4 commit, hardware class, script exit status and
sanitized structural result. Do not attach model files, generated text, token
identifiers or full state dumps.
