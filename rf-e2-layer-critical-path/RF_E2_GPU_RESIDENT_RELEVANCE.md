# RF-E2 — Relevance to GPU-originated I/O and persistent kernels

## Summary

RF-E2 measured a real host-side target in DS4 Metal SSD streaming, but it did
not implement a GPU-originated queue or a persistent GPU kernel.

Across cache sizes 256, 760 and 1,521, the portion conservatively classified as
host-addressable was 16.84–18.96% of decode wall time. This is an upper bound on
time that a different submission architecture might reduce, bypass or overlap.
It is not a prediction of end-to-end speedup.

## What was measured

For each routed MoE layer, the telemetry marked:

- **T0:** selected expert IDs are available on the host;
- **T1:** cache lookup is complete;
- **T2:** the first required I/O starts;
- **T3:** all required expert cache slots are ready;
- **T4:** host bookkeeping and synchronization are complete and MoE compute is
  dispatch-ready.

For layers containing at least one miss:

| Interval | Meaning | Measured mean |
| --- | --- | ---: |
| `T0 -> T2` | expert IDs ready to first I/O start | 0.61–0.68 ms/layer |
| `T2 -> T3` | first I/O start to all slots ready | 1.30–1.66 ms/layer |
| `T3 -> T4` | all slots ready to compute dispatch-ready | 0.007–0.022 ms/layer |

The most interesting target is therefore before the first I/O starts. The final
post-ready dispatch phase is already very small.

## Meaning of host-addressable

Host-addressable time includes host-controlled work that a different design
might reduce or overlap:

- making or synchronizing expert IDs available to the host;
- cache lookup and slot selection;
- preparing read requests;
- delay before the first read begins;
- final address-table bookkeeping and synchronization.

It deliberately excludes the assumption that the physical SSD service itself
becomes faster. A persistent kernel cannot remove media latency merely by
moving submission logic to the GPU.

Measured host-addressable cost:

| Cache slots | Host-addressable ms/token | Fraction of decode |
| ---: | ---: | ---: |
| 256 | 26.222 | 18.96% |
| 760 | 26.534 | 18.63% |
| 1,521 | 23.320 | 16.84% |

## Why the cost repeats

Even with 1,521 slots, 79.34% of routed layers contained at least one miss.
With 43 routed layers, this is roughly 34 miss-bearing layers per generated
token. The approximately 0.6–0.7 ms before first I/O is therefore paid many
times per token.

Observed all-hit layer rates:

| Cache slots | All-hit layer rate | Miss-bearing layer rate |
| ---: | ---: | ---: |
| 256 | 0.019% | 99.981% |
| 760 | 2.539% | 97.461% |
| 1,521 | 20.659% | 79.341% |

## Miss count still matters

RF-E2 rejected a simple fixed single-miss-barrier model. Average wait increased
with the number of missing experts:

| Misses in layer | Average wait |
| ---: | ---: |
| 0 | 0.00 ms |
| 1 | 1.09 ms |
| 2 | 1.73 ms |
| 3 | 2.12 ms |
| 4 | 2.28 ms |
| 5 | 2.53 ms |
| 6 | 2.81 ms |

A GPU-originated queue can attack the host-side startup delay, but physical I/O
and the number of misses remain important.

## Current interpretation

The persistent-kernel / GPU-originated I/O direction is classified as
**PROMISING**, not proven.

The most plausible useful design is not merely a persistent polling kernel. It
is a combination of:

1. GPU-produced bounded request descriptors;
2. an always-ready submission service;
3. earlier overlap or prefetch;
4. potentially finer-grained paging later.

A real implementation may recover only part of the 16.84–18.96% upper bound and
may also consume GPU occupancy, increase coherence traffic or interfere with
model compute kernels.

## Recommended bounded spike

Compare:

- **A:** current DS4 host-driven path;
- **B:** persistent CPU proxy consuming a shared request ring;
- **C:** GPU-produced request descriptors with a minimal CPU I/O proxy;
- **D:** oracle early-submission upper bound.

Initial GO criteria:

- at least 50% reduction in `T0 -> T2`;
- at least 5% end-to-end throughput improvement;
- identical output digest;
- no unbounded memory growth;
- no meaningful GPU-compute regression.

These criteria are experimental FARO conventions, not universal thresholds.
