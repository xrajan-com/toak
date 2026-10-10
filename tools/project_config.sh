#!/usr/bin/env bash
# Reads one value from project.yaml, the single source of truth for names,
# IDs and addresses.
#
#   bash tools/project_config.sh backend.url        # prints the value
#   source tools/project_config.sh; project_value backend.url
#
# A key that is missing is an error. A key set to null prints nothing, so
# optional values (like backend.custom_domain) can be tested with -z.

project_value() {
  local key="$1" root section field out
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  section="${key%%.*}"
  field="${key#*.}"
  out="$(awk -v s="$section" -v f="$field" '
    /^[^[:space:]#][^:]*:/ { cur = $0; sub(/:.*/, "", cur); next }
    cur == s && index($0, f ":") > 0 && $0 ~ "^[[:space:]]+" f ":" {
      v = $0
      sub(/^[^:]*:[[:space:]]*/, "", v)
      sub(/[[:space:]]+#.*$/, "", v)
      sub(/[[:space:]]+$/, "", v)
      gsub(/^["'"'"']|["'"'"']$/, "", v)
      print "FOUND\t" v
      exit
    }' "$root/project.yaml")"
  if [[ "$out" != FOUND* ]]; then
    echo "ERROR: project.yaml has no key '$key'." >&2
    return 1
  fi
  out="${out#FOUND	}"
  if [[ "$out" == "null" || "$out" == "~" ]]; then
    out=""
  fi
  printf '%s\n' "$out"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  if [[ $# -ne 1 ]]; then
    echo "Usage: bash tools/project_config.sh <section.key>" >&2
    exit 2
  fi
  project_value "$1"
fi
