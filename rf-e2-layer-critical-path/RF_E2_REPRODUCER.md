# RF-E2 — Bounded reproduction guidance

## Purpose

This document describes the environment and measurement contract used for the
RF-E2 aggregate results. It does not provide or redistribute the model and it
does not implement GPU-driven I/O.

## Exact revisions

- DS4 upstream:
  `54b36ed9ba42da31b24f2d1a5feb075c2475dbb1`
- RF-E telemetry base:
  `cab90ed992c7427bbee4d9d7e0d5cbbe190185b0`
- RF-E2 layer telemetry:
  `3ae659316268b8429078bd455d2a9bac54779e14`

The RF-E2 commit is a local research-instrumentation revision recorded here for
traceability. The published bundle contains aggregate results, not the complete
private working tree.

## Tested environment

- Apple M4 Max;
- 36 GiB unified memory;
- Metal backend;
- DeepSeek V4 Flash q2-imatrix;
- model size: 86,720,111,488 bytes;
- model SHA-256:
  `efc7ed607ff27076e3e501fc3fefefa33c0ed8cf1eff483a2b7fdc0c2e616668`;
- instrumented binary SHA-256:
  `75dab09f2aa787538b03bf1f86706e34e82dd1f323938fecdd4adf724f3e357d`;
- context: 1,024;
- generated tokens: 128;
- greedy decoding, temperature 0;
- thinking, MTP, DSpark and speculation disabled;
- cache sizes: 256, 760 and 1,521 experts;
- two complete measured runs per cache size.

The model is not included.

## Instrumentation contract

Instrumentation was:

- opt-in and default-off;
- aggregate-only;
- bounded to per-layer counters, histograms and timing sums;
- designed not to modify routing, cache policy, eviction, prefetch, paging or
  Metal kernels;
- forbidden from saving prompts, generated text or token IDs.

Telemetry OFF and ON produced identical token-sequence SHA-256 digests. Median
instrumentation overhead in an OFF/ON/ON/OFF check was 0.3623%.

## Timing points

- `T0`: selected expert IDs available on the host;
- `T1`: cache lookup complete;
- `T2`: first required I/O starts;
- `T3`: all required expert cache slots ready;
- `T4`: MoE compute dispatch-ready after host bookkeeping and synchronization.

Derived intervals:

- `T0 -> T2`: host-side route-to-I/O-start path;
- `T2 -> T3`: synchronous read and slot-fill wall interval;
- `T3 -> T4`: post-ready dispatch preparation.

Because the tested path uses synchronous `pread`, submission and physical
service are not fully separable. The bundle therefore does not claim to expose
pure device service time.

## Reproduction outline

A researcher with an authorized local copy of the official model can reproduce
the measurement structure by:

1. checking out DS4 at the exact upstream commit;
2. applying equivalent opt-in aggregate instrumentation;
3. building the Metal backend;
4. verifying telemetry OFF/ON output equivalence;
5. running two 128-token greedy decodes for each cache size 256, 760 and 1,521;
6. collecting only aggregate per-layer counters and timing sums;
7. rejecting diagnostic runs made before timing boundaries are validated;
8. comparing all-hit rates, miss histograms and T0–T4 intervals.

The exact local prompt is intentionally not published. Its SHA-256 in the
private FARO protocol was:

`a3f3912de478e6f3c606b3feddd41c80ab4bbb268ceb8ad6f2461c13a2c66b50`

A reproducer should use one fixed, public synthetic prompt across all
configurations and publish only its hash if privacy boundaries require it.

## Required validation

A compatible reproduction should verify:

- exact DS4 base revision;
- model and binary hashes;
- cache sizes requested equal cache sizes effective;
- no MTP, DSpark or speculation;
- telemetry OFF/ON digest equality;
- telemetry overhead measured separately;
- `all_hit_calls + miss_bearing_calls == layer_calls`;
- miss histogram total equals layer calls;
- physical-load histogram semantics documented;
- no increasing swap during a run;
- normal memory pressure and no Metal/OOM errors;
- aggregate output remains bounded and sanitized.

## Expected qualitative result

The published run observed:

- host-side `T0 -> T2` near 0.61–0.68 ms per miss-bearing layer;
- physical-I/O/slot-fill `T2 -> T3` near 1.30–1.66 ms;
- very small `T3 -> T4`, near 0.007–0.022 ms;
- miss-bearing layer rate still 79.34% at 1,521 cache slots;
- wait increasing with miss count;
- GPU-originated I/O classified as promising but not proven.

Exact timing equality across systems is not expected. The structural
relationships and measurement definitions are the intended comparison points.
