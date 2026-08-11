#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

project_id="${PROJECT_ID:-${FIREBASE_PROJECT_ID:-ten-of-a-kind-poker}}"
region="${CLOUD_RUN_REGION:-asia-south1}"
service_name="${BACKEND_SERVICE_NAME:-toak-backend}"
cors_origin="${CORS_ORIGIN:-https://tenofakind.com,https://www.tenofakind.com,https://ten-of-a-kind-poker.web.app,https://ten-of-a-kind-poker.firebaseapp.com}"
runtime_service_account="${BACKEND_SERVICE_ACCOUNT:-toak-backend@$project_id.iam.gserviceaccount.com}"
preflight_tag="${BACKEND_PREFLIGHT_TAG:-preflight-550}"

java_major_for() {
  "$1/bin/java" -version 2>&1 |
    awk -F '"' '/version/ {
      split($2, parts, ".");
      if (parts[1] == "1") {
        print parts[2];
      } else {
        print parts[1];
      }
      exit;
    }'
}

use_java_21_or_newer_if_available() {
  local candidates=()
  if [[ -n "${JAVA_HOME:-}" ]]; then
    candidates+=("$JAVA_HOME")
  fi
  candidates+=(
    "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
    "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
    "/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
    "/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  )

  local candidate major
  for candidate in "${candidates[@]}"; do
    if [[ ! -x "$candidate/bin/java" ]]; then
      continue
    fi
    major="$(java_major_for "$candidate")"
    if [[ "$major" =~ ^[0-9]+$ && "$major" -ge 21 ]]; then
      export JAVA_HOME="$candidate"
      export PATH="$JAVA_HOME/bin:$PATH"
      return
    fi
  done
}

cd "$repo_root"

echo "==> Testing backend"
npm --prefix backend test
npm --prefix backend audit --omit=dev --audit-level=high
bash "$repo_root/tools/verify_assets.sh"
bash "$repo_root/tools/verify_economy_catalog.sh"
use_java_21_or_newer_if_available
bash "$repo_root/tools/verify_firestore_rules.sh"

current_service_json="$(
  gcloud run services describe "$service_name" \
    --project "$project_id" \
    --region "$region" \
    --format=json
)"
previous_revision="$(
  node -e '
    const service = JSON.parse(process.argv[1]);
    const traffic = service.status?.traffic || [];
    process.stdout.write(
      traffic.find((entry) => entry.percent === 100)?.revisionName || "",
    );
  ' "$current_service_json"
)"
if [[ -z "$previous_revision" ]]; then
  echo "ERROR: Could not identify the current 100% traffic revision." >&2
  exit 1
fi

echo "==> Deploying backend candidate with no production traffic"
gcloud run deploy "$service_name" \
  --project "$project_id" \
  --region "$region" \
  --source "$repo_root/backend" \
  --no-traffic \
  --tag "$preflight_tag" \
  --allow-unauthenticated \
  --service-account "$runtime_service_account" \
  --cpu 1 \
  --memory 256Mi \
  --concurrency 80 \
  --max-instances 2 \
  --min-instances 0 \
  --set-env-vars="^@^NODE_ENV=production@FIREBASE_PROJECT_ID=$project_id@CORS_ORIGIN=$cors_origin@ALLOW_LEGACY_CLIENT_ECONOMY_MIGRATION=false@ALLOW_LEGACY_UNCATALOGUED_ECONOMY_EVENTS=false"

candidate_service_json="$(
  gcloud run services describe "$service_name" \
    --project "$project_id" \
    --region "$region" \
    --format=json
)"
candidate_revision="$(
  node -e '
    const service = JSON.parse(process.argv[1]);
    process.stdout.write(service.status?.latestReadyRevisionName || "");
  ' "$candidate_service_json"
)"
candidate_url="$(
  node -e '
    const service = JSON.parse(process.argv[1]);
    const tag = process.argv[2];
    const traffic = service.status?.traffic || [];
    process.stdout.write(traffic.find((entry) => entry.tag === tag)?.url || "");
  ' "$candidate_service_json" "$preflight_tag"
)"
if [[ -z "$candidate_revision" || -z "$candidate_url" ]]; then
  echo "ERROR: Candidate revision or tagged URL was not ready." >&2
  exit 1
fi

smoke_args=()
if [[ -z "${FIREBASE_ID_TOKEN:-}" && \
      ( -z "${FIREBASE_TEST_EMAIL:-}" || \
        -z "${FIREBASE_TEST_PASSWORD:-}" ) ]]; then
  smoke_args+=(--ephemeral-user)
fi

echo "==> Verifying no-traffic candidate health and economy behavior"
API_BASE_URL="$candidate_url" \
  node "$repo_root/tools/smoke_backend_live.mjs" --health-only
ALLOW_MUTATING_SMOKE=1 API_BASE_URL="$candidate_url" \
  node "$repo_root/tools/smoke_backend_live.mjs" "${smoke_args[@]}"

# Deploy rules only after the replacement backend has passed authenticated
# economy smoke tests. If Cloud Run deployment fails, the currently published
# client keeps its existing Firestore access instead of being stranded behind
# server-only rules with no working authority.
echo "==> Deploying secure-default Firestore rules"
firebase deploy \
  --project "$project_id" \
  --only firestore:rules \
  --non-interactive

echo "==> Moving production traffic to the verified candidate"
gcloud run services update-traffic "$service_name" \
  --project "$project_id" \
  --region "$region" \
  --to-revisions="$candidate_revision=100"

service_url="$(
  gcloud run services describe "$service_name" \
    --project "$project_id" \
    --region "$region" \
    --format='value(status.url)'
)"

echo "==> Re-verifying the complete backend + rules release"
if ! ALLOW_MUTATING_SMOKE=1 API_BASE_URL="$service_url" \
  node "$repo_root/tools/smoke_backend_live.mjs" "${smoke_args[@]}"; then
  echo "ERROR: Post-cutover smoke failed; rolling back to $previous_revision." >&2
  gcloud run services update-traffic "$service_name" \
    --project "$project_id" \
    --region "$region" \
    --to-revisions="$previous_revision=100"
  exit 1
fi

cat <<EOF
Backend deployed:
  $service_url

Build web/app clients against this verified backend with:
  RELEASE_ECONOMY_MODE=backend API_BASE_URL=$service_url tools/deploy_web.sh

If api.tenofakind.com is mapped to this Cloud Run service later, pass
API_BASE_URL=https://api.tenofakind.com explicitly.
EOF
