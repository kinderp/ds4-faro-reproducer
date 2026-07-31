# Publication checklist

Status after local verification and before private-remote verification:

| Gate | Status | Evidence |
| --- | --- | --- |
| minimal patch | PASS | applies alone to the exact base; 4 files, +885/-2 |
| cumulative patch | PASS | applies to the exact base; 6 files, +2,235/-29 |
| compilation | PASS | minimal and cumulative worktrees build with two pre-existing warnings |
| clean bounded run | PASS | all required structural relations reproduced |
| privacy | PASS | automated scan plus manual review; informational vocabulary only |
| license | PASS | DS4 MIT notice preserved |
| file size | PASS | no ordinary file exceeds 5 MiB; 20 MiB hard limit |
| checksums | PASS | SHA-256 manifest generated after local final content |
| documentation | PASS | README and seven focused technical documents reviewed |
| aggregate results | PASS | all JSON parsed; all CSV rows are rectangular |
| fresh Git history | PENDING | repository not initialised yet |
| no model | PASS | no GGUF, support model, weight file or model symlink |
| no private data | PASS | no private trace, prompt/output capture, token IDs or state dumps |
| private GitHub clone audit | PENDING | remote not created yet |

The repository must remain private until the exact phrase
`PUBBLICA REPRODUCER` is received.
