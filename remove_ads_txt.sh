#!/usr/bin/env bash
set -euo pipefail
cd ~/Desktop/toak

echo "==> Removing the AdSense publisher declaration"
git rm -q hosting/app-ads.txt
git commit -m "$(cat <<'MSG'
Stop declaring an ad publisher on the domain

app-ads.txt authorised an AdSense publisher ID to sell inventory for
this site. Nothing in the app has ever served an ad, and the account it
named is no longer in use, so the file only misrepresented the site.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PWtMYH6cRY2Hgeu7UnnXWn
MSG
)"
git push

echo "==> Publishing hosting (no rebuild; ships the live 1.2.10+85 bundle as-is)"
env -u DEBUG firebase deploy --only hosting --non-interactive

echo
echo "Done. https://tenofakind.com/app-ads.txt should now 404."
