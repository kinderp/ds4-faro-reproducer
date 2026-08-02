# RF-E2 — Limitations and non-claims

## Evidence scope

RF-E2 is single-host E1 evidence:

- one Apple M4 Max system with 36 GiB unified memory;
- one model;
- one fixed prompt hash;
- one experimental session;
- two measured runs per cache size.

The results do not establish cross-Mac, cross-model, Linux/APU or discrete-GPU
generalization.

## Timing limitations

The tested expert-load path uses synchronous `pread`. The telemetry can measure
wall intervals around the read path, but it cannot fully separate:

- request submission;
- kernel scheduling;
- physical NVMe service;
- page-cache effects;
- slot-fill visibility.

`T0 -> T2` is a host-side route-to-first-I/O interval. `T2 -> T3` is a combined
I/O and slot-ready wall interval, not pure device latency.

Maximum individual read-tail latency was not available. The parallelized pool
exposes aggregate layer wall time rather than a complete latency distribution
for every physical read.

## Host-addressable fraction

The reported 16.84–18.96% host-addressable fraction is an upper bound on time
that a different architecture might reduce, bypass or overlap.

It is not:

- an expected speedup;
- proof that a persistent kernel can remove all of that time;
- proof that GPU-side polling is free;
- proof that host work and physical I/O never overlap;
- a guarantee that moving work to the GPU improves end-to-end throughput.

A persistent GPU kernel may consume GPU occupancy, create coherence traffic,
increase power use or interfere with model compute.

## Compute limitations

RF-E2 did not add intrusive GPU timers. GPU MoE compute time is therefore
`NOT_AVAILABLE`. The experiment cannot fully divide the remaining decode time
between:

- attention and non-routed compute;
- routed MoE compute;
- command-buffer work;
- synchronization not captured by the bounded timers;
- other runtime overhead.

## Cache and routing limitations

The experiment did not modify:

- routing;
- top-k selection;
- cache policy;
- eviction policy;
- cache size semantics;
- prefetch;
- paging;
- Metal kernels.

The physical-load histogram equaled the miss histogram in these runs and
`coalesced_waiters` was zero. Other workloads or runtimes may coalesce requests
differently.

## Statistical limitations

There were only two measured runs per cache size. Aggregate means, medians and
histograms are descriptive. They are not population confidence guarantees.

The three cache configurations are insufficient for strong causal correlation
claims between throughput and hit rate, all-hit rate, bytes or blocking wait.

## Privacy and publication limits

This bundle does not include:

- the model;
- prompts;
- generated text;
- token IDs;
- credentials;
- hostnames or serials;
- absolute local paths;
- complete KV state;
- raw per-token or per-request traces.

The published summary is aggregate and bounded.

## What RF-E2 does establish

Within the tested environment, RF-E2 establishes that:

- telemetry overhead was small and output equivalence passed;
- most routed layers still contained a miss even with 1,521 slots;
- wait increased with miss count;
- the host-side delay before first I/O was measurable and repeated per
  miss-bearing layer;
- post-ready dispatch was very small;
- a bounded GPU-driven I/O spike is justified.

## What RF-E2 does not establish

RF-E2 does not establish that:

- a persistent kernel will improve throughput;
- direct GPU submission is better than a persistent CPU proxy;
- GPU-originated I/O will recover the full host-addressable fraction;
- SSD service is the only bottleneck;
- fine-grained paging or prefetch is unnecessary;
- the reported timings apply to Linux, HSA, `io_uring`, hipFile or cuFile;
- production DS4 should adopt the research instrumentation.
