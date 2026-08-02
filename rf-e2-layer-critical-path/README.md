# RF-E2 Layer Critical Path collaboration bundle

This directory publishes a bounded, sanitized summary of FARO Gate RF-E2.
The experiment measured the per-layer host-driven critical path of DS4 Metal
SSD streaming before attempting any GPU-originated I/O or persistent-kernel
implementation.

## Main result

For routed MoE layers containing at least one cache miss, the measured path was:

| Interval | Meaning | Measured mean |
| --- | --- | ---: |
| `T0 -> T2` | selected expert IDs available on the host to first required I/O start | 0.61–0.68 ms/layer |
| `T2 -> T3` | first I/O start to all required cache slots ready | 1.30–1.66 ms/layer |
| `T3 -> T4` | all slots ready to MoE compute dispatch-ready | 0.007–0.022 ms/layer |

The host-addressable portion was 16.84–18.96% of decode wall time across the
tested cache sizes. This is an upper bound on time that a different submission
architecture might reduce or overlap; it is not an expected speedup.

The experiment therefore classifies a GPU-originated request queue or persistent
GPU kernel as **PROMISING**, while also showing that physical I/O remains a
substantial part of the critical path.

## Files

- [`RF_E2_LAYER_SUMMARY.json`](RF_E2_LAYER_SUMMARY.json): canonical aggregate
  results and classifications.
- [`RF_E2_GPU_RESIDENT_RELEVANCE.md`](RF_E2_GPU_RESIDENT_RELEVANCE.md):
  interpretation for GPU-originated I/O and persistent-kernel work.
- [`RF_E2_REPRODUCER.md`](RF_E2_REPRODUCER.md): environment, instrumentation
  contract and bounded reproduction guidance.
- [`RF_E2_LIMITATIONS.md`](RF_E2_LIMITATIONS.md): explicit limits and claims
  that this bundle does not make.

## Tested environment

- Apple M4 Max, 36 GiB unified memory;
- DS4 upstream commit
  `54b36ed9ba42da31b24f2d1a5feb075c2475dbb1`;
- RF-E telemetry base
  `cab90ed992c7427bbee4d9d7e0d5cbbe190185b0`;
- RF-E2 telemetry commit
  `3ae659316268b8429078bd455d2a9bac54779e14`;
- DeepSeek V4 Flash q2-imatrix, 86,720,111,488 bytes;
- context 1,024; 128 generated tokens; greedy decoding; temperature 0;
- thinking, MTP, DSpark and speculative decoding disabled;
- cache sizes 256, 760 and 1,521 experts;
- two complete measured runs per cache size.

The model is not included.

## Privacy and scope

This bundle contains aggregate timings, counts and hashes only. It does not
contain prompts, generated text, token IDs, credentials, hostnames, serials,
absolute local paths, full KV state or model files.

The telemetry was opt-in, default-off and aggregate-only. Telemetry OFF/ON
produced identical token-sequence SHA-256 digests, and median instrumentation
overhead was 0.3623%.
