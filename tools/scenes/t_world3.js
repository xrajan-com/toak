// More templates for Asia-Pacific, the Americas and the rest of the world.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

// ---------- figures and props ----------
function hatPath(p, x, y, h, o = {}) { const s = h / 100, hy = y - 94 * s; p.ellipse(x, hy, (o.wide || 16) * s, 2.6 * s, 0, 0, TAU); p.moveTo(x - 7 * s, hy); p.quadraticCurveTo(x - 7 * s, hy - 10 * s, x, hy - 10 * s); p.quadraticCurveTo(x + 7 * s, hy - 10 * s, x + 7 * s, hy); p.closePath(); }
function runnerPath(p, x, y, h, o = {}) {
  const s = h / 100, d = o.flip ? -1 : 1, ph = o.phase || 0;
  p.moveTo(x + d * 4 * s + 7 * s, y - 88 * s); p.arc(x + d * 4 * s, y - 88 * s, 7 * s, 0, TAU);
  p.moveTo(x - 8 * s, y - 76 * s); p.lineTo(x + d * 10 * s, y - 78 * s); p.lineTo(x + d * 4 * s, y - 46 * s); p.lineTo(x - d * 6 * s, y - 46 * s); p.closePath();
  const limb = (ax, ay, a1, l1, a2, l2, w) => { const bx = ax + Math.sin(a1) * l1, by = ay + Math.cos(a1) * l1, cx = bx + Math.sin(a2) * l2, cy = by + Math.cos(a2) * l2; p.moveTo(ax - w, ay); p.lineTo(bx - w, by); p.lineTo(cx - w * 0.7, cy); p.lineTo(cx + w * 0.7, cy); p.lineTo(bx + w, by); p.lineTo(ax + w, ay); p.closePath(); };
  const f = 0.9 + ph * 0.2;
  limb(x, y - 48 * s, d * 0.7 * f, 26 * s, -d * 0.1, 24 * s, 3.4 * s); limb(x, y - 48 * s, -d * 0.5 * f, 24 * s, -d * 1.4, 22 * s, 3.4 * s);
  limb(x, y - 74 * s, -d * 0.8, 16 * s, d * 0.9, 14 * s, 2.2 * s); limb(x + d * 4 * s, y - 74 * s, d * 1.1, 16 * s, d * 2.4, 14 * s, 2.2 * s);
}
function buffalo(ctx, x, base, h, c, o = {}) {
  const d = o.flip ? -1 : 1, s = h / 50, p = P2();
  p.ellipse(x, base - 24 * s, 24 * s, 12 * s, 0, 0, TAU);
  p.ellipse(x + d * 24 * s, base - 22 * s, 9 * s, 7 * s, d * 0.3, 0, TAU);
  for (const lx of [-16, -10, 12, 18]) p.rect(x + d * lx * s - 2.2 * s, base - 16 * s, 4.4 * s, 16 * s);
  p.moveTo(x + d * 18 * s, base - 28 * s); p.quadraticCurveTo(x + d * 4 * s, base - 46 * s, x + d * 20 * s, base - 50 * s); p.quadraticCurveTo(x + d * 12 * s, base - 42 * s, x + d * 24 * s, base - 29 * s); p.closePath();
  p.moveTo(x + d * 26 * s, base - 28 * s); p.quadraticCurveTo(x + d * 44 * s, base - 44 * s, x + d * 34 * s, base - 50 * s); p.quadraticCurveTo(x + d * 38 * s, base - 40 * s, x + d * 28 * s, base - 30 * s); p.closePath();
  p.moveTo(x - d * 23 * s, base - 28 * s); p.lineTo(x - d * 28 * s, base - 10 * s); p.lineTo(x - d * 26 * s, base - 10 * s); p.closePath();
  fillPath(ctx, p, c);
  if (o.rider) { const r = P2(); personPath(r, x - d * 4 * s, base - 30 * s, 26 * s); fillPath(ctx, r, c); const hat = P2(); hat.moveTo(x - d * 4 * s - 9 * s, base - 30 * s - 23 * s); hat.lineTo(x - d * 4 * s, base - 30 * s - 30 * s); hat.lineTo(x - d * 4 * s + 9 * s, base - 30 * s - 23 * s); hat.closePath(); fillPath(ctx, hat, c); }
}
function baobab(ctx, x, base, h, c) {
  const p = P2(), w = h * 0.16;
  p.moveTo(x - w * 1.2, base); p.quadraticCurveTo(x - w * 0.9, base - h * 0.5, x - w * 0.8, base - h * 0.86); p.lineTo(x + w * 0.8, base - h * 0.86); p.quadraticCurveTo(x + w * 0.9, base - h * 0.5, x + w * 1.2, base); p.closePath();
  for (let k = -3; k <= 3; k++) { const a = -Math.PI / 2 + k * 0.32, bx = x + k * w * 0.22, by = base - h * 0.84; p.moveTo(bx - w * 0.1, by); p.lineTo(bx + Math.cos(a) * h * 0.2, by + Math.sin(a) * h * 0.16); p.lineTo(bx + w * 0.1, by); p.closePath(); }
  fillPath(ctx, p, c);
  const cr = P2(); for (let k = -3; k <= 3; k++) { const a = -Math.PI / 2 + k * 0.32; cr.ellipse(x + k * w * 0.22 + Math.cos(a) * h * 0.2, base - h * 0.84 + Math.sin(a) * h * 0.16, h * 0.08, h * 0.04, 0, 0, TAU); } fillPath(ctx, cr, c);
}
function cypress(ctx, x, base, h, c) { const p = P2(); p.moveTo(x, base - h); p.quadraticCurveTo(x + h * 0.12, base - h * 0.5, x + h * 0.07, base); p.lineTo(x - h * 0.07, base); p.quadraticCurveTo(x - h * 0.12, base - h * 0.5, x, base - h); p.closePath(); fillPath(ctx, p, c); }
function balloon(ctx, x, y, r, cols, o = {}) {
  const env = P2(); env.moveTo(x, y + r * 1.3); env.bezierCurveTo(x - r * 0.5, y + r * 0.9, x - r * 1.05, y + r * 0.4, x - r, y - r * 0.1); env.bezierCurveTo(x - r * 0.95, y - r * 1.15, x + r * 0.95, y - r * 1.15, x + r, y - r * 0.1); env.bezierCurveTo(x + r * 1.05, y + r * 0.4, x + r * 0.5, y + r * 0.9, x, y + r * 1.3); env.closePath();
  fillPath(ctx, env, lin(ctx, x - r, 0, x + r, 0, [[0, rgba(shade(cols[0], -0.45))], [0.4, rgba(cols[0])], [1, rgba(shade(cols[0], -0.6))]]));
  ctx.save(); ctx.clip(env); const st = P2(); for (let k = -3; k <= 3; k += 2) { st.moveTo(x + k * r * 0.22, y - r * 1.2); st.quadraticCurveTo(x + k * r * 0.38, y + r * 0.2, x + k * r * 0.08, y + r * 1.4); st.lineTo(x + (k + 1) * r * 0.08, y + r * 1.4); st.quadraticCurveTo(x + (k + 1) * r * 0.38, y + r * 0.2, x + (k + 1) * r * 0.22, y - r * 1.2); st.closePath(); } fillPath(ctx, st, rgba(cols[1], 0.85)); ctx.restore();
  const b = P2(); b.rect(x - r * 0.16, y + r * 1.5, r * 0.32, r * 0.24); b.moveTo(x - r * 0.12, y + r * 1.3); b.lineTo(x - r * 0.15, y + r * 1.5); b.lineTo(x - r * 0.12, y + r * 1.5); b.closePath(); b.moveTo(x + r * 0.12, y + r * 1.3); b.lineTo(x + r * 0.15, y + r * 1.5); b.lineTo(x + r * 0.12, y + r * 1.5); b.closePath(); fillPath(ctx, b, rgba([40, 26, 20]));
  if (o.burner) glow(ctx, x, y + r * 1.25, r * 0.5, [255, 180, 80], 0.7, true);
}
function shipSmoke(ctx, R, x, y, s, flash = true) { withBlur(ctx, 6, () => { for (let k = 0; k < 3; k++) oval(ctx, x + between(R, -s, s) * 0.5, y + between(R, -6, 4), s * between(R, 0.4, 0.7), s * 0.16, rgba([210, 200, 196], 0.35)); }); if (flash) glow(ctx, x, y + 2, s * 0.25, [255, 200, 120], 0.8, true); }
function lineShip(ctx, x, base, s, c, o = {}) { // a ship of the line: three masts, square sails, gun decks
  const d = o.flip ? -1 : 1, p = P2();
  p.moveTo(x - s, base - s * 0.24); p.lineTo(x + s * 0.9, base - s * 0.2); p.quadraticCurveTo(x + s * 1.06, base - s * 0.3, x + s * 1.1, base - s * 0.36); p.lineTo(x + s * 0.8, base); p.lineTo(x - s * 0.84, base); p.quadraticCurveTo(x - s * 1.02, base - s * 0.1, x - s, base - s * 0.24); p.closePath();
  p.rect(x - s * 0.98, base - s * 0.36, s * 0.3, s * 0.14);
  for (const [mx, mh] of [[-0.5, 1.1], [0.05, 1.3], [0.55, 1]]) { const X = x + d * mx * s; p.rect(X - 1, base - s * 0.24 - s * mh, 2, s * mh); for (let k = 0; k < 3; k++) { const sy = base - s * 0.34 - k * s * mh * 0.3, sw = s * (0.26 - k * 0.05); p.moveTo(X - sw, sy - s * mh * 0.24); p.lineTo(X + sw, sy - s * mh * 0.24); p.quadraticCurveTo(X + sw * 1.1, sy - s * mh * 0.12, X + sw, sy); p.lineTo(X - sw, sy); p.quadraticCurveTo(X - sw * 1.1, sy - s * mh * 0.12, X - sw, sy - s * mh * 0.24); p.closePath(); } }
  p.moveTo(x + d * s * 1.06, base - s * 0.34); p.lineTo(x + d * s * 1.5, base - s * 0.62); p.lineTo(x + d * s * 1.48, base - s * 0.58); p.closePath();
  fillPath(ctx, p, c);
  const ports = []; for (let k = 0; k < 12; k++) ports.push([x - s * 0.76 + k * s * 0.14, base - s * 0.14, s * 0.018]); dots(ctx, ports, rgba(o.lit || [255, 190, 110], 0.8));
}

function surfer(ctx, x, base, h, c, o = {}) { const d = o.flip ? -1 : 1, s = h / 30, p = P2(); p.ellipse(x, base, 16 * s, 2.2 * s, d * -0.08, 0, TAU); p.moveTo(x - 5 * s, base - 1); p.lineTo(x - 2 * s, base - 12 * s); p.lineTo(x + 2 * s, base - 12 * s); p.lineTo(x + 5 * s, base - 1); p.lineTo(x + 3 * s, base - 1); p.lineTo(x, base - 9 * s); p.lineTo(x - 3 * s, base - 1); p.closePath(); p.moveTo(x - 3 * s, base - 12 * s); p.lineTo(x + d * 2 * s, base - 22 * s); p.lineTo(x + d * 5 * s, base - 21 * s); p.lineTo(x + 3 * s, base - 12 * s); p.closePath(); p.ellipse(x + d * 4.5 * s, base - 25 * s, 2.6 * s, 2.6 * s, 0, 0, TAU); p.moveTo(x + d * 3 * s, base - 20 * s); p.lineTo(x + d * 14 * s, base - 18 * s); p.lineTo(x + d * 14 * s, base - 17 * s); p.lineTo(x + d * 3 * s, base - 18 * s); p.closePath(); p.moveTo(x + d * 2 * s, base - 20 * s); p.lineTo(x - d * 9 * s, base - 24 * s); p.lineTo(x - d * 9 * s, base - 23 * s); p.lineTo(x + d * 2 * s, base - 18 * s); p.closePath(); fillPath(ctx, p, c); const sp = P2(); sp.moveTo(x - d * 16 * s, base); sp.quadraticCurveTo(x - d * 24 * s, base - 8 * s, x - d * 30 * s, base - 2 * s); strokePath(ctx, sp, rgba([240, 250, 255], 0.8), 1.6); }
function panda(ctx, x, base, h, o = {}) { const d = o.flip ? -1 : 1, s = h / 40, w = P2(), b = P2();
  w.ellipse(x, base - 16 * s, 22 * s, 13 * s, 0, 0, TAU); w.ellipse(x + d * 20 * s, base - 22 * s, 10 * s, 9 * s, 0, 0, TAU); fillPath(ctx, w, rgba([236, 232, 222]));
  for (const lx of [-14, -6, 8, 16]) b.rect(x + d * lx * s - 3.4 * s, base - 14 * s, 6.8 * s, 14 * s); b.moveTo(x + d * 4 * s, base - 28 * s); b.quadraticCurveTo(x + d * 14 * s, base - 30 * s, x + d * 12 * s, base - 6 * s); b.lineTo(x + d * 4 * s, base - 6 * s); b.closePath();
  b.ellipse(x + d * 15 * s, base - 30 * s, 3.4 * s, 3.4 * s, 0, 0, TAU); b.ellipse(x + d * 25 * s, base - 30 * s, 3.4 * s, 3.4 * s, 0, 0, TAU); b.ellipse(x + d * 18 * s, base - 23 * s, 2.4 * s, 3 * s, 0.5, 0, TAU); b.ellipse(x + d * 24 * s, base - 23 * s, 2.4 * s, 3 * s, -0.5, 0, TAU); b.ellipse(x + d * 29 * s, base - 19 * s, 1.6 * s, 1.4 * s, 0, 0, TAU);
  fillPath(ctx, b, rgba([20, 18, 20])); if (o.bamboo) { line(ctx, x + d * 26 * s, base - 14 * s, x + d * 36 * s, base - 44 * s, rgba([90, 140, 60]), 2 * s); } }
function ape(ctx, x, top, h, c, o = {}) { const d = o.flip ? -1 : 1, s = h / 60, p = P2(); // an orangutan hanging from a vine by one long arm
  p.moveTo(x - 1.6 * s, top); p.lineTo(x + 1.6 * s, top); p.lineTo(x + d * 6 * s, top + 26 * s); p.lineTo(x + d * 2 * s, top + 27 * s); p.closePath();
  p.ellipse(x + d * 8 * s, top + 36 * s, 12 * s, 15 * s, d * 0.2, 0, TAU); p.ellipse(x + d * 4 * s, top + 22 * s, 6 * s, 5.4 * s, 0, 0, TAU);
  p.moveTo(x + d * 14 * s, top + 30 * s); p.quadraticCurveTo(x + d * 30 * s, top + 36 * s, x + d * 28 * s, top + 58 * s); p.lineTo(x + d * 24 * s, top + 58 * s); p.quadraticCurveTo(x + d * 26 * s, top + 40 * s, x + d * 12 * s, top + 38 * s); p.closePath();
  p.moveTo(x + d * 2 * s, top + 46 * s); p.lineTo(x - d * 4 * s, top + 60 * s); p.lineTo(x + d * 1 * s, top + 60 * s); p.lineTo(x + d * 8 * s, top + 48 * s); p.closePath(); p.moveTo(x + d * 12 * s, top + 48 * s); p.lineTo(x + d * 16 * s, top + 62 * s); p.lineTo(x + d * 20 * s, top + 61 * s); p.lineTo(x + d * 16 * s, top + 46 * s); p.closePath();
  fillPath(ctx, p, c); const hair = P2(); for (let k = 0; k < 10; k++) { const yy = top + 26 * s + k * 2.4 * s; hair.moveTo(x + d * (k % 2 ? -3 : 19) * s, yy); hair.lineTo(x + d * (k % 2 ? -6 : 22) * s, yy + 4 * s); } strokePath(ctx, hair, c, 1); line(ctx, x, -20, x, top + 1, rgba([40, 50, 30]), 1.6); }
function hoiAn(ctx, R) { const h = P2(); for (let x = -20; x < SW + 20; x += 54) { h.rect(x, 52, 50, 22); h.moveTo(x - 4, 52); h.lineTo(x + 6, 44); h.lineTo(x + 44, 44); h.lineTo(x + 54, 52); h.closePath(); } fillPath(ctx, h, rgba([150, 120, 50])); const r = P2(); for (let x = -20; x < SW + 20; x += 54) r.rect(x - 4, 50, 58, 3); fillPath(ctx, r, rgba([90, 40, 30])); for (let x = -20; x < SW + 20; x += 54) rect(ctx, x + 10, 58, 30, 12, rgba([255, 200, 110], 0.7)); const cols = [[230, 40, 60], [250, 180, 40], [60, 140, 220], [230, 90, 180], [80, 200, 120]]; for (let x = 10; x < SW; x += 26) { const c = pick(R, cols); glow(ctx, x, 44, 10, c, 0.5, true); const l = P2(); l.ellipse(x, 44, 4, 5, 0, 0, TAU); fillPath(ctx, l, rgba(c)); } }
function immortalShield(p, x, y, h) { p.moveTo(x - h * 0.12, y); p.quadraticCurveTo(x - h * 0.16, y - h * 0.3, x - h * 0.1, y - h * 0.62); p.lineTo(x + h * 0.1, y - h * 0.62); p.quadraticCurveTo(x + h * 0.16, y - h * 0.3, x + h * 0.12, y); p.closePath(); }

// ---------- history ----------
// A palace terrace of tall columns with ranks of spearmen and wicker shields.
TEMPLATES.immortals = (ctx, R, o) => {
  const dark = '#0c0806';
  skyPreset(ctx, 'golden'); ground(ctx, ['#d8a060', '#6a4424', '#160c06']);
  sunDisc(ctx, CX + 300, 70, 20, [255, 120, 50], [255, 214, 130], 86);
  ridge(ctx, R, 80, 24, rgba([140, 100, 100]), { bottom: 92 });
  const t = P2(); t.rect(160, 64, SW - 320, 34); for (let k = 0; k < 8; k++) t.rect(CX - 120 + k * 4, 64 + k * 4, 240 - k * 8, 4); fillPath(ctx, t, lin(ctx, 0, 64, 0, 98, [[0, '#c8a070'], [1, '#5a4028']]));
  const reliefs = P2(); for (let x = 180; x < SW - 180; x += 10) { if (Math.abs(x - CX) < 130) continue; personPath(reliefs, x, 94, 14); } fillPath(ctx, reliefs, rgba([110, 80, 50], 0.6));
  const cols = P2(); for (let x = 210; x < SW - 180; x += 64) { if (Math.abs(x - CX) < 110) continue; const h = 50, top = 64 - h; cols.rect(x - 6, top, 12, h); cols.rect(x - 8, 60, 16, 4); cols.moveTo(x - 16, top); cols.quadraticCurveTo(x - 20, top - 6, x - 14, top - 10); cols.lineTo(x - 4, top - 8); cols.lineTo(x - 4, top); cols.closePath(); cols.moveTo(x + 16, top); cols.quadraticCurveTo(x + 20, top - 6, x + 14, top - 10); cols.lineTo(x + 4, top - 8); cols.lineTo(x + 4, top); cols.closePath(); cols.rect(x - 14, top - 2, 28, 3); } fillPath(ctx, cols, lin(ctx, 0, -10, 0, 64, [[0, '#e0c090'], [1, '#8a6440']]));
  const sp = P2(), sh = P2(); for (let row = 0; row < 1; row++) for (let x = 150; x < SW - 140; x += 34) { if (x > DEALER[0] - 30 && x < DEALER[1] + 30) continue; const h = 40, y = 97; soldierPath(sp, x, y, h, { spearSide: 1 }); immortalShield(sh, x - 5, y - h * 0.18, h); } fillPath(ctx, sp, dark); fillPath(ctx, sh, rgba([170, 120, 60]));
  for (const x of [300, 1040]) { line(ctx, x, 20, x, 92, dark, 1.6); const b = P2(); b.rect(x - 14, 22, 28, 22); fillPath(ctx, b, rgba([200, 60, 40])); const f = P2(); f.moveTo(x - 9, 34); f.lineTo(x, 26); f.lineTo(x + 9, 34); f.lineTo(x, 31); f.closePath(); fillPath(ctx, f, rgba([250, 200, 60])); }
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, [255, 170, 90], 0.4, true); const s = P2(); soldierPath(s, 90, 340, 240, { spearSide: 1 }); fillPath(ctx, s, '#080604'); const q = P2(); immortalShield(q, 70, 300, 240); fillPath(ctx, q, rgba([170, 120, 60])); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, [255, 170, 90], 0.35, true); const c = P2(); c.rect(SW - 100, 60, 26, 280); c.moveTo(SW - 130, 60); c.quadraticCurveTo(SW - 130, 30, SW - 104, 26); c.lineTo(SW - 70, 26); c.quadraticCurveTo(SW - 44, 30, SW - 44, 60); c.closePath(); fillPath(ctx, c, lin(ctx, SW - 130, 0, SW - 44, 0, [[0, '#4a3420'], [0.5, '#c8a070'], [1, '#3a2814']])); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#8a6038'], [1, '#140a06']]));
  finish(ctx, { split: 0.35 });
};

// Ships fighting at sea. o.ships: 'galleon' | 'junk' | 'mixed' | 'line'; o.backdrop: 'cliffs' | 'islands' | 'peak' | 'none';
// o.pirate (black flags), o.time ('dusk' | 'night' | 'dawn'), o.flags
TEMPLATES.navalBattle = (ctx, R, o) => {
  const night = o.time === 'night', dark = night ? '#04060c' : '#0a0a10', sea = o.sea || (night ? [14, 30, 52] : [26, 66, 92]);
  const skyName = o.sky || (night ? 'deepNight' : o.time === 'dawn' ? 'dawn' : 'dusk');
  sky(ctx, SKIES[skyName], 0, 60); ground(ctx, [shade(sea, 0.2), shade(sea, -0.4), shade(sea, -0.8)], 60);
  if (night) { stars(ctx, R, 100, [0, 0, SW, 54], { bright: 3 }); moon(ctx, 1000, 18, 9, { halo: 6 }); }
  else sunDisc(ctx, CX - 260, 52, 20, [255, 120, 50], [255, 210, 120], 60);
  clouds(ctx, R, 18, 6, rgba(night ? [40, 50, 70] : [255, 190, 160], 0.35));
  if (o.backdrop === 'cliffs') { const c = P2(); c.moveTo(860, 61); c.lineTo(880, 30); c.lineTo(1000, 22); c.lineTo(1100, 34); c.lineTo(1200, 30); c.lineTo(1300, 61); c.closePath(); fillPath(ctx, c, rgba(shade(sea, -0.55))); }
  if (o.backdrop === 'islands') { const c = P2(); for (const [x, w, h] of [[900, 70, 26], [1040, 50, 18], [260, 60, 20]]) { c.moveTo(x - w, 61); c.quadraticCurveTo(x - w * 0.3, 61 - h * 1.4, x, 61 - h); c.quadraticCurveTo(x + w * 0.4, 61 - h * 1.2, x + w, 61); c.closePath(); } fillPath(ctx, c, rgba(shade(sea, -0.55))); }
  if (o.backdrop === 'peak') { const p = P2(); p.moveTo(960, 61); p.quadraticCurveTo(980, 6, 1006, 4); p.quadraticCurveTo(1030, 8, 1040, 61); p.closePath(); fillPath(ctx, p, rgba(shade(sea, -0.55))); }
  water(ctx, R, 60, 100, sea, { n: 60 });
  if (!night) reflection(ctx, R, CX - 260, 61, 90, [255, 190, 110], 50, 0.45);
  const kind = o.ships || 'galleon', fc = o.flags || [[200, 30, 40], [240, 230, 210]];
  const ships = [[CX - 360, 46, false, 70], [CX + 360, 50, true, 74], [CX - 150, 64, false, 84], [CX + 170, 66, true, 86], [CX - 560, 40, false, 66], [CX + 560, 40, true, 66]];
  ships.forEach(([x, s, flip, by], i) => {
    const k = kind === 'mixed' ? (i % 2 ? 'junk' : 'galleon') : kind;
    if (k === 'junk') junk(ctx, x, by, s, dark, { flip, sail: o.sail });
    else if (k === 'line') lineShip(ctx, x, by, s * 0.9, dark, { flip });
    else iconAt(ctx, 'galleon', x, by + 2, s * 1.1, dark, { flip });
    const fx = x + (flip ? -1 : 1) * s * 0.1, fy = by - s * (k === 'line' ? 1.5 : 1.12);
    const f = P2(); f.rect(fx, fy, s * 0.22, s * 0.13); fillPath(ctx, f, o.pirate && i % 2 === 0 ? '#0c0c0c' : rgba(fc[i % fc.length]));
    if (o.pirate && i % 2 === 0) circle(ctx, fx + s * 0.11, fy + s * 0.065, s * 0.035, rgba([240, 240, 240]));
    shipSmoke(ctx, R, x + (flip ? -1 : 1) * s * 0.7, by - 10, s, i < 4);
  });
  const sp = P2(); for (let i = 0; i < 6; i++) { const x = between(R, 300, 1040), y = between(R, 76, 92); sp.moveTo(x - 4, y); sp.quadraticCurveTo(x, y - between(R, 8, 16), x + 4, y); sp.closePath(); } fillPath(ctx, sp, rgba([230, 240, 250], 0.7));
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, [255, 160, 80], 0.4, true); iconAt(ctx, 'galleon', 100, 330, 240, '#06080c'); shipSmoke(ctx, R, 150, 200, 120); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, [255, 160, 80], 0.35, true); iconAt(ctx, 'pirate-cannon', SW - 100, 330, 200, '#06080c', { flip: true }); shipSmoke(ctx, R, SW - 200, 260, 90); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, rgba(shade(sea, -0.3))], [1, '#04060a']]));
  finish(ctx, { split: 0.35 });
};

// A main street at sundown: false fronts, a water tower, two gunslingers.
TEMPLATES.westernTown = (ctx, R, o) => {
  const dark = '#0e0806';
  skyPreset(ctx, 'golden'); ground(ctx, ['#d89058', '#6a3a1e', '#1a0c06']);
  sunDisc(ctx, CX, 80, 26, [255, 110, 40], [255, 214, 130], 86);
  mesas(ctx, R, 84, rgba([150, 80, 60]));
  horizonHaze(ctx, 84, 8, [255, 190, 120], 0.5);
  const fronts = (x0, x1, right) => { let x = x0; while (x < x1) { const w = between(R, 54, 90), h = between(R, 40, 70), p = P2(), top = 96 - h; p.rect(x, top, w - 4, h); if (R() < 0.6) { p.moveTo(x, top); p.lineTo(x + 10, top - 8); p.lineTo(x + w - 14, top - 8); p.lineTo(x + w - 4, top); p.closePath(); } fillPath(ctx, p, lin(ctx, 0, top - 8, 0, 96, [[0, '#5a3420'], [1, '#1a0e08']])); rect(ctx, x, 96 - h * 0.42, w - 4, 3, rgba([30, 18, 10])); const pr = P2(); for (let px = x + 4; px < x + w - 6; px += 14) pr.rect(px, 96 - h * 0.42, 2, h * 0.42); fillPath(ctx, pr, rgba([30, 18, 10])); for (const wx of [x + w * 0.25, x + w * 0.6]) { rect(ctx, wx, top + 8, 10, 12, rgba([255, 190, 100], 0.85)); } rect(ctx, x + 6, top + 2, w - 16, 5, rgba([230, 200, 150], 0.6)); x += w; } };
  fronts(-20, CX - 200, false); fronts(CX + 200, SW + 20, true);
  const wt = P2(); wt.ellipse(CX + 150, 40, 22, 4, 0, 0, TAU); wt.rect(CX + 128, 40, 44, 22); wt.moveTo(CX + 126, 40); wt.lineTo(CX + 150, 28); wt.lineTo(CX + 174, 40); wt.closePath(); for (const lx of [-18, -6, 6, 18]) wt.rect(CX + 150 + lx - 1, 62, 2, 34); fillPath(ctx, wt, rgba([40, 24, 16]));
  const tm = P2(); for (const [x, s] of [[CX - 200, 1], [CX - 140, 0.8]]) { tm.rect(x - 1, 60, 2, 36); tm.rect(x - 8, 62, 16, 2); } fillPath(ctx, tm, rgba([30, 18, 10])); strokePath(ctx, (() => { const w = P2(); w.moveTo(CX - 200, 63); w.quadraticCurveTo(CX - 170, 68, CX - 140, 63); return w; })(), rgba([30, 18, 10]), 0.6);
  for (const [x, f] of [[540, false], [810, true]]) { const g = P2(); personPath(g, x, 96, 58); hatPath(g, x, 96, 58); fillPath(ctx, g, dark); const hl = P2(); hl.rect(x + (f ? -1 : 1) * 6, 96 - 58 * 0.46, 4, 9); fillPath(ctx, hl, dark); line(ctx, x - 7, 96 - 58 * 0.45, x + 7, 96 - 58 * 0.4, rgba([200, 150, 60]), 1.4); }
  for (const [x, f] of [[460, false], [900, true]]) horse(ctx, x, 96, 40, dark, { flip: f });
  const tw = P2(); tw.ellipse(700, 92, 8, 6, 0, 0, TAU); strokePath(ctx, tw, rgba([60, 40, 20], 0.8), 1);
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, [255, 160, 80], 0.4, true); const p = P2(); p.rect(30, 0, 16, 340); p.rect(150, 0, 16, 340); p.rect(0, 40, 200, 20); fillPath(ctx, p, '#0c0806'); brassLantern(ctx, 100, 60, 20, 16); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, [255, 160, 80], 0.35, true); horse(ctx, SW - 110, 340, 230, '#0c0806', { flip: true }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#8a5a34'], [1, '#140a06']]));
  finish(ctx, { split: 0.4 });
};

// A cavalry column crossing a snowy mountain pass.
TEMPLATES.andesCrossing = (ctx, R, o) => {
  const dark = '#0a0c12', fc = o.flags || [[120, 180, 230], [250, 250, 250]];
  skyPreset(ctx, 'dawn'); ground(ctx, ['#e8eef6', '#7a88a8', '#1a2030']);
  sunDisc(ctx, CX - 300, 70, 18, [255, 150, 90], [255, 220, 170], 86);
  mountains(ctx, R, 70, 60, [150, 150, 190], { snow: [250, 250, 255], snowLine: 0.5, bottom: 90, freqs: [0.004, 0.012, 0.03] });
  mountains(ctx, R, 88, 34, [70, 74, 100], { snow: [235, 240, 250], snowLine: 0.65, bottom: 100 });
  horizonHaze(ctx, 86, 6, [255, 230, 220], 0.4);
  for (let i = 0; i < 9; i++) { const x = 440 + i * 62 + (i > 3 ? 70 : 0); if (x > DEALER[0] - 20 && x < DEALER[1] + 20) continue; const y = 97 - (i % 2) * 2; horse(ctx, x, y, 42, dark, { rider: true }); if (i % 3 === 0) { line(ctx, x + 2, y - 70, x + 2, y - 40, dark, 1.2); const f = P2(); f.rect(x + 2, y - 70, 18, 6); fillPath(ctx, f, rgba(fc[0])); rect(ctx, x + 2, y - 64, 18, 5, rgba(fc[1])); } }
  const mul = P2(); for (const x of [220, 300, 1060, 1140]) { mul.ellipse(x, 84, 12, 6, 0, 0, TAU); for (const lx of [-8, -4, 5, 9]) mul.rect(x + lx, 88, 2, 8); mul.ellipse(x + 13, 80, 4, 3, 0, 0, TAU); mul.rect(x - 8, 74, 16, 6); } fillPath(ctx, mul, dark);
  const sn = []; for (let i = 0; i < 260; i++) sn.push([between(R, 0, SW), between(R, 0, SH), between(R, 0.6, 1.6)]); dots(ctx, sn, rgba([255, 255, 255], 0.6));
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, [255, 200, 160], 0.35, true); rimIcon(ctx, 'cavalry', 80, 340, 240, '#080a10', [255, 220, 200]); });
  anchored(ctx, 'R', () => { line(ctx, SW - 120, 0, SW - 120, 340, '#080a10', 4); const f = P2(); f.rect(SW - 120, 10, 110, 30); fillPath(ctx, f, rgba(fc[0])); rect(ctx, SW - 120, 40, 110, 30, rgba(fc[1])); rect(ctx, SW - 120, 70, 110, 30, rgba(fc[0])); circle(ctx, SW - 65, 55, 9, rgba([250, 200, 60])); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#a8b4c8'], [1, '#141a26']]));
  finish(ctx, { split: 0.3 });
};

// Warriors on the shore, galleons offshore, canoes in the surf.
TEMPLATES.shoreBattle = (ctx, R, o) => {
  const dark = '#080a0c';
  skyPreset(ctx, 'dawn', 60); ground(ctx, ['#3a7aa0', '#14405a', '#06121c'], 60);
  sunDisc(ctx, CX + 280, 54, 18, [255, 140, 60], [255, 220, 150], 60);
  water(ctx, R, 60, 100, [40, 110, 150], { n: 50 }); reflection(ctx, R, CX + 280, 61, 84, [255, 200, 130], 40, 0.45);
  for (const [x, s, f] of [[300, 60, false], [1060, 66, true], [1200, 46, true]]) { iconAt(ctx, 'galleon', x, 70, s, dark, { flip: f }); shipSmoke(ctx, R, x + (f ? -1 : 1) * s * 0.6, 60, s); }
  const sand = P2(); sand.moveTo(-20, 100); sand.lineTo(-20, 86); sand.quadraticCurveTo(CX, 80, SW + 20, 86); sand.lineTo(SW + 20, 100); sand.closePath(); fillPath(ctx, sand, rgba([200, 170, 120]));
  for (const x of [80, 180, 1160, 1260]) palm(ctx, R, x, 86, between(R, 50, 70), dark, { lean: x < CX ? 0.2 : -0.2 });
  for (const [x, f] of [[400, false], [940, true]]) canoe(ctx, x, 86, 40, dark, { crew: 5 });
  const w = P2(), sh = P2(); for (let x = 450; x < 950; x += between(R, 14, 20)) { if (x > DEALER[0] - 20 && x < DEALER[1] + 20) continue; const h = between(R, 26, 32); soldierPath(w, x, 94, h, { spearSide: R() < 0.5 ? -1 : 1 }); sh.ellipse(x + 4, 94 - h * 0.5, h * 0.12, h * 0.2, 0, 0, TAU); } fillPath(ctx, w, dark); fillPath(ctx, sh, rgba([120, 60, 30]));
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, [255, 180, 100], 0.35, true); const s = P2(); soldierPath(s, 90, 340, 240, { spearSide: 1 }); fillPath(ctx, s, '#06080a'); const sh2 = P2(); sh2.ellipse(110, 220, 26, 50, 0, 0, TAU); fillPath(ctx, sh2, rgba([110, 54, 26])); });
  anchored(ctx, 'R', () => { palm(ctx, R, SW - 50, 340, 280, '#06080a', { lean: -0.25 }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#c8a878'], [1, '#2a2014']]));
  finish(ctx, { split: 0.3 });
};

// A drystone city of curved walls and a conical tower, warriors with cowhide shields.
TEMPLATES.stoneCity = (ctx, R, o) => {
  const dark = '#0c0806';
  skyPreset(ctx, 'golden'); ground(ctx, ['#c89a5a', '#5a3e22', '#140c06']);
  sunDisc(ctx, CX - 300, 72, 20, [255, 120, 50], [255, 214, 130], 86);
  ridge(ctx, R, 84, 14, rgba([120, 80, 60]), { bottom: 96 });
  const bo = P2(); for (const [x, r] of [[300, 26], [340, 18], [1040, 30], [1090, 20]]) bo.ellipse(x, 84 - r * 0.6, r, r * 0.8, 0, 0, TAU); fillPath(ctx, bo, rgba([110, 80, 60]));
  const wall = P2(); wall.moveTo(CX - 320, 96); wall.quadraticCurveTo(CX - 300, 54, CX - 120, 46); wall.quadraticCurveTo(CX, 42, CX + 120, 46); wall.quadraticCurveTo(CX + 300, 54, CX + 320, 96); wall.closePath(); fillPath(ctx, wall, lin(ctx, 0, 42, 0, 96, [[0, '#a8906c'], [1, '#3a2c1c']]));
  const cs = P2(); for (let x = CX - 300; x < CX + 300; x += 8) { const y0 = 60 + Math.abs(x - CX) * 0.08; cs.moveTo(x, y0); cs.lineTo(x + 6, y0); } for (let y = 52; y < 96; y += 4) { cs.moveTo(CX - 300 + (y - 52) * 0.5, y); cs.lineTo(CX + 300 - (y - 52) * 0.5, y); } strokePath(ctx, cs, rgba([60, 44, 28], 0.35), 0.6);
  const zz = P2(); for (let x = CX - 160; x < CX + 160; x += 10) { zz.moveTo(x, 50); zz.lineTo(x + 5, 45); zz.lineTo(x + 10, 50); } strokePath(ctx, zz, rgba([60, 44, 28], 0.7), 1);
  const tw = P2(); tw.moveTo(CX + 90, 46); tw.lineTo(CX + 96, 8); tw.quadraticCurveTo(CX + 108, 2, CX + 120, 8); tw.lineTo(CX + 126, 46); tw.closePath(); fillPath(ctx, tw, lin(ctx, CX + 90, 0, CX + 126, 0, [[0, '#c0a47c'], [1, '#5a4430']]));
  rect(ctx, CX - 16, 70, 32, 26, '#0a0605'); glow(ctx, CX, 90, 50, [255, 150, 70], 0.4, true);
  const w = P2(), sh = P2(); for (let x = 140; x < SW - 140; x += between(R, 14, 20)) { if (x > DEALER[0] - 30 && x < DEALER[1] + 30) continue; const h = between(R, 24, 30); soldierPath(w, x, 97, h, { spearSide: -1 }); sh.ellipse(x + 5, 97 - h * 0.55, h * 0.13, h * 0.24, 0, 0, TAU); } fillPath(ctx, w, dark); fillPath(ctx, sh, rgba([230, 220, 200])); const spots = []; for (let x = 140; x < SW - 140; x += 40) spots.push([x, 82, 1.4]); dots(ctx, spots, rgba([40, 26, 20]));
  for (const [x, f] of [[300, false], [1060, true]]) iconAt(ctx, 'elephant', x, 97, 50, dark, { flip: f });
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, [255, 170, 90], 0.4, true); const s = P2(); soldierPath(s, 80, 340, 240, { spearSide: -1 }); fillPath(ctx, s, '#080604'); const sh2 = P2(); sh2.ellipse(104, 200, 30, 62, 0, 0, TAU); fillPath(ctx, sh2, rgba([235, 225, 205])); const sp2 = []; for (let k = 0; k < 6; k++) sp2.push([96 + (k % 2) * 16, 160 + k * 14, 6]); dots(ctx, sp2, rgba([50, 30, 20])); });
  anchored(ctx, 'R', () => { baobab(ctx, SW - 70, 340, 300, '#080604'); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#7a5434'], [1, '#120a06']]));
  finish(ctx, { split: 0.35 });
};

// A great rock fortress rising from the jungle, lion paws at its foot.
TEMPLATES.rockFortress = (ctx, R, o) => {
  const dark = '#08080a';
  skyPreset(ctx, 'dusk'); ground(ctx, ['#5a7a4a', '#1e2c1a', '#080c06']);
  glow(ctx, CX - 320, 84, 360, [255, 140, 70], 0.45, true);
  forestLine(ctx, R, 92, 18, rgba([30, 50, 34]));
  const rk = P2(); rk.moveTo(CX - 210, 96); rk.quadraticCurveTo(CX - 150, 90, CX - 146, 70); rk.lineTo(CX - 150, 24); rk.quadraticCurveTo(CX - 148, 6, CX - 126, 4); rk.lineTo(CX + 120, 0); rk.quadraticCurveTo(CX + 140, 2, CX + 142, 20); rk.lineTo(CX + 146, 70); rk.quadraticCurveTo(CX + 150, 90, CX + 220, 96); rk.closePath(); fillPath(ctx, rk, lin(ctx, CX - 210, 0, CX + 230, 0, [[0, '#c87a50'], [0.5, '#8a4a30'], [1, '#3a1e14']]));
  const st = P2(); for (let k = 0; k < 14; k++) { const x = CX - 140 + k * 21; st.moveTo(x, 6); st.lineTo(x + between(R, -3, 3), 86); } strokePath(ctx, st, rgba([60, 30, 20], 0.4), 1.2);
  const vg = []; for (let i = 0; i < 160; i++) vg.push([between(R, CX - 130, CX + 140), between(R, -6, 4), between(R, 2, 5)]); dots(ctx, vg, rgba([50, 80, 40]));
  const paw = P2(); for (const x of [CX - 70, CX + 70]) { paw.moveTo(x - 30, 96); paw.quadraticCurveTo(x - 32, 70, x - 10, 66); paw.quadraticCurveTo(x + 20, 62, x + 30, 96); paw.closePath(); for (let k = 0; k < 4; k++) paw.ellipse(x - 22 + k * 15, 94, 6, 5, 0, 0, TAU); } fillPath(ctx, paw, lin(ctx, 0, 60, 0, 96, [[0, '#a89070'], [1, '#4a3a2a']]));
  rect(ctx, CX - 14, 70, 28, 26, '#0a0605'); glow(ctx, CX, 90, 60, [255, 150, 70], 0.4, true);
  const pools = P2(); pools.rect(260, 92, 140, 4); pools.rect(940, 92, 140, 4); fillPath(ctx, pools, rgba([255, 190, 130], 0.6));
  for (const [x, s, f] of [[480, 60, false], [570, 52, false], [780, 58, true], [870, 52, true]]) rimIcon(ctx, 'elephant', x, 97, s, dark, [255, 180, 110], { flip: f });
  const w = P2(); for (let x = 140; x < SW - 140; x += between(R, 12, 18)) { if (x > 430 && x < 920) continue; soldierPath(w, x, 97, between(R, 22, 28), { spearSide: 1 }); } fillPath(ctx, w, dark);
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, [255, 160, 80], 0.4, true); palm(ctx, R, 50, 340, 280, '#06080a', { lean: 0.25 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, [255, 160, 80], 0.35, true); rimIcon(ctx, 'elephant', SW - 80, 340, 240, '#06080a', [255, 180, 110], { flip: true }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#3a4a30'], [1, '#080c06']]));
  finish(ctx, { split: 0.35 });
};

// ---------- bars ----------
// Street drinking. o.style: 'korea' (orange tent, soju, steam) | 'biaHoi' (plastic stools, motorbikes)
TEMPLATES.streetTent = (ctx, R, o) => {
  const st = o.style || 'korea', dark = '#0a0808';
  skyPreset(ctx, 'blueHour', 100); skyline(ctx, R, 92, rgba([20, 22, 36]), { h: 54, lit: 0.5 });
  const signs = [[255, 60, 120], [80, 220, 255], [255, 200, 60], [120, 255, 140], [255, 120, 40]];
  for (let i = 0; i < 18; i++) { const x = between(R, 0, SW), y = between(R, 20, 80), c = pick(R, signs); rect(ctx, x, y, between(R, 6, 14), between(R, 14, 26), rgba(c, 0.85)); glow(ctx, x + 5, y + 10, 16, c, 0.25, true); }
  if (st === 'korea') {
    for (const [x0, x1] of [[-20, CX - 60], [CX + 60, SW + 20]]) { const t = P2(); t.moveTo(x0, 30); t.lineTo(x1, 30); t.lineTo(x1, 100); t.lineTo(x0, 100); t.closePath(); fillPath(ctx, t, lin(ctx, 0, 30, 0, 100, [[0, 'rgba(255,120,40,0.85)'], [1, 'rgba(200,70,20,0.75)']])); const sm = P2(); for (let x = x0; x < x1; x += 60) { sm.moveTo(x, 30); sm.lineTo(x, 100); } strokePath(ctx, sm, rgba([140, 50, 20], 0.6), 1.2); glow(ctx, (x0 + x1) / 2, 60, 200, [255, 170, 80], 0.35, true); }
    rect(ctx, -20, 26, SW + 40, 6, rgba([120, 40, 16]));
    for (const x of [200, 480, 860, 1140]) { const b = P2(); b.ellipse(x, 52, 3, 3, 0, 0, TAU); fillPath(ctx, b, rgba([255, 240, 200])); glow(ctx, x, 52, 30, [255, 220, 150], 0.5, true); }
    withBlur(ctx, 8, () => { for (const x of [420, 940]) for (let k = 0; k < 3; k++) oval(ctx, x + k * 8, 70 - k * 12, 14, 8, rgba([240, 240, 240], 0.35)); });
    const tb = P2(); for (const x of [420, 940]) { tb.rect(x - 50, 84, 100, 4); tb.rect(x - 4, 88, 8, 10); } fillPath(ctx, tb, rgba([40, 30, 30]));
    for (const x of [400, 412, 952, 964]) { const b = P2(); b.rect(x - 2.5, 72, 5, 12); b.rect(x - 1, 68, 2, 4); fillPath(ctx, b, rgba([40, 160, 80], 0.9)); }
    const ppl = P2(); for (const [x, h] of [[480, 44], [540, 42], [600, 46], [760, 44], [820, 42], [880, 46]]) personPath(ppl, x, 98, h, { armUp: R() < 0.3 ? 1 : 0 }); fillPath(ctx, ppl, dark);
  } else {
    const sh = P2(); for (let x = -20; x < SW + 20; x += 70) { const h = between(R, 50, 74); sh.rect(x, 96 - h, 66, h); } fillPath(ctx, sh, rgba([60, 50, 46])); for (let x = -20; x < SW + 20; x += 70) { rect(ctx, x + 6, 50, 54, 10, rgba(pick(R, signs), 0.8)); rect(ctx, x + 10, 66, 46, 20, rgba([255, 200, 120], 0.5)); }
    additive(ctx, () => { const tr = P2(); for (let i = 0; i < 16; i++) { const y = between(R, 86, 94), x = between(R, -40, SW); tr.moveTo(x, y); tr.lineTo(x + between(R, 60, 160), y); } strokePath(ctx, tr, rgba([255, 230, 180], 0.4), 1.4); });
    for (const [x, f] of [[300, false], [1060, true]]) { const m = P2(); m.ellipse(x - 10, 92, 5, 5, 0, 0, TAU); m.ellipse(x + 12, 92, 5, 5, 0, 0, TAU); m.moveTo(x - 10, 88); m.lineTo(x + 6, 84); m.lineTo(x + 12, 88); m.closePath(); personPath(m, x, 86, 26); fillPath(ctx, m, dark); glow(ctx, x + (f ? -16 : 16), 86, 14, [255, 240, 200], 0.7, true); }
    const st2 = P2(); for (let x = 420; x < 960; x += 34) { if (x > DEALER[0] - 20 && x < DEALER[1] + 20) continue; st2.rect(x - 7, 90, 14, 3); st2.rect(x - 6, 93, 2, 5); st2.rect(x + 4, 93, 2, 5); } fillPath(ctx, st2, rgba([220, 50, 50]));
    const ppl = P2(); for (const [x, h] of [[470, 30], [520, 32], [590, 30], [780, 32], [840, 30], [900, 32]]) personPath(ppl, x, 92, h, { armUp: 1 }); fillPath(ctx, ppl, dark);
    for (const x of [480, 530, 600, 790, 850, 910]) rect(ctx, x + 4, 92 - 30 * 0.8, 3, 5, rgba([255, 200, 80], 0.9));
  }
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, [255, 160, 80], 0.4, true); const s = P2(); s.rect(30, 280, 120, 12); s.rect(40, 292, 8, 50); s.rect(132, 292, 8, 50); fillPath(ctx, s, rgba(st === 'korea' ? [60, 80, 200] : [220, 50, 50])); for (const x of [60, 90, 120]) { const b = P2(); b.rect(x - 8, 220, 16, 60); b.rect(x - 3, 200, 6, 20); fillPath(ctx, b, rgba(st === 'korea' ? [40, 160, 80] : [230, 170, 40], 0.85)); } });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, [255, 160, 80], 0.35, true); withBlur(ctx, 14, () => { for (let k = 0; k < 4; k++) oval(ctx, SW - 90 + k * 10, 260 - k * 50, 40, 22, rgba([240, 240, 240], 0.3)); }); const pot = P2(); pot.ellipse(SW - 90, 300, 60, 20, 0, 0, TAU); pot.rect(SW - 150, 300, 120, 40); fillPath(ctx, pot, rgba([60, 56, 54])); });
  planks(ctx, F - 10, [50, 40, 36]);
  finish(ctx, { split: 0.2, vignette: 0.5 });
};

// ---------- rock ----------
// A band on the water. o.style: 'riverboat' (paddle steamer) | 'catamaran' (party boat with a DJ)
TEMPLATES.rockBoat = (ctx, R, o) => {
  const st = o.style || 'riverboat', dark = '#06060a', c1 = o.c1 || [255, 80, 160], c2 = o.c2 || [80, 220, 255];
  skyPreset(ctx, st === 'riverboat' ? 'warmNight' : 'night', 70); ground(ctx, ['#1a2a40', '#0a1220', '#04060a'], 70);
  stars(ctx, R, 120, [0, 0, SW, 60], { bright: 4 });
  if (st === 'riverboat') { forestLine(ctx, R, 70, 12, rgba([12, 14, 18])); } else { moon(ctx, 1040, 20, 10, { halo: 8 }); const isl = P2(); isl.moveTo(980, 71); isl.quadraticCurveTo(1060, 50, 1160, 71); isl.closePath(); fillPath(ctx, isl, rgba([10, 14, 20])); for (const x of [1030, 1080, 1110]) palm(ctx, R, x, 64, 20, rgba([10, 14, 20])); }
  water(ctx, R, 70, 100, [24, 40, 70], { n: 40 });
  if (st === 'riverboat') {
    const h = P2(); h.moveTo(CX - 330, 88); h.lineTo(CX + 330, 88); h.lineTo(CX + 300, 98); h.lineTo(CX - 300, 98); h.closePath(); for (const [y, w] of [[70, 300], [52, 250], [36, 180]]) h.rect(CX - w, y, w * 2, 3); for (let x = CX - 300; x <= CX + 300; x += 24) h.rect(x - 1, 52, 2, 36); for (const x of [CX - 100, CX + 100]) { h.rect(x - 5, -10, 10, 46); h.moveTo(x - 9, -10); h.lineTo(x - 5, -4); h.lineTo(x + 5, -4); h.lineTo(x + 9, -10); h.closePath(); } h.ellipse(CX + 360, 80, 30, 18, 0, 0, TAU);
    fillPath(ctx, h, rgba([20, 16, 18]));
    const lt = []; for (let x = CX - 296; x < CX + 296; x += 7) lt.push([x, 70, 1.1], [x, 52, 1.1]); for (let x = CX - 176; x < CX + 176; x += 7) lt.push([x, 36, 1.1]); dots(ctx, lt, rgba([255, 214, 140]));
    for (let x = CX - 280; x < CX + 280; x += 24) rect(ctx, x, 74, 16, 10, rgba([255, 190, 110], 0.6));
    reflection(ctx, R, CX, 98, 100, [255, 200, 130], 300, 0.3);
    for (const [x, f] of [[CX - 150, false], [CX + 150, true]]) guitarist(ctx, x, 52, 30, dark, { flip: f });
    const pp = P2(); for (let x = CX - 280; x < CX + 280; x += 22) { if (Math.abs(x - CX) < 60) continue; personPath(pp, x, 70, 18, { armUp: R() < 0.4 ? 1 : 0 }); } fillPath(ctx, pp, dark);
  } else {
    const h = P2(); h.moveTo(CX - 300, 84); h.lineTo(CX + 300, 84); h.lineTo(CX + 280, 96); h.lineTo(CX - 280, 96); h.closePath(); h.rect(CX - 240, 60, 480, 4); for (const x of [CX - 240, CX + 236]) h.rect(x, 60, 4, 24); h.rect(CX - 1, -20, 2, 84); fillPath(ctx, h, rgba([16, 16, 22]));
    stringLights(ctx, CX - 240, 60, CX, -18, 4, 18, c1, 1.5); stringLights(ctx, CX, -18, CX + 240, 60, 4, 18, c2, 1.5);
    additive(ctx, () => { for (let i = 0; i < 8; i++) { const a = -Math.PI / 2 + (i - 3.5) * 0.25; line(ctx, CX, 60, CX + Math.cos(a) * 500, 60 + Math.sin(a) * 500, rgba(i % 2 ? c1 : c2, 0.35), 1.4); } });
    reflection(ctx, R, CX, 96, 100, c1, 260, 0.3);
    const pp = P2(); for (let x = CX - 270; x < CX + 270; x += 16) { if (Math.abs(x - CX) < 50) continue; personPath(pp, x, 84, between(R, 20, 24), { armUp: R() < 0.5 ? 2 : 1 }); } fillPath(ctx, pp, dark);
  }
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, c1, 0.35, true); if (st === 'riverboat') { const w = P2(); w.ellipse(90, 260, 80, 80, 0, 0, TAU); fillPath(ctx, w, '#100c0e'); const sp = P2(); for (let k = 0; k < 12; k++) { const a = k * TAU / 12; sp.moveTo(90, 260); sp.lineTo(90 + Math.cos(a) * 78, 260 + Math.sin(a) * 78); } strokePath(ctx, sp, rgba([200, 60, 50]), 5); } else palm(ctx, R, 40, 340, 280, '#06060a', { lean: 0.3 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, c2, 0.35, true); guitarist(ctx, SW - 100, 340, 230, '#06060a', { flip: true }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#14202e'], [1, '#020306']]));
  finish(ctx, { split: 0.2 });
};

// An amphitheatre between two huge red rocks, the city lights beyond the stage.
TEMPLATES.redRocks = (ctx, R, o) => {
  const dark = '#08050a', c1 = o.c1 || [255, 120, 40], c2 = o.c2 || [120, 80, 255];
  skyPreset(ctx, 'deepNight'); stars(ctx, R, 200, [0, 0, SW, 70], { bright: 6 });
  ground(ctx, ['#2a1a20', '#120a0e', '#060406']);
  const cityL = []; for (let i = 0; i < 200; i++) cityL.push([between(R, 440, 900), between(R, 78, 86), 0.7]); dots(ctx, cityL, rgba([255, 214, 150], 0.7));
  for (const [side, x0] of [[-1, 0], [1, SW]]) { const r = P2(); r.moveTo(x0, 100); r.lineTo(x0, -10); r.quadraticCurveTo(x0 - side * 140, 0, x0 - side * 340, 40); r.quadraticCurveTo(x0 - side * 400, 70, x0 - side * 420, 100); r.closePath(); fillPath(ctx, r, lin(ctx, x0, 0, x0 - side * 420, 0, [[0, '#3a160e'], [0.7, '#a8482a'], [1, '#c86040']])); const ln = P2(); for (let k = 0; k < 8; k++) { const y = 10 + k * 10; ln.moveTo(x0, y); ln.quadraticCurveTo(x0 - side * 200, y + 8, x0 - side * (300 + k * 10), y + 30); } strokePath(ctx, ln, rgba([60, 20, 10], 0.4), 1.4); }
  const stg = P2(); stg.rect(CX - 120, 64, 240, 8); stg.moveTo(CX - 140, 64); stg.quadraticCurveTo(CX, 22, CX + 140, 64); stg.lineTo(CX + 120, 64); stg.quadraticCurveTo(CX, 32, CX - 120, 64); stg.closePath(); fillPath(ctx, stg, rgba([30, 26, 36]));
  additive(ctx, () => { for (let i = 0; i < 9; i++) { const a = -Math.PI / 2 + (i - 4) * 0.2; line(ctx, CX, 60, CX + Math.cos(a) * 500, 60 + Math.sin(a) * 500, rgba(i % 2 ? c1 : c2, 0.3), 1.6); } glow(ctx, CX, 60, 200, c1, 0.3); });
  for (const [x, f] of [[CX - 80, false], [CX + 80, true]]) guitarist(ctx, x, 64, 26, dark, { flip: f });
  for (let row = 0; row < 3; row++) crowd(ctx, R, 380 - row * 40, 960 + row * 40, 82 + row * 6, 10 + row * 2, dark, { hands: 0.35 });
  anchored(ctx, 'L', () => { glow(ctx, 60, 200, 160, c1, 0.25, true); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 200, 160, c2, 0.25, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#3a1810'], [1, '#060204']]));
  finish(ctx, { split: 0.2 });
};

// ---------- sport ----------
// Distance runners on a highland road at dawn.
TEMPLATES.runners = (ctx, R, o) => {
  const dark = '#0a0806';
  skyPreset(ctx, 'dawn'); ground(ctx, ['#c89a5a', '#5a4022', '#140c06']);
  sunDisc(ctx, CX + 260, 72, 20, [255, 140, 70], [255, 220, 150], 86);
  ridge(ctx, R, 78, 24, rgba([110, 90, 110]), { bottom: 90 }); ridge(ctx, R, 88, 10, rgba([70, 60, 50]), { bottom: 98 });
  for (const x of [200, 320, 1040, 1180]) tree(ctx, R, 'acacia', x, 90, between(R, 36, 50), rgba([30, 24, 20]));
  const rd = P2(); rd.moveTo(-20, 98); rd.lineTo(-20, 92); rd.quadraticCurveTo(CX, 86, SW + 20, 92); rd.lineTo(SW + 20, 98); rd.closePath(); fillPath(ctx, rd, rgba([150, 80, 50]));
  horizonHaze(ctx, 84, 8, [255, 210, 160], 0.4);
  const r = P2(); for (const [x, h, ph] of [[460, 50, 0], [510, 48, 1], [560, 52, 0.5], [610, 48, 1], [760, 50, 0.2], [820, 52, 0.8], [880, 48, 0.4]]) runnerPath(r, x, 96, h, { phase: ph }); fillPath(ctx, r, dark);
  const bibs = P2(); for (const x of [460, 510, 560, 610, 760, 820, 880]) bibs.rect(x - 2, 96 - 50 * 0.72, 7, 5); fillPath(ctx, bibs, rgba([240, 240, 230], 0.8));
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, [255, 190, 120], 0.35, true); tree(ctx, R, 'acacia', 90, 340, 260, '#080604'); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, [255, 190, 120], 0.35, true); const p = P2(); runnerPath(p, SW - 110, 340, 230, { flip: true }); fillPath(ctx, p, '#080604'); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#8a4a2a'], [1, '#120806']]));
  finish(ctx, { split: 0.3 });
};

// ---------- wild ----------
// Hot-air balloons at dawn. o.landmark(ctx, R) for something on the plain.
TEMPLATES.balloons = (ctx, R, o) => {
  skyPreset(ctx, o.sky || 'dawn'); ground(ctx, ['#c8a070', '#5a4428', '#140e08']);
  sunDisc(ctx, CX - 260, 78, 22, [255, 150, 80], [255, 224, 170], 86);
  ridge(ctx, R, 80, 18, rgba([140, 110, 130]), { bottom: 92 });
  if (o.landmark) o.landmark(ctx, R);
  horizonHaze(ctx, 84, 8, [255, 220, 180], 0.4);
  const cols = [[[230, 60, 50], [250, 200, 60]], [[40, 120, 200], [250, 250, 250]], [[250, 150, 40], [200, 40, 120]], [[60, 170, 100], [250, 230, 80]], [[160, 60, 200], [250, 180, 60]]];
  const bl = [[300, 30, 12], [400, 52, 9], [520, 24, 14], [610, 46, 8], [760, 30, 13], [860, 54, 9], [980, 22, 12], [1100, 44, 10], [1220, 28, 8], [200, 60, 6], [1160, 64, 6]];
  bl.forEach(([x, y, r], i) => balloon(ctx, x, y, r, cols[i % cols.length], { burner: i % 3 === 0 }));
  anchored(ctx, 'L', () => { balloon(ctx, 100, 120, 70, cols[0], { burner: true }); });
  anchored(ctx, 'R', () => { balloon(ctx, SW - 110, 170, 54, cols[1]); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#7a6040'], [1, '#140e08']]));
  finish(ctx, { split: 0.3 });
};

// Dhows on a creek at dusk with wind towers on the shore.
TEMPLATES.harbourDusk = (ctx, R, o) => {
  const dark = '#0a0808';
  skyPreset(ctx, 'pinkDusk', 66); ground(ctx, ['#4a6a8a', '#1a2a3a', '#060a10'], 66);
  sunDisc(ctx, CX + 240, 58, 18, [255, 120, 70], [255, 210, 150], 66);
  const sh = P2(); for (let x = -20; x < SW + 20; x += between(R, 30, 50)) { const h = between(R, 10, 18); sh.rect(x, 66 - h, between(R, 24, 40), h); if (R() < 0.4) { sh.rect(x + 6, 66 - h - 12, 8, 12); } } fillPath(ctx, sh, rgba([60, 44, 50]));
  supertall(ctx, 1100, 66, 60, rgba([50, 40, 56]), { lights: [255, 210, 160] });
  water(ctx, R, 66, 100, [50, 80, 110], { n: 40 }); reflection(ctx, R, CX + 240, 67, 96, [255, 190, 140], 50, 0.45);
  for (const [x, s, f] of [[420, 46, false], [560, 40, true], [800, 50, false], [930, 42, true], [240, 32, false]]) dhow(ctx, x, 90, s, dark, { flip: f });
  const lt = []; for (let x = 0; x < SW; x += 6) lt.push([x, 64, 0.8]); dots(ctx, lt, rgba([255, 214, 150], 0.7));
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, [255, 160, 110], 0.35, true); dhow(ctx, 100, 330, 160, '#060606'); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, [255, 160, 110], 0.3, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#2a3a4a'], [1, '#04060a']]));
  finish(ctx, { split: 0.3 });
};

// A garden with a long pool, cypress rows and a pavilion.
TEMPLATES.persianGarden = (ctx, R, o) => {
  const dark = '#0a0a08';
  skyPreset(ctx, 'dusk'); ground(ctx, ['#7a8a5a', '#2a3020', '#0a0c08']);
  glow(ctx, CX, 70, 300, [255, 170, 100], 0.35, true);
  const pv = P2(); pv.rect(CX - 160, 30, 320, 58); fillPath(ctx, pv, lin(ctx, 0, 30, 0, 88, [[0, '#d8b888'], [1, '#6a5038']]));
  for (const x of [CX - 110, CX + 110]) { const a = P2(); cuspedArch(a, x - 26, x + 26, 40, 88, 0.4); fillPath(ctx, a, rgba([40, 60, 90])); glow(ctx, x, 70, 30, [255, 190, 110], 0.5, true); }
  const iw = P2(); cuspedArch(iw, CX - 44, CX + 44, 18, 88, 0.45); fillPath(ctx, iw, rgba([50, 70, 110])); rect(ctx, CX - 170, 26, 340, 6, rgba([60, 120, 160]));
  const pool = P2(); pool.moveTo(CX - 30, 88); pool.lineTo(CX + 30, 88); pool.lineTo(CX + 200, 100); pool.lineTo(CX - 200, 100); pool.closePath(); fillPath(ctx, pool, lin(ctx, 0, 88, 0, 100, [[0, '#ffc890'], [1, '#4a6a8a']]));
  for (const k of [1, 2, 3, 4, 5, 6]) { for (const side of [-1, 1]) cypress(ctx, CX + side * (150 + k * 60), 94, 48 + k * 4, rgba([20, 34, 24])); }
  const ft = []; for (let k = 0; k < 6; k++) ft.push([CX + (k - 2.5) * 30, 92, 1.2]); dots(ctx, ft, rgba([230, 240, 255], 0.8));
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, [255, 170, 100], 0.3, true); cypress(ctx, 90, 340, 320, '#081008'); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, [255, 170, 100], 0.3, true); cypress(ctx, SW - 90, 340, 300, '#081008'); });
  tiles(ctx, F - 10, [60, 110, 140], [220, 210, 190], 24);
  finish(ctx, { split: 0.3 });
};

// Stilt fishermen at sunset.
TEMPLATES.stiltFishers = (ctx, R, o) => {
  const dark = '#0a0606';
  skyPreset(ctx, 'golden', 60); ground(ctx, ['#e09060', '#6a3a28', '#160a08'], 60);
  sunDisc(ctx, CX, 54, 24, [255, 110, 50], [255, 214, 140], 60);
  water(ctx, R, 60, 100, [120, 80, 70], { n: 60 }); reflection(ctx, R, CX, 61, 98, [255, 200, 120], 80, 0.55);
  const p = P2(); for (const [x, h] of [[440, 42], [520, 50], [600, 44], [760, 48], [840, 42], [910, 50], [300, 36], [1060, 38]]) { p.rect(x - 1.2, 96 - h, 2.4, h + 4); p.rect(x - 10, 96 - h + 4, 20, 2); personPath(p, x, 96 - h + 4, 24); p.rect(x + 4, 96 - h - 14, 1, 2); const rod = [x + 6, 96 - h - 12]; p.moveTo(rod[0], rod[1]); p.lineTo(rod[0] + 30, rod[1] - 20); p.lineTo(rod[0] + 30.6, rod[1] - 19); p.closePath(); } fillPath(ctx, p, dark);
  const ln = P2(); for (const [x, h] of [[440, 42], [520, 50], [600, 44], [760, 48], [840, 42], [910, 50]]) { ln.moveTo(x + 36, 96 - h - 32); ln.lineTo(x + 36, 92); } strokePath(ctx, ln, rgba([30, 20, 20], 0.5), 0.5);
  for (const x of [100, 200, 1150, 1260]) palm(ctx, R, x, 64, between(R, 40, 56), dark, { lean: x < CX ? 0.25 : -0.25 });
  anchored(ctx, 'L', () => { palm(ctx, R, 40, 340, 280, '#060404', { lean: 0.3 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, [255, 170, 100], 0.3, true); const q = P2(); q.rect(SW - 110, 60, 8, 280); q.rect(SW - 160, 120, 100, 8); personPath(q, SW - 106, 124, 110); fillPath(ctx, q, '#060404'); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#5a3428'], [1, '#0a0404']]));
  finish(ctx, { split: 0.35 });
};

// An avenue of baobabs at dusk.
TEMPLATES.baobabAvenue = (ctx, R, o) => {
  const dark = '#0c0606';
  skyPreset(ctx, 'pinkDusk'); ground(ctx, ['#c87a50', '#5a2e1e', '#140806']);
  sunDisc(ctx, CX, 80, 22, [255, 110, 60], [255, 210, 150], 86);
  horizonHaze(ctx, 84, 10, [255, 190, 140], 0.5);
  for (const [x, h] of [[120, 80], [250, 74], [380, 66], [500, 58], [860, 58], [980, 66], [1110, 74], [1240, 80]]) baobab(ctx, x, 94, h, dark);
  const cart = P2(); cart.rect(560, 82, 40, 8); cart.ellipse(570, 92, 6, 6, 0, 0, TAU); cart.ellipse(594, 92, 6, 6, 0, 0, TAU); cart.ellipse(620, 86, 12, 7, 0, 0, TAU); cart.moveTo(626, 80); cart.lineTo(634, 72); cart.lineTo(632, 82); cart.closePath(); cart.rect(612, 88, 2, 8); cart.rect(628, 88, 2, 8); fillPath(ctx, cart, dark);
  anchored(ctx, 'L', () => { baobab(ctx, 80, 340, 320, '#080404'); });
  anchored(ctx, 'R', () => { baobab(ctx, SW - 90, 340, 300, '#080404'); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#7a3a24'], [1, '#100604']]));
  finish(ctx, { split: 0.35 });
};

// A beach at sunset with wind-bent trees and sailboats.
TEMPLATES.islandSunset = (ctx, R, o) => {
  const dark = '#0a0608';
  skyPreset(ctx, 'golden', 64); ground(ctx, ['#4a90a8', '#1a4a5a', '#061418'], 64);
  sunDisc(ctx, CX + 200, 58, 20, [255, 110, 50], [255, 214, 140], 64);
  water(ctx, R, 64, 100, [50, 120, 140], { n: 50 }); reflection(ctx, R, CX + 200, 65, 90, [255, 200, 120], 60, 0.5);
  for (const [x, s] of [[520, 30], [880, 36], [1000, 24]]) sailboat(ctx, x, 70, s, dark);
  const sand = P2(); sand.moveTo(-20, 100); sand.lineTo(-20, 88); sand.quadraticCurveTo(CX, 84, SW + 20, 90); sand.lineTo(SW + 20, 100); sand.closePath(); fillPath(ctx, sand, rgba([230, 200, 160]));
  const divi = (x, base, h, flip) => { const d = flip ? -1 : 1, p = P2(); p.moveTo(x - 3, base); p.quadraticCurveTo(x + d * h * 0.2, base - h * 0.5, x + d * h * 0.9, base - h * 0.7); p.lineTo(x + d * h * 0.9, base - h * 0.62); p.quadraticCurveTo(x + d * h * 0.25, base - h * 0.4, x + 3, base); p.closePath(); fillPath(ctx, p, dark); const c = P2(); for (let k = 0; k < 7; k++) c.ellipse(x + d * h * (0.25 + k * 0.12), base - h * (0.74 + Math.sin(k * 1.7) * 0.06), h * 0.14, h * 0.09, 0, 0, TAU); c.moveTo(x + d * h * 0.4, base - h * 0.6); c.lineTo(x + d * h * 0.6, base - h * 0.76); c.lineTo(x + d * h * 0.55, base - h * 0.62); c.closePath(); fillPath(ctx, c, dark); };
  for (const [x, h] of [[200, 50], [360, 40], [1100, 46], [1240, 52]]) divi(x, 90, h, false);
  anchored(ctx, 'L', () => { divi(30, 340, 260, false); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, [255, 170, 100], 0.3, true); palm(ctx, R, SW - 60, 340, 280, '#060404', { lean: -0.3 }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#d8b888'], [1, '#2a2014']]));
  finish(ctx, { split: 0.3 });
};

// A tidewater glacier meeting the sea.
TEMPLATES.glacier = (ctx, R, o) => {
  const dark = '#06080e';
  skyPreset(ctx, o.sky || 'dawn', 64); ground(ctx, ['#4a6a8a', '#1a2a40', '#060a14'], 64);
  mountains(ctx, R, 40, 34, [140, 150, 190], { snow: [250, 250, 255], snowLine: 0.3, bottom: 60 });
  const ice = P2(); ice.moveTo(200, 66); ice.lineTo(240, 34); for (let x = 240; x <= 1100; x += 20) ice.lineTo(x, 36 + between(R, -4, 4)); ice.lineTo(1140, 66); ice.closePath(); fillPath(ctx, ice, lin(ctx, 0, 34, 0, 66, [[0, '#f0f6ff'], [0.4, '#a8d0f0'], [1, '#4a88c0']]));
  const cr = P2(); for (let x = 260; x < 1100; x += between(R, 10, 24)) { cr.moveTo(x, 38); cr.lineTo(x + between(R, -4, 4), 66); } strokePath(ctx, cr, rgba([40, 90, 150], 0.5), 1);
  water(ctx, R, 66, 100, [40, 70, 100], { n: 40 });
  const bg = P2(); for (const [x, w, h] of [[380, 40, 12], [470, 20, 8], [880, 50, 14], [1000, 24, 8], [620, 14, 5]]) { bg.moveTo(x - w, 90); bg.lineTo(x - w * 0.6, 90 - h); bg.lineTo(x + w * 0.3, 90 - h * 1.1); bg.lineTo(x + w, 90); bg.closePath(); } fillPath(ctx, bg, lin(ctx, 0, 76, 0, 90, [[0, '#f0f8ff'], [1, '#7ab0d8']]));
  for (const [x, f] of [[540, false], [800, true]]) canoe(ctx, x, 92, 20, dark, { crew: 1 });
  anchored(ctx, 'L', () => { const c = P2(); c.moveTo(-20, 340); c.lineTo(-20, 120); c.lineTo(60, 100); c.lineTo(140, 200); c.lineTo(180, 340); c.closePath(); fillPath(ctx, c, lin(ctx, 0, 100, 0, 340, [[0, '#e0f0ff'], [1, '#3a6a9a']])); });
  anchored(ctx, 'R', () => { iconAt(ctx, 'polar-bear', SW - 110, 330, 180, '#0a0e16', { flip: true }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#2a4a6a'], [1, '#040810']]));
  finish(ctx, { split: 0.15 });
};

// Autumn hills around a lake. o.barn adds a red barn and a white church-less farmhouse.
TEMPLATES.foliage = (ctx, R, o) => {
  const dark = '#0c0806';
  skyPreset(ctx, 'golden', 70); ground(ctx, ['#4a6a8a', '#1a2a3a', '#060a10'], 70);
  sunDisc(ctx, CX - 260, 60, 18, [255, 140, 60], [255, 220, 150], 70);
  ridge(ctx, R, 60, 16, rgba([130, 100, 110]), { bottom: 72 });
  const leafC = [[220, 70, 30], [240, 140, 40], [250, 200, 60], [180, 40, 30], [120, 120, 40]];
  for (let k = 0; k < 2; k++) for (let x = -20; x < SW + 20; x += between(R, 10, 18)) { const y = 66 + k * 4 + Math.sin(x * 0.01) * 3, r = between(R, 6, 11); circle(ctx, x, y, r, rgba(pick(R, leafC), 0.9)); }
  water(ctx, R, 72, 100, [60, 90, 120], { n: 40 });
  const rf = P2(); for (let x = -20; x < SW + 20; x += 14) { rf.rect(x, 74, 12, between(R, 6, 14)); } fillPath(ctx, rf, rgba([200, 110, 50], 0.35));
  if (o.barn !== false) { const b = P2(); b.rect(380, 56, 34, 18); b.moveTo(376, 56); b.lineTo(397, 44); b.lineTo(418, 56); b.closePath(); fillPath(ctx, b, rgba([170, 40, 30])); const h = P2(); h.rect(920, 58, 40, 16); h.moveTo(916, 58); h.lineTo(940, 48); h.lineTo(964, 58); h.closePath(); fillPath(ctx, h, rgba([236, 232, 220])); rect(ctx, 930, 62, 6, 6, rgba([255, 200, 120])); }
  const cb = P2(); cb.rect(CX - 120, 74, 240, 4); cb.rect(CX - 100, 60, 200, 14); cb.moveTo(CX - 108, 60); cb.lineTo(CX, 50); cb.lineTo(CX + 108, 60); cb.closePath(); fillPath(ctx, cb, rgba([120, 40, 30]));
  canoe(ctx, 560, 88, 20, dark, { crew: 1 }); canoe(ctx, 820, 90, 22, dark, { crew: 2 });
  anchored(ctx, 'L', () => { canopy(ctx, R, 40, 70, 220, 150, [240, 120, 40], [120, 30, 16]); line(ctx, 50, 340, 70, 120, '#1a0e08', 8); });
  anchored(ctx, 'R', () => { canopy(ctx, R, SW - 40, 80, 200, 140, [250, 190, 60], [140, 60, 20]); line(ctx, SW - 60, 340, SW - 70, 140, '#1a0e08', 8); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#6a3a1e'], [1, '#0e0806']]));
  const fl = []; for (let i = 0; i < 80; i++) fl.push([between(R, 0, SW), between(R, F, SH), between(R, 2, 4)]); dots(ctx, fl, rgba([220, 110, 40], 0.6));
  finish(ctx, { split: 0.3 });
};
