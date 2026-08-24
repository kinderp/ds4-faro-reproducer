# Upstream audit

> Historical baseline audit: this file describes DS4 at
> `54b36ed9ba42da31b24f2d1a5feb075c2475dbb1`. It is intentionally preserved
> as evidence of the state observed at that revision. For the current upstream
> status as of 2026-08-24, see [`UPSTREAM_WATCH_2026-08-24.md`](UPSTREAM_WATCH_2026-08-24.md).

The FARO base and fetched DS4 `origin/main` were both:

```text
54b36ed9ba42da31b24f2d1a5feb075c2475dbb1
```

The commit distance was zero.

## Documentation/code discrepancy

At this revision, the README says that on Metal the Flash target may be
resident or use `--ssd-streaming` with DSpark. The runtime checks for a
support-model path and rejects it when SSD streaming is active:

```text
ds4: --ssd-streaming is not compatible with --mtp yet
```

Because DSpark receives its support GGUF through `--mtp`, the documented
combination does not start. A bounded verify-depth invocation reproduced the
rejection before inference.

## Verifier state

The upstream target batch verifier is layer-major but has no branch that maps
non-resident routed-expert spans or services SSD misses. Upstream tests check
accepted chunks and target argmax proximity and test individual compressor
primitives, but no identified test compares the complete raw KV and recurrent
compressor state against sequential single-token decode.

This is an audit observation, not a declaration of an upstream bug. An
undocumented invariant or intended future path may exist.
