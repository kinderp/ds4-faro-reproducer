#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPRO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
DS4_ROOT="${1:-}"
OUT_DIR="${FARO_BUILD_DIR:-$REPRO_ROOT/artifacts/bin}"

if [[ -z "$DS4_ROOT" || ! -d "$DS4_ROOT" ]] ||
   ! git -C "$DS4_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "usage: $0 /path/to/patched/ds4" >&2
  exit 2
fi
if ! git -C "$DS4_ROOT" apply --reverse --check \
    "$REPRO_ROOT/patches/faro-minimal-reproducer.patch" >/dev/null 2>&1; then
  echo "build refused: minimal patch is not applied exactly" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
make -C "$DS4_ROOT" -j4 ds4
cc -O3 -ffast-math -g -mcpu=native -Wall -Wextra -std=c99 \
  -I"$DS4_ROOT" \
  -o "$OUT_DIR/faro_oracle_reproducer" \
  "$SCRIPT_DIR/faro_oracle_reproducer.c" \
  "$DS4_ROOT/ds4.o" \
  "$DS4_ROOT/ds4_distributed.o" \
  "$DS4_ROOT/ds4_tp.o" \
  "$DS4_ROOT/ds4_ssd.o" \
  "$DS4_ROOT/ds4_metal.o" \
  "$DS4_ROOT/ds4_layer_pack.o" \
  -lm -pthread -framework Foundation -framework Metal

echo "Build: PASS"
shasum -a 256 "$OUT_DIR/faro_oracle_reproducer"
