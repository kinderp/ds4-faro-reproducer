# Environment

## Reference machine

| Item | Value |
| --- | --- |
| hardware | MacBook Pro Mac16,5 |
| SoC | Apple M4 Max |
| CPU | 14 cores |
| GPU | 32 cores |
| unified memory | 36 GiB |
| compiler | Apple clang 17 |
| backend | Metal |
| target placement | SSD streaming |
| context | 1,024 |
| expert-cache budget | 1,521 experts |
| DS4 commit | `54b36ed9ba42da31b24f2d1a5feb075c2475dbb1` |

The measured run used a warm cache. It did not use `purge`, a cold-cache
substitute, DSpark, MTP, GLM, a server or a second model process.

## Safety bounds

The harness:

- uses a single target process;
- stops after one warm-up and one block-size-6 measurement;
- refuses an unexpected DS4 commit;
- limits the accepted model to a regular local file;
- stops if process RSS exceeds 24 GiB;
- stops if swap exceeds 3 GiB;
- stops after 120 seconds without output progress;
- never writes to or modifies the GGUF.

The published aggregate run reported zero swap.
