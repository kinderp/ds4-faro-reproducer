# DS4 upstream watch — 2026-08-24

This note records a desk audit of DS4 upstream after the bounded FARO work.
It does **not** claim a fresh model/runtime reproduction on local hardware.

## Reference points

- FARO historical baseline: `54b36ed9ba42da31b24f2d1a5feb075c2475dbb1`.
- DS4 upstream head inspected: `c1d4597a80e300b803dc642519718f2c999589da` (2026-08-23).
- GitHub compare reports upstream `137` commits ahead of the FARO baseline and
  `0` behind.

## 1. Metal SSD streaming + DSpark

### Historical FARO observation

At `54b36ed...`, documentation described a Metal target using
`--ssd-streaming` with DSpark, while the runtime rejected `--mtp` together
with SSD streaming. Since DSpark receives the support GGUF through `--mtp`,
that documented combination did not start.

### Current upstream status

**Resolved / obsolete as a current incompatibility.**

Current DS4 documentation explicitly states that, on Metal, the main model may
be resident **or use `--ssd-streaming`** while the DSpark support model adds its
own weights/runtime state. The same section documents `--mtp <support.gguf>
--dspark` as the normal invocation.

Reference:
<https://github.com/antirez/ds4/blob/c1d4597a80e300b803dc642519718f2c999589da/README.md#dspark-speculative-decoding>

The old FARO result therefore remains useful as a historical baseline, but it
must not be presented as a current upstream limitation.

## 2. Batched verifier state vs one-token decode

### Historical FARO observation

The bounded FARO oracle found that a causal multi-row verification path could
match logical frontier/counter structure while raw KV and recurrent compressor
state differed numerically from sequential one-token decode. Rollback plus
ordinary autoregressive replay restored the authoritative final logits.

### Upstream confirmation: issue #658

Upstream issue #658 independently describes the same numerical class:
batched target verification and single-token decode can derive numerically
different compressor/KV state because their floating-point reductions use
different operation ordering. The drift can accumulate until a later greedy
argmax differs.

Reference:
<https://github.com/antirez/ds4/issues/658>

This materially strengthens the interpretation of the FARO measurements: the
raw-state mismatch was not merely an artifact of the bounded harness.

## 3. Upstream policy changed twice

The important sequence is:

1. `af80694e95a9fa0d7c74333b25fe285420801747` — **Restore greedy identity
   after DSpark acceptance**. Upstream moved accepted tokens back through the
   ordinary one-token path so verifier-batch compressor state would not become
   authoritative.
2. `7fb28303df65f9eb2f22de7d5d9b6ccbda504eb5` — **Replay partial DSpark accepts
   through ordinary decode**. Empirical discussion on #658 reports that this
   second step is the point at which the tested Metal runs matched the plain
   greedy stream.
3. `0e89a0eeffc90701fbea1f44a96492bcbb936122` (2026-08-07) — **dspark: commit
   accepted verifier state directly**. Upstream deliberately changed the
   contract: normal DSpark keeps accepted batched-verifier state; byte identity
   with one-token decode is no longer required. `--dspark-strict` is the
   target-only reproducibility control.
4. `42033ee3f45678b71c82c6ac11e9cd9ffe3d4f59` (2026-08-09) — **metal: pipeline
   DFlash verification**. The commit explicitly tunes Metal around direct
   verifier-state commits.

References:
- <https://github.com/antirez/ds4/issues/658>
- <https://github.com/antirez/ds4/pull/659>
- <https://github.com/antirez/ds4/commit/0e89a0eeffc90701fbea1f44a96492bcbb936122>
- <https://github.com/antirez/ds4/commit/42033ee3f45678b71c82c6ac11e9cd9ffe3d4f59>

## 4. Meaning for this repository

The FARO repository should now be classified as:

- **historical reproducer** for the `54b36ed...` documentation/runtime gap;
- **numerical oracle/regression lab** for batch-vs-sequential state identity;
- **research evidence** for the trade-off between direct verifier-state commit
  and strict one-token numerical identity;
- **not** a claim that current DS4 has an unacknowledged SSD+DSpark startup bug;
- **not** a claim that current normal DSpark promises byte-identical output to
  one-token decode.

The strongest still-current FARO contribution is the state-level methodology:
compare semantic structure, raw KV, recurrent compressor state, rollback, and
replay separately instead of reducing correctness to final-text equality.

## 5. Proposed next runtime matrix

A new current-head run should be kept separate from the historical artifact.
Pin `c1d4597...` (or the exact newer head selected at execution time) and record
that SHA before running.

| Target placement | DSpark mode | Expected contract | Primary check |
| --- | --- | --- | --- |
| resident | normal | direct verifier-state commits allowed | valid output, acceptance, state-diff telemetry |
| resident | `--dspark-strict` | target-only reproducibility control | byte identity with ordinary decode |
| Metal SSD | normal | supported; direct verifier-state commits allowed | startup + verifier correctness + SSD behavior |
| Metal SSD | `--dspark-strict` | target-only control | startup + byte identity baseline |

For normal DSpark, a text mismatch with ordinary decode is now diagnostic, not
by itself a failure. Failures remain verifier errors, invalid state/text,
incorrect accepted-prefix semantics, rollback corruption, or material quality
regression.

## Watch conclusion

**Status on 2026-08-24:** the two original FARO pressure points have both moved
upstream. SSD+DSpark is now an advertised supported Metal configuration, while
the batch-vs-sequential numerical difference is explicitly acknowledged and
incorporated into DS4's current execution contract. The FARO evidence should
be preserved, but future work should pivot from “prove the old incompatibility”
to “measure and guard the current direct-commit vs strict-mode contracts.”
