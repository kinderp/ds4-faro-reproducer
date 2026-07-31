#!/usr/bin/env bash
set -euo pipefail

BASE_COMMIT="54b36ed9ba42da31b24f2d1a5feb075c2475dbb1"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPRO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
PATCH="$REPRO_ROOT/patches/faro-minimal-reproducer.patch"
DS4_ROOT="${1:-}"

if [[ -z "$DS4_ROOT" || ! -d "$DS4_ROOT" ]] ||
   ! git -C "$DS4_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "usage: $0 /path/to/clean/ds4" >&2
  exit 2
fi
if [[ "$(git -C "$DS4_ROOT" rev-parse HEAD)" != "$BASE_COMMIT" ]]; then
  echo "refusing: DS4 is not at the required base commit" >&2
  exit 1
fi
if [[ -n "$(git -C "$DS4_ROOT" status --porcelain --untracked-files=no)" ]]; then
  echo "refusing: DS4 tracked working tree is not clean" >&2
  exit 1
fi

git -C "$DS4_ROOT" apply --check "$PATCH"
git -C "$DS4_ROOT" apply "$PATCH"
git -C "$DS4_ROOT" diff --check
echo "Minimal patch: APPLIED"
