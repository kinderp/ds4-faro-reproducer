#!/usr/bin/env bash
set -euo pipefail

BASE_COMMIT="54b36ed9ba42da31b24f2d1a5feb075c2475dbb1"
MODEL_SHA256="efc7ed607ff27076e3e501fc3fefefa33c0ed8cf1eff483a2b7fdc0c2e616668"
DS4_ROOT="${1:-}"

if [[ -z "$DS4_ROOT" || ! -d "$DS4_ROOT" ]] ||
   ! git -C "$DS4_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "usage: $0 /path/to/clean/ds4" >&2
  exit 2
fi
if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "environment check failed: macOS arm64 is required" >&2
  exit 1
fi
for tool in git make cc python3 shasum stat df; do
  command -v "$tool" >/dev/null ||
    { echo "environment check failed: missing $tool" >&2; exit 1; }
done

head_sha="$(git -C "$DS4_ROOT" rev-parse HEAD)"
if [[ "$head_sha" != "$BASE_COMMIT" ]]; then
  echo "environment check failed: DS4 commit is $head_sha, expected $BASE_COMMIT" >&2
  exit 1
fi

if [[ -z "${DS4_MODEL:-}" || ! -f "$DS4_MODEL" || -L "$DS4_MODEL" ]]; then
  echo "environment check failed: DS4_MODEL must name a regular official GGUF" >&2
  exit 1
fi
model_bytes="$(stat -f '%z' "$DS4_MODEL")"
if (( model_bytes < 80 * 1024 * 1024 * 1024 )); then
  echo "environment check failed: model is smaller than the expected q2-imatrix target" >&2
  exit 1
fi

free_kib="$(df -k / | awk 'NR==2 {print $4}')"
if (( free_kib < 10 * 1024 * 1024 )); then
  echo "environment check failed: less than 10 GiB free" >&2
  exit 1
fi

if [[ "${FARO_FULL_MODEL_HASH:-0}" == "1" ]]; then
  actual="$(shasum -a 256 "$DS4_MODEL" | awk '{print $1}')"
  if [[ "$actual" != "$MODEL_SHA256" ]]; then
    echo "environment check failed: model SHA-256 mismatch" >&2
    exit 1
  fi
fi

echo "DS4 base commit: MATCH"
echo "Platform: macOS arm64"
echo "Model: regular local file, not copied"
echo "Environment: PASS"
