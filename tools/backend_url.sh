#!/usr/bin/env bash
# Prints the backend address that release builds must call.
#
#   bash tools/backend_url.sh            # backend.public_url (what apps call)
#   bash tools/backend_url.sh --direct   # backend.url (Cloud Run's own address)
#
# API_BASE_URL, if set, overrides both.
#
# When gcloud is available, project.yaml's Cloud Run URL is checked against
# the live service, so a stale value fails here instead of quietly breaking
# the deploy checks and the builds that still call it directly.
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
public_url="$(project_value backend.public_url)"

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

if [[ "${1:-}" == "--direct" ]]; then
  printf '%s\n' "$configured_url"
else
  printf '%s\n' "$public_url"
fi
