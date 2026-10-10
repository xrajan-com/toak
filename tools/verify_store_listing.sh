#!/usr/bin/env bash
# Checks the Google Play listing text in project.yaml's app.store_listing_dir
# against Play's limits and metadata rules before it is pasted or uploaded:
# title <= 30, short description <= 80, full description <= 4000 characters;
# the title starts with the app name; no promotional or ranking words in the
# title or short description; the full description doesn't repeat the short.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
# shellcheck source=tools/project_config.sh
source "$root/tools/project_config.sh"

APP_NAME="$(project_value app.name)" \
LISTING_DIR="$(project_value app.store_listing_dir)" \
node - <<'JS'
const fs = require('fs');
const path = require('path');
const dir = process.env.LISTING_DIR;
const read = (f) => fs.readFileSync(path.join(dir, f), 'utf8').replace(/\n+$/, '');
const chars = (s) => Array.from(s).length;
const title = read('title.txt');
const short = read('short_description.txt');
const full = read('full_description.txt');
const problems = [];
const limit = (name, text, max) => {
  if (chars(text) > max) problems.push(`${name} is ${chars(text)} characters (max ${max})`);
};
limit('title', title, 30);
limit('short description', short, 80);
limit('full description', full, 4000);
if (!title.startsWith(process.env.APP_NAME)) {
  problems.push(`title must start with the app name '${process.env.APP_NAME}'`);
}
const banned = /\b(free|best|top|new|sale|discount|no ads|#1|number one)\b|#1/i;
for (const [name, text] of [['title', title], ['short description', short]]) {
  const m = text.match(banned);
  if (m) problems.push(`${name} contains promotional wording '${m[0]}'`);
  if (/\p{Extended_Pictographic}/u.test(text)) problems.push(`${name} contains an emoji`);
}
if (full.includes(short)) problems.push('full description repeats the short description');
if (problems.length) {
  for (const p of problems) console.error(`STORE LISTING: ${p}`);
  process.exit(1);
}
console.log(`Store listing within Play limits: title ${chars(title)}/30, short ${chars(short)}/80, full ${chars(full)}/4000`);
JS
