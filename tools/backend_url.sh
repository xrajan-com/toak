#!/usr/bin/env bash
# Prints the production backend URL that release builds must call.
#
# Order of truth:
#   1. API_BASE_URL, if the caller set it explicitly (an override).
#   2. backend.custom_domain from project.yaml, once one is mapped.
#   3. backend.url from project.yaml.
#
# When gcloud is available, the project.yaml URL is checked against the live
# Cloud Run service, so a stale value fails here instead of shipping a client
# that calls the wrong address.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tools/project_config.sh
source "$root/tools/project_config.sh"

if [[ -n "${API_BASE_URL:-}" ]]; then
  echo "    Using API_BASE_URL override: $API_BASE_URL" >&2
  printf '%s\n' "$API_BASE_URL"
  exit 0
fi

configured_url="$(project_value backend.url)"
custom_domain="$(project_value backend.custom_domain)"

if command -v gcloud >/dev/null 2>&1; then
  live_url="$(
    gcloud run services describe "$(project_value backend.service)" \
      --project "$(project_value backend.gcp_project)" \
      --region "$(project_value backend.region)" \
      --format='value(status.url)' 2>/dev/null || true
  )"
  if [[ -n "$live_url" && "$live_url" != "$configured_url" ]]; then
    echo "ERROR: project.yaml backend.url is stale." >&2
    echo "       project.yaml: $configured_url" >&2
    echo "       Cloud Run:    $live_url" >&2
    echo "       Update backend.url in project.yaml (and run tools/verify_identity.sh)." >&2
    exit 1
  fi
  if [[ -z "$live_url" ]]; then
    echo "    (gcloud could not describe the service; using project.yaml as-is)" >&2
  fi
fi

if [[ -n "$custom_domain" ]]; then
  printf 'https://%s\n' "${custom_domain#https://}"
else
  printf '%s\n' "$configured_url"
fi
