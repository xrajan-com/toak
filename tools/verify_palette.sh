#!/usr/bin/env bash
# Enforces the brand palette in project.yaml (colors.*) across lib/:
#  - the app uses exactly two reds, colors.ferrari_red and colors.action_red;
#    any other vivid red literal, or Colors.red / Colors.redAccent, fails;
#  - AppColors and the theme accents match project.yaml.
# Dark felt surfaces, skin, lip and wood tones are not "reds" here: the check
# only looks at saturated reds of mid lightness, the ones that read as brand red.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
# shellcheck source=tools/project_config.sh
source "$root/tools/project_config.sh"

FERRARI_RED="$(project_value colors.ferrari_red)" \
ACTION_RED="$(project_value colors.action_red)" \
BEACH_BLUE="$(project_value colors.beach_blue)" \
node - <<'JS'
const fs = require('fs');
const path = require('path');
const norm = (h) => h.replace('#', '').toUpperCase();
const ferrari = norm(process.env.FERRARI_RED);
const action = norm(process.env.ACTION_RED);
const blue = norm(process.env.BEACH_BLUE);
const allowedReds = new Set([ferrari, action]);

function hsl(hex) {
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
  const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2;
  if (max === min) return { h: 0, s: 0, l };
  const d = max - min;
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  let h;
  if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
  else if (max === g) h = ((b - r) / d + 2) / 6;
  else h = ((r - g) / d + 4) / 6;
  return { h: h * 360, s, l };
}
const isBrandRed = (hex) => {
  const { h, s, l } = hsl(hex);
  return (h < 14.4 || h > 343.8) && s > 0.55 && l > 0.25 && l < 0.75;
};

const files = [];
(function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p);
    else if (p.endsWith('.dart')) files.push(p);
  }
})('lib');

const problems = [];
for (const f of files) {
  fs.readFileSync(f, 'utf8').split('\n').forEach((line, i) => {
    for (const m of line.matchAll(/0x([0-9A-Fa-f]{2})([0-9A-Fa-f]{6})\b/g)) {
      const hex = m[2].toUpperCase();
      if (m[1].toUpperCase() === 'FF' && isBrandRed(hex) && !allowedReds.has(hex)) {
        problems.push(`${f}:${i + 1}: red #${hex} is not one of the two brand reds (#${ferrari}, #${action})`);
      }
    }
    for (const m of line.matchAll(/Color\.fromARGB\(\s*\d+\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/g)) {
      const hex = [m[1], m[2], m[3]].map((n) => (+n).toString(16).padStart(2, '0')).join('').toUpperCase();
      if (isBrandRed(hex) && !allowedReds.has(hex)) {
        problems.push(`${f}:${i + 1}: red #${hex} is not one of the two brand reds (#${ferrari}, #${action})`);
      }
    }
    if (/\bColors\.(red|redAccent)\b/.test(line)) {
      problems.push(`${f}:${i + 1}: Material Colors.red/redAccent; use AppColors.red or AppColors.actionRed`);
    }
  });
}

const expectConst = (file, name, hex) => {
  const src = fs.readFileSync(file, 'utf8');
  const m = src.match(new RegExp(`\\b${name}\\s*=\\s*Color\\(0x[Ff]{2}([0-9A-Fa-f]{6})\\)`));
  if (!m || m[1].toUpperCase() !== hex) problems.push(`${file}: ${name} should be #${hex} (project.yaml), found ${m ? '#' + m[1].toUpperCase() : 'nothing'}`);
};
expectConst('lib/ui/theme/colors.dart', 'red', ferrari);
expectConst('lib/ui/theme/colors.dart', 'actionRed', action);
expectConst('lib/ui/theme/colors.dart', 'blue', blue);
expectConst('lib/themes/app_theme.dart', 'primaryAccent', ferrari);
expectConst('lib/themes/app_theme.dart', 'secondaryAccent', blue);

if (problems.length) {
  for (const p of problems) console.error(`PALETTE: ${p}`);
  process.exit(1);
}
console.log(`Palette matches project.yaml: reds #${ferrari} and #${action} only, blue #${blue}.`);
JS
