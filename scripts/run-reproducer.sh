#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPRO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
DS4_ROOT="${1:-}"
OUT_DIR="${FARO_OUTPUT_DIR:-$REPRO_ROOT/artifacts}"
BUILD_DIR="${FARO_BUILD_DIR:-$REPRO_ROOT/artifacts/bin}"
BIN="$BUILD_DIR/faro_oracle_reproducer"

"$SCRIPT_DIR/check-environment.sh" "$DS4_ROOT"
if [[ ! -x "$BIN" ]]; then
  "$SCRIPT_DIR/build.sh" "$DS4_ROOT"
fi

mkdir -p "$OUT_DIR"
raw_log="$(mktemp "$OUT_DIR/.runtime.XXXXXX")"
cleanup_raw() {
  rm -f -- "$raw_log"
}
trap cleanup_raw EXIT INT TERM

# DS4 resolves its Metal source paths relative to the repository root.
cd "$DS4_ROOT"
FARO_GATE4C1_ORACLE_VERIFIER=1 "$BIN" "$DS4_MODEL" >"$raw_log" 2>&1 &
run_pid=$!
last_size=0
last_progress="$(date +%s)"

while kill -0 "$run_pid" 2>/dev/null; do
  sleep 5
  current_size="$(stat -f '%z' "$raw_log" 2>/dev/null || printf '0')"
  now="$(date +%s)"
  if [[ "$current_size" != "$last_size" ]]; then
    last_size="$current_size"
    last_progress="$now"
  elif (( now - last_progress >= 120 )); then
    echo "reproducer stopped: no progress for 120 seconds" >&2
    kill -TERM "$run_pid" 2>/dev/null || true
    wait "$run_pid" || true
    exit 1
  fi

  rss_kib="$(ps -o rss= -p "$run_pid" 2>/dev/null | tr -d ' ' || printf '0')"
  if [[ -n "$rss_kib" ]] && (( rss_kib > 24 * 1024 * 1024 )); then
    echo "reproducer stopped: process RSS exceeded 24 GiB" >&2
    kill -TERM "$run_pid" 2>/dev/null || true
    wait "$run_pid" || true
    exit 1
  fi

  swap_mib="$(sysctl vm.swapusage 2>/dev/null |
    awk '{for(i=1;i<=NF;i++) if($i=="used") {v=$(i+2); gsub("M","",v); print int(v)}}')"
  if [[ -n "$swap_mib" ]] && (( swap_mib > 3072 )); then
    echo "reproducer stopped: swap exceeded 3 GiB" >&2
    kill -TERM "$run_pid" 2>/dev/null || true
    wait "$run_pid" || true
    exit 1
  fi
done

set +e
wait "$run_pid"
run_rc=$?
set -e

python3 - "$raw_log" "$OUT_DIR" "$DS4_MODEL" <<'PY'
import json
import pathlib
import re
import sys

raw_path = pathlib.Path(sys.argv[1])
out_dir = pathlib.Path(sys.argv[2])
model_path = sys.argv[3]
text = raw_path.read_text(errors="replace")
text = text.replace(model_path, "<official-model.gguf>")
text = re.sub(r"/" + "Users/" + r"[^/\s]+", "<home>", text)
text = re.sub(r"/home/[^/\s]+", "<home>", text)

allowed = []
result = None
for line in text.splitlines():
    if line.startswith("FARO_RESULT_JSON="):
        result = json.loads(line.split("=", 1)[1])
        allowed.append(line)
    elif line.startswith((
        "DS4 base commit:", "Oracle candidates:", "Frontier position:",
        "Compressor counters:", "Raw KV state:",
        "Attention compressor state:", "Index compressor state:",
        "Replay-safe final logits:", "ds4: Metal device",
        "ds4: SSD streaming expert cache", "faro-reproducer:"
    )):
        allowed.append(line)

(out_dir / "sanitized-runtime.log").write_text(
    "\n".join(allowed) + "\n", encoding="utf-8")
if result is not None:
    (out_dir / "reproducer.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8")
PY

if (( run_rc != 0 )); then
  echo "reproducer: FAIL (see sanitized runtime log)" >&2
  exit "$run_rc"
fi
"$SCRIPT_DIR/verify-results.sh" "$OUT_DIR/reproducer.json"
echo "Reproducer: PASS"
