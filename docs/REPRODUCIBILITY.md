# Reproducibility protocol

## Clean-start requirement

The patch application script requires:

1. a Git checkout at the exact DS4 commit;
2. no tracked modifications;
3. a successful `git apply --check`;
4. a successful `git diff --check`.

It refuses a different commit rather than attempting a fuzzy application.

## Bounded run

The public run performs one unmeasured warm-up and one measured block-size-6
oracle verification. It emits only structural status and aggregate metrics.
The target model is referenced by `DS4_MODEL`; it is never copied.

## Verification

`verify-results.sh` checks:

- exact base commit;
- block size;
- required MATCH/DIFFERENT relations;
- positive bounded mismatch counts;
- positive expert reuse (`unique_experts < expert_requests`);
- finite non-negative timing values;
- footprint at most 24 GiB;
- swap at most 3 GiB.

Digest values may differ on another toolchain. The relation must not.

## Expected limitations

Physical SSD state, cache warmth, compiler revision and Metal scheduling affect
timings. A structural PASS is more portable than matching the published
milliseconds. Timing comparison should use several replicas on one fixed
environment.

## Clean local qualification

The publication candidate was applied to a detached clean worktree at the
exact base commit. The minimal patch changed four DS4 files, compiled, and ran
to completion using the existing official target. The bounded probe reported
1,548 expert selections and 903 per-layer unique experts, reproduced all
required state relations, used no swap, and ended with exact replay-safe final
logits. A second clean worktree accepted and compiled the cumulative patch
independently.
