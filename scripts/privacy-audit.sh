#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
failed=0

echo "Privacy audit root: $ROOT"

if find "$ROOT" \( -path "$ROOT/.git" -o -path "$ROOT/artifacts" \) \
     -prune -o -type l -print | grep -q .; then
  echo "FAIL: symbolic links found"
  find "$ROOT" \( -path "$ROOT/.git" -o -path "$ROOT/artifacts" \) \
    -prune -o -type l -print
  failed=1
fi

if find "$ROOT" \( -path "$ROOT/.git" -o -path "$ROOT/artifacts" \) \
     -prune -o -type f -size +20M -print |
   grep -q .; then
  echo "FAIL: ordinary file exceeds 20 MiB"
  find "$ROOT" \( -path "$ROOT/.git" -o -path "$ROOT/artifacts" \) \
    -prune -o -type f -size +20M -print
  failed=1
fi

echo "Files larger than 5 MiB:"
find "$ROOT" \( -path "$ROOT/.git" -o -path "$ROOT/artifacts" \) \
  -prune -o -type f -size +5M -print

strict_pattern='/Users/|antoniocaristia|Developer/faro-lab|Authoriz''ation:[[:space:]]*Bear''er|api[_-]?key[[:space:]]*[:=]|pass(word|wd)[[:space:]]*[:=]|secret[[:space:]]*[:=]|credential[[:space:]]*[:=]|BEGIN PRIVATE KEY|github[_-]?token|X-Amz-(Credential|Signature)'
if rg --hidden -n -I \
     -g '!/.git/**' \
     -g '!/artifacts/**' \
     -g '!scripts/privacy-audit.sh' \
     "$strict_pattern" "$ROOT"; then
  echo "FAIL: sensitive or personal pattern found"
  failed=1
fi

email_pattern='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
if rg --hidden -n -I -g '!/.git/**' -g '!/artifacts/**' \
     "$email_pattern" "$ROOT"; then
  echo "FAIL: email address found"
  failed=1
fi

if find "$ROOT" \( -path "$ROOT/.git" -o -path "$ROOT/artifacts" \) \
     -prune -o -type f \
     \( -name '.DS_Store' -o -name '.env' -o -name '*.swp' -o \
        -name '*.swo' -o -name '*.part' -o -name 'core' -o \
        -name 'core.*' -o -name '*.gguf' -o -name '*.safetensors' -o \
        -name '*.f16' -o -name '*.f32' \) -print | grep -q .; then
  echo "FAIL: forbidden file type found"
  failed=1
fi

while IFS= read -r file_path; do
  kind="$(file -b "$file_path")"
  case "$kind" in
    *Mach-O*|*ELF*|*executable*)
      if [[ "$file_path" != *.sh ]]; then
        echo "FAIL: compiled binary found: $file_path ($kind)"
        failed=1
      fi
      ;;
  esac
done < <(find "$ROOT" \( -path "$ROOT/.git" -o -path "$ROOT/artifacts" \) \
  -prune -o -type f -print)

if [[ -f "$ROOT/.gitmodules" ]]; then
  echo "FAIL: unexpected submodule declaration"
  failed=1
fi

echo "Informational privacy vocabulary references:"
rg --hidden -n -I -g '!/.git/**' -g '!/artifacts/**' \
  'private-data|prompt|generated_output|token_id|session|cookie' \
  "$ROOT" || true

if (( failed != 0 )); then
  echo "Privacy audit: FAIL"
  exit 1
fi
echo "Privacy audit: PASS"
