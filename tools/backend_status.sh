#!/usr/bin/env bash
# Read-only health report for the production backend. Changes nothing.
#   bash tools/backend_status.sh            # last 7 days
#   DAYS=30 bash tools/backend_status.sh
# Needs: gcloud (logged in), node, curl.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
# shellcheck source=tools/project_config.sh
source "$root/tools/project_config.sh"
project="$(project_value backend.gcp_project)"
region="$(project_value backend.region)"
service="$(project_value backend.service)"
url="$(project_value backend.url)"
days="${DAYS:-7}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

section() { printf '\n==== %s ====\n' "$1"; }

section "Cloud Run service ($service, $region)"
if gcloud run services describe "$service" --project "$project" --region "$region" --format=json > "$tmp/svc.json" 2>"$tmp/err"; then
  node -e '
    const s=require(process.argv[1]); const t=s.spec.template; const c=t.spec.containers[0];
    const a=t.metadata.annotations||{};
    console.log("latest ready revision:", s.status.latestReadyRevisionName);
    console.log("traffic:", (s.status.traffic||[]).map(x=>`${x.revisionName||x.tag}=${x.percent||0}%`).join(", "));
    console.log("cpu/memory:", c.resources?.limits?.cpu, "/", c.resources?.limits?.memory, " concurrency:", t.spec.containerConcurrency);
    console.log("scaling: min", a["autoscaling.knative.dev/minScale"]||0, " max", a["autoscaling.knative.dev/maxScale"]||"default");
    console.log("env vars set:", (c.env||[]).map(e=>e.name).join(", "));
    console.log("service account:", t.spec.serviceAccountName);
  ' "$tmp/svc.json"
else cat "$tmp/err"; fi

section "Live /health"
curl -fsS -m 20 "$url/health" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{const h=JSON.parse(d);console.log("ok:",h.ok," catalog:",h.catalogVersion," events:",h.catalogEventCount);console.log("supported catalog versions:",(h.supportedCatalogVersions||[]).join(", "))})' || echo "health check FAILED"

section "Requests, last $days days"
gcloud logging read "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"$service\" AND jsonPayload.event=\"http_request\"" \
  --project "$project" --freshness="${days}d" --limit=20000 --format=json > "$tmp/req.json" 2>/dev/null
node -e '
  const rows=require(process.argv[1]).map(r=>r.jsonPayload||{});
  if(!rows.length){console.log("no request logs found");process.exit(0)}
  const n=rows.length, by=(f)=>rows.reduce((m,r)=>(m[f(r)]=(m[f(r)]||0)+1,m),{});
  const ms=rows.map(r=>r.durationMs||0).sort((a,b)=>a-b), q=p=>ms[Math.min(n-1,Math.floor(p*n))];
  console.log("requests:",n,(n>=20000?"(capped at 20000)":""));
  console.log("status:",JSON.stringify(by(r=>String(r.status)[0]+"xx")), " 429s:",rows.filter(r=>r.status===429).length);
  console.log("latency ms: p50",q(.5)," p95",q(.95)," p99",q(.99)," max",ms[n-1]);
  const paths=Object.entries(by(r=>r.method+" "+r.path)).sort((a,b)=>b[1]-a[1]).slice(0,8);
  console.log("top routes:"); for(const [p,c] of paths) console.log("  ",c,p);
' "$tmp/req.json"

section "Errors, last $days days"
gcloud logging read "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"$service\" AND severity>=ERROR" \
  --project "$project" --freshness="${days}d" --limit=2000 --format=json > "$tmp/err.json" 2>/dev/null
node -e '
  const rows=require(process.argv[1]);
  console.log("error log entries:",rows.length);
  const key=r=>{const j=r.jsonPayload||{};return j.event?`${j.event} ${j.errorCode||j.status||""}`:(r.textPayload||"").slice(0,90)};
  const m={}; for(const r of rows){const k=key(r);m[k]=(m[k]||0)+1}
  for(const [k,c] of Object.entries(m).sort((a,b)=>b[1]-a[1]).slice(0,10)) console.log("  ",c,k);
  const oom=rows.filter(r=>/memory limit|OOM|out of memory/i.test(JSON.stringify(r))).length; if(oom) console.log("  out-of-memory events:",oom);
' "$tmp/err.json"

section "Firestore (default database)"
gcloud firestore databases describe --database='(default)' --project "$project" \
  --format='value(locationId,type,pointInTimeRecoveryEnablement,deleteProtectionState)' 2>&1 | sed 's/^/location, type, point-in-time recovery, delete protection: /'
echo "backup schedules:"; gcloud firestore backups schedules list --database='(default)' --project "$project" --format='table(name.basename(),retention,dailyRecurrence,weeklyRecurrence)' 2>&1 | sed 's/^/  /'

section "Alerting and budget"
echo "alert policies:"; gcloud alpha monitoring policies list --project "$project" --format='value(displayName,enabled)' 2>&1 | sed 's/^/  /' | head -20
billing="$(gcloud billing projects describe "$project" --format='value(billingAccountName)' 2>/dev/null | sed 's#billingAccounts/##')"
if [[ -n "$billing" ]]; then
  echo "budgets on billing account $billing:"; gcloud billing budgets list --billing-account="$billing" --format='value(displayName,amount.specifiedAmount.units,amount.specifiedAmount.currencyCode)' 2>&1 | sed 's/^/  /'
fi

section "Backend dependencies"
( cd backend && npm outdated --omit=dev 2>/dev/null || true )
( cd backend && npm audit --omit=dev 2>/dev/null | tail -2 )
