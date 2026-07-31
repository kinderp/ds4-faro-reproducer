# Scientific limitations

## What is measured

- one Apple M4 Max system;
- one q2-imatrix target;
- fixed context and expert-cache budget;
- warm SSD-streaming state;
- target-generated greedy oracle candidates;
- blocks up to eight in the aggregate data;
- exact rollback and autoregressive replay.

## What is inferred

Different state digests with matching positions and counters localise the
problem to numeric or semantic differences between the multi-row prefill-like
path and single-token decode. FP8 rounding, ratio-4 compression and operation
order are plausible contributors, not proven single causes.

## What is not demonstrated

- universal divergence on every hardware/toolchain combination;
- an upstream defect;
- a correct direct batch-state commit;
- a real draft model or acceptance distribution;
- end-to-end speculative speedup;
- 30 token/s.

The roughly 41.13 candidate/s value is a warm, oracle, draft-free
lower-bound projection. It is not generation throughput. The future 54.13 ms
budget would have to include a correct state commit, a draft, scheduling and
any I/O not already hidden.
