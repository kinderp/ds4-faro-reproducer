# Methodology

## Isolation of draft quality

The target first performs deterministic greedy decode and obtains six future
tokens. These target-produced tokens are used as oracle candidates. Draft
quality, confidence thresholds and support-model cost are therefore absent
from the experiment.

## Verification path

After saving the frontier, the harness restores the same start state and asks
the target to process the candidate block through a causal, layer-major batch:

1. route every candidate row;
2. collect selected experts per layer;
3. use the existing bounded expert cache;
4. load an expert miss once and reuse it for all selecting rows;
5. run routed and non-routed Metal work;
6. produce batch output-head rows;
7. compare the accepted prefix;
8. compare state metadata and per-layer state digests;
9. roll back;
10. replay the six oracle tokens through authoritative single-token decode.

The digest is FNV-1a over selected state regions read back outside the timed
sample. Only mismatch counts are emitted.

## Timing definitions

- `T_core`: target batch upload, layers and output head required for logits;
- `T_verify`: snapshot, preparation, `T_core`, acceptance comparison and
  metadata checks, excluding deep digest diagnostics;
- `T_verify_rollback`: `T_verify` plus restoration of the saved frontier;
- `T_replay`: exact six-step autoregressive replay;
- `T_safe_total`: the currently authoritative verify, rollback, replay and
  final-commit path.

The detailed CSV/JSON values are aggregates of four synthetic categories and
five measured replicas per block size. P50 is the median; P95 describes the
upper tail. `T_core` is a lower-bound component, not achieved decode speed.

## Data schemas

- `timing-summary.csv`: one row per block size with P50/P95 timings and
  projected no-replay ceilings;
- `timing-summary.json`: equivalent aggregates plus category distributions;
- `component-percentages.csv`: median component shares;
- `draft-budget.csv`: time remaining after `T_verify` for target throughputs;
- `state-checksums.csv`: structural relations and mismatch-layer counts only.

No row contains source text, generated text, token identifiers, tensor values
or per-layer digests.
