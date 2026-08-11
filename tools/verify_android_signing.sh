#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
properties_file="$repo_root/android/key.properties"

fail() {
  echo "ERROR: $1" >&2
  exit 1
}

[[ -f "$properties_file" ]] || fail \
  "android/key.properties is required for a distributable Android bundle."

property_value() {
  local key="$1"
  awk -F= -v wanted="$key" '
    $1 == wanted {
      sub(/^[^=]*=/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      print
      exit
    }
  ' "$properties_file"
}

key_alias="$(property_value keyAlias)"
key_password="$(property_value keyPassword)"
store_file="$(property_value storeFile)"
store_password="$(property_value storePassword)"

[[ -n "$key_alias" ]] || fail "keyAlias is missing from android/key.properties."
[[ -n "$key_password" ]] || fail "keyPassword is missing from android/key.properties."
[[ -n "$store_file" ]] || fail "storeFile is missing from android/key.properties."
[[ -n "$store_password" ]] || fail "storePassword is missing from android/key.properties."

if [[ "$store_file" = /* ]]; then
  keystore_path="$store_file"
else
  keystore_path="$repo_root/android/app/$store_file"
fi
[[ -f "$keystore_path" ]] || fail "The configured Android upload keystore does not exist."

file_mode() {
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
}

for sensitive_file in "$properties_file" "$keystore_path"; do
  mode="$(file_mode "$sensitive_file")"
  permissions=$((8#$mode))
  if (( (permissions & 8#077) != 0 )); then
    fail "$(basename "$sensitive_file") must not be readable or writable by group/others (use chmod 600)."
  fi
done

command -v keytool >/dev/null 2>&1 || fail "keytool is required to validate Android signing."
keytool -list \
  -keystore "$keystore_path" \
  -storepass "$store_password" \
  -alias "$key_alias" \
  >/dev/null 2>&1 || fail "The configured Android upload key could not be validated."

echo "Android release signing preflight passed."
