# Privacy and exclusions

The repository is designed to contain only source, patches, synthetic inputs,
aggregate measurements and sanitised logs.

The following are excluded from the public bundle because they are unnecessary
for reproduction, privately derived, very large, or already officially
available:

| Excluded material | Reason |
| --- | --- |
| target GGUF, about 81 GiB | Very large, officially available and governed by its upstream terms |
| DSpark support GGUF, about 5.58 GiB | Not required by this oracle test; officially available and separately licensed |
| private input and generated text | Unnecessary for the fixed synthetic reproducer and potentially identifying |
| token identifiers | Unnecessary and capable of reconstructing content |
| complete KV/compressor dumps | Large, derived and unnecessary; mismatch counts are sufficient |
| complete FARO repository | Contains unrelated research and local operational material |
| unsanitised patches and logs | Harder to review and may contain unrelated instrumentation |
| shell history and editor metadata | Unrelated and potentially sensitive |

`fixtures/synthetic-prompts.json` contains four short, deliberately authored
test strings. It contains no user conversation, private source code or model
output.

The automated audit rejects personal home paths, credentials, private keys,
signed URL material, email addresses, model files, binary objects, temporary
parts, editor swap files, core dumps, symbolic links and files over 20 MiB.
Vocabulary such as “prompt” or “token identifier” is expected in explanatory
documentation and does not imply that such private data is included.
