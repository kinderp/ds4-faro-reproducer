#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPRO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
RESULT="${1:-$REPRO_ROOT/artifacts/reproducer.json}"
EXPECTED="$REPRO_ROOT/fixtures/expected-structural-results.json"

python3 - "$RESULT" "$EXPECTED" <<'PY'
import json
import math
import pathlib
import sys

result = json.loads(pathlib.Path(sys.argv[1]).read_text())
expected = json.loads(pathlib.Path(sys.argv[2]).read_text())

assert result["base_commit"] == expected["ds4_base_commit"]
assert result["block_size"] == expected["block_size"]
for key, value in expected["relations"].items():
    assert result[key] == value, (key, result[key], value)

ranges = expected["allowed_mismatch_ranges"]
checks = {
    "raw_kv_mismatch_layers": "raw_kv_layers",
    "attention_state_mismatch_layers": "attention_compressor_layers",
    "index_state_mismatch_layers": "index_compressor_layers",
}
for result_key, range_key in checks.items():
    low, high = ranges[range_key]
    assert low <= result[result_key] <= high

for key in ("t_core_ms", "t_verify_ms", "t_verify_rollback_ms",
            "t_replay_ms", "t_safe_total_ms", "pread_ms"):
    assert math.isfinite(result[key]) and result[key] >= 0.0
assert result["footprint_bytes"] <= 24 * 1024**3
assert result["swap_used_bytes"] <= 3 * 1024**3
assert 0 < result["unique_experts"] < result["expert_requests"]
print("Structural verification: PASS")
PY
