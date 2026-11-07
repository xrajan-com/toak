// Templates for Asia, the Americas, Africa, Arabia and the islands.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

// ---------- small creatures ----------
function komodo(ctx, x, base, h, c, o = {}) { const d = o.flip ? -1 : 1, s = h / 20, p = P2(); p.moveTo(x - d * 50 * s, base - 1 * s); p.quadraticCurveTo(x - d * 20 * s, base - 8 * s, x, base - 9 * s); p.quadraticCurveTo(x + d * 20 * s, base - 10 * s, x + d * 28 * s, base - 8 * s); p.lineTo(x + d * 36 * s, base - 6 * s); p.lineTo(x + d * 30 * s, base - 4 * s); p.quadraticCurveTo(x, base - 3 * s, x - d * 50 * s, base); p.closePath(); for (const lx of [-12, 14]) { p.moveTo(x + d * lx * s, base - 5 * s); p.lineTo(x + d * (lx - 4) * s, base); p.lineTo(x + d * (lx + 6) * s, base); p.lineTo(x + d * (lx + 4) * s, base - 5 * s); p.closePath(); } fillPath(ctx, p, c); line(ctx, x + d * 34 * s, base - 5 * s, x + d * 40 * s, base - 4 * s, rgba([200, 60, 40]), 0.8 * s); }
function fennec(ctx, x, base, h, c, o = {}) { const d = o.flip ? -1 : 1, s = h / 30, p = P2(); p.ellipse(x, base - 8 * s, 10 * s, 6 * s, 0, 0, TAU); p.ellipse(x + d * 10 * s, base - 14 * s, 5 * s, 4.5 * s, 0, 0, TAU); for (const k of [-1, 1]) { const ex = x + d * (10 + k * 3) * s; p.moveTo(ex - 2.5 * s, base - 16 * s); p.lineTo(ex + k * d * 3 * s, base - 30 * s); p.lineTo(ex + 2.5 * s, base - 16 * s); p.closePath(); } p.moveTo(x + d * 14 * s, base - 13 * s); p.lineTo(x + d * 19 * s, base - 12 * s); p.lineTo(x + d * 14 * s, base - 11 * s); p.closePath(); p.moveTo(x - d * 9 * s, base - 9 * s); p.quadraticCurveTo(x - d * 22 * s, base - 6 * s, x - d * 20 * s, base - 1 * s); p.quadraticCurveTo(x - d * 14 * s, base - 4 * s, x - d * 8 * s, base - 5 * s); p.closePath(); for (const lx of [-6, -3, 4, 7]) p.rect(x + d * lx * s - 0.8 * s, base - 4 * s, 1.6 * s, 4 * s); fillPath(ctx, p, c); }
function llama(ctx, x, base, h, c, o = {}) { const d = o.flip ? -1 : 1, s = h / 60, p = P2(); p.ellipse(x, base - 30 * s, 16 * s, 9 * s, 0, 0, TAU); for (const lx of [-11, -6, 7, 12]) p.rect(x + lx * s - 1.4 * s, base - 26 * s, 2.8 * s, 26 * s); p.rect(x + d * 10 * s - 3 * s, base - 58 * s, 6 * s, 30 * s); p.ellipse(x + d * 13 * s, base - 58 * s, 6 * s, 3.4 * s, 0, 0, TAU); for (const k of [-1, 1]) { p.moveTo(x + d * (10 + k) * s, base - 60 * s); p.lineTo(x + d * (10 + k * 2) * s, base - 67 * s); p.lineTo(x + d * (11 + k * 2) * s, base - 60 * s); p.closePath(); } fillPath(ctx, p, c); }
function alligator(ctx, x, base, h, c, o = {}) { const d = o.flip ? -1 : 1, s = h / 20, p = P2(); p.moveTo(x - d * 44 * s, base - 1 * s); p.quadraticCurveTo(x - d * 10 * s, base - 9 * s, x + d * 18 * s, base - 8 * s); p.lineTo(x + d * 32 * s, base - 5 * s); p.lineTo(x + d * 32 * s, base - 2 * s); p.lineTo(x + d * 14 * s, base - 2 * s); p.closePath(); fillPath(ctx, p, c); circle(ctx, x + d * 16 * s, base - 9 * s, 1.6 * s, c); }
function butterflies(ctx, R, n, box, cols, sz = [1.2, 2.6]) { const [x0, y0, x1, y1] = box, ws = cols.map(() => []); for (let i = 0; i < n; i++) { const x = between(R, x0, x1), y = between(R, y0, y1), s = between(R, sz[0], sz[1]), k = Math.floor(R() * cols.length); ws[k].push([x - s * 0.6, y, s * 0.7], [x + s * 0.6, y, s * 0.7]); } cols.forEach((c, i) => dots(ctx, ws[i], rgba(c, 0.95))); }
function hummingbird(ctx, x, y, s, c, o = {}) { const d = o.flip ? -1 : 1, p = P2(); p.ellipse(x, y, s * 0.5, s * 0.22, d * -0.4, 0, TAU); p.ellipse(x + d * s * 0.45, y - s * 0.28, s * 0.16, s * 0.15, 0, 0, TAU); p.moveTo(x + d * s * 0.58, y - s * 0.3); p.lineTo(x + d * s * 1.2, y - s * 0.12); p.lineTo(x + d * s * 0.58, y - s * 0.24); p.closePath(); p.moveTo(x - d * s * 0.4, y + s * 0.1); p.lineTo(x - d * s * 0.9, y + s * 0.4); p.lineTo(x - d * s * 0.75, y + s * 0.5); p.closePath(); fillPath(ctx, p, c); const w = P2(); w.ellipse(x - d * s * 0.05, y - s * 0.5, s * 0.18, s * 0.6, d * 0.5, 0, TAU); fillPath(ctx, w, rgba([255, 255, 255], 0.35)); }
function hibiscus(ctx, x, y, s, c) { const p = P2(); for (let k = 0; k < 5; k++) { const a = k * TAU / 5; p.ellipse(x + Math.cos(a) * s * 0.5, y + Math.sin(a) * s * 0.5, s * 0.5, s * 0.36, a, 0, TAU); } fillPath(ctx, p, rgba(c)); circle(ctx, x, y, s * 0.18, rgba([255, 230, 120])); }

// ---------- war & history ----------
TEMPLATES.greatWall = (ctx, R, o) => {
  const dark = '#0c0a10', red = [200, 30, 30], gold = [250, 200, 40];
  skyPreset(ctx, 'dusk'); ground(ctx, ['#b8704a', '#3a2420', '#0e0a0a']);
  glow(ctx, CX - 320, 84, 360, [255, 120, 50], 0.45, true);
  mountains(ctx, R, 70, 40, [120, 80, 100], { bottom: 90, freqs: [0.004, 0.011] });
  const f = mountains(ctx, R, 92, 50, [60, 44, 52], { bottom: 100, freqs: [0.005, 0.014, 0.03] });
  // the wall follows the near ridge, with watchtowers
  const top = (x) => 92 - f(x) - 2;
  const w = P2(); w.moveTo(-20, top(-20) + 8); for (let x = -20; x <= SW + 20; x += 4) w.lineTo(x, top(x)); for (let x = SW + 20; x >= -20; x -= 4) w.lineTo(x, top(x) + 8); w.closePath(); fillPath(ctx, w, rgba([170, 140, 110]));
  const cr = P2(); for (let x = -20; x <= SW + 20; x += 6) cr.rect(x, top(x) - 3, 3.4, 3); fillPath(ctx, cr, rgba([170, 140, 110]));
  for (const x of [180, 420, 940, 1180]) { const y = top(x), t = P2(); t.rect(x - 12, y - 22, 24, 24); t.moveTo(x - 16, y - 22); t.quadraticCurveTo(x, y - 26, x + 16, y - 22); t.lineTo(x + 12, y - 30); t.lineTo(x - 12, y - 30); t.closePath(); fillPath(ctx, t, rgba([150, 120, 96])); glow(ctx, x, y - 14, 14, [255, 170, 80], 0.5, true); rect(ctx, x - 2, y - 16, 4, 6, rgba([255, 210, 140])); }
  // the pass gate behind the dealer: a tall gatehouse with a two-tier roof
  const g = P2(); g.rect(CX - 80, 34, 160, 64); fillPath(ctx, g, lin(ctx, 0, 34, 0, 98, [[0, '#a8805e'], [1, '#4a3424']]));
  const roof = (y, w2) => { const r = P2(); r.moveTo(CX - w2, y + 4); r.quadraticCurveTo(CX - w2 * 0.6, y, CX - w2 * 0.5, y - 10); r.lineTo(CX + w2 * 0.5, y - 10); r.quadraticCurveTo(CX + w2 * 0.6, y, CX + w2, y + 4); r.lineTo(CX + w2 * 0.85, y + 7); r.lineTo(CX - w2 * 0.85, y + 7); r.closePath(); fillPath(ctx, r, '#2a1c1c'); };
  rect(ctx, CX - 54, 14, 108, 22, rgba([170, 40, 30])); roof(34, 96); roof(14, 74);
  rect(ctx, CX - 20, 62, 40, 36, '#0a0605'); glow(ctx, CX, 90, 50, [255, 140, 60], 0.45, true);
  for (const x of [CX - 40, CX + 40]) chochin(ctx, x, 40, 4, 6, [230, 50, 40]);
  // soldiers and banners on the wall and in front
  const ranks = P2(); for (let x = 140; x < SW - 140; x += between(R, 11, 16)) { if (x > CX - 100 && x < CX + 100) continue; soldierPath(ranks, x, 96, between(R, 20, 24), { helmet: 'kabuto', spearSide: R() < 0.5 ? -1 : 1 }); } fillPath(ctx, ranks, dark);
  for (const x of [470, 540, 610, 740, 810, 880]) { line(ctx, x, 40, x, 96, dark, 1.4); const fl = P2(); fl.moveTo(x, 40); fl.lineTo(x + 18, 44); fl.lineTo(x, 60); fl.closePath(); fillPath(ctx, fl, rgba(x % 140 < 70 ? red : gold)); }
  anchored(ctx, 'L', () => { glow(ctx, 50, 170, 200, [255, 150, 70], 0.4, true); line(ctx, 120, -10, 120, 300, '#08060a', 3); const fl = P2(); fl.moveTo(120, 4); fl.lineTo(210, 20); fl.lineTo(120, 110); fl.closePath(); fillPath(ctx, fl, rgba(red)); circle(ctx, 146, 38, 12, rgba(gold)); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 50, 170, 200, [255, 150, 70], 0.35, true); rimIcon(ctx, 'cavalry', SW - 80, 330, 230, '#08060a', [255, 170, 100], { flip: true }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#4a3428'], [1, '#0e0a08']]));
  finish(ctx, { split: 0.35 });
};

// An East or Southeast Asian palace gate. o.style: 'korean' | 'vietnam' | 'thai'; o.elephants, o.rockets
TEMPLATES.asianGate = (ctx, R, o) => {
  const style = o.style || 'korean', dark = '#0c0a10';
  const roofC = { korean: '#20262a', vietnam: '#c8962a', thai: '#a8301e' }[style], wallC = { korean: [150, 140, 130], vietnam: [150, 60, 40], thai: [236, 226, 210] }[style];
  if (o.calm) { skyPreset(ctx, 'blueHour'); ground(ctx, ['#dfe6f2', '#6a7898', '#141a2c']); } else { skyPreset(ctx, style === 'thai' ? 'golden' : 'dusk'); ground(ctx, ['#c8885a', '#4a2a20', '#120c0a']); }
  if (!o.calm) glow(ctx, CX - 320, 84, 360, [255, 140, 60], 0.45, true);
  if (o.calm) mountains(ctx, R, 70, 30, [70, 80, 110], { snow: [230, 236, 250], bottom: 90 }); else ridge(ctx, R, 82, 20, rgba([110, 80, 90]), { bottom: 100 });
  const w = P2(); w.rect(-20, 58, SW + 40, 40); for (let x = -20; x < SW + 20; x += 10) w.rect(x, 54, 6, 4); fillPath(ctx, w, lin(ctx, 0, 54, 0, 98, [[0, rgba(wallC)], [1, rgba(shade(wallC, -0.55))]]));
  const pav = (cx, y, wd, tiers) => {
    for (let t = 0; t < tiers; t++) {
      const yy = y - t * 16, ww = wd * (1 - t * 0.22);
      rect(ctx, cx - ww * 0.42, yy, ww * 0.84, 12, rgba(style === 'korean' ? [60, 110, 90] : style === 'thai' ? [240, 220, 200] : [180, 50, 40]));
      const r = P2(); r.moveTo(cx - ww * 0.62, yy + 2); r.quadraticCurveTo(cx - ww * 0.4, yy, cx - ww * 0.3, yy - 10); r.lineTo(cx + ww * 0.3, yy - 10); r.quadraticCurveTo(cx + ww * 0.4, yy, cx + ww * 0.62, yy + 2);
      if (style === 'thai') { r.lineTo(cx + ww * 0.66, yy - 6); r.lineTo(cx + ww * 0.5, yy + 4); } r.lineTo(cx - ww * 0.5, yy + 4); if (style === 'thai') r.lineTo(cx - ww * 0.66, yy - 6); r.closePath();
      fillPath(ctx, r, roofC);
      if (style === 'thai') { const sp = P2(); sp.moveTo(cx - 3, yy - 10); sp.lineTo(cx, yy - 22); sp.lineTo(cx + 3, yy - 10); sp.closePath(); fillPath(ctx, sp, rgba([230, 180, 60])); }
    }
  };
  if (style === 'vietnam') { const base = P2(); base.rect(CX - 220, 44, 440, 54); fillPath(ctx, base, lin(ctx, 0, 44, 0, 98, [[0, '#a8483a'], [1, '#4a1c14']])); for (const [x, wd] of [[CX - 160, 70], [CX, 110], [CX + 160, 70]]) pav(x, 32, wd, 2); }
  else { const base = P2(); base.rect(CX - 90, 50, 180, 48); fillPath(ctx, base, lin(ctx, 0, 50, 0, 98, [[0, rgba(wallC)], [1, rgba(shade(wallC, -0.5))]])); pav(CX, 34, 170, style === 'thai' ? 3 : 2); }
  const arch = P2(); arch.moveTo(CX - 22, 98); arch.lineTo(CX - 22, 70); arch.quadraticCurveTo(CX, 56, CX + 22, 70); arch.lineTo(CX + 22, 98); arch.closePath(); fillPath(ctx, arch, '#0a0605'); glow(ctx, CX, 90, 50, [255, 140, 60], 0.5, true);
  for (const x of [CX - 60, CX + 60]) chochin(ctx, x, 46, 4, 6, style === 'korean' ? [240, 240, 220] : [230, 60, 40]);
  horizonHaze(ctx, 86, 8, [255, 180, 120], 0.4);
  if (o.calm) { const sr = P2(); sr.rect(-20, 52, SW + 40, 3); for (const [x, w] of [[CX, 170]]) for (let t = 0; t < 2; t++) { const yy = 34 - t * 16, ww = w * (1 - t * 0.22); sr.moveTo(x - ww * 0.55, yy); sr.quadraticCurveTo(x, yy - 14, x + ww * 0.55, yy); sr.lineTo(x + ww * 0.5, yy + 2); sr.lineTo(x - ww * 0.5, yy + 2); sr.closePath(); } fillPath(ctx, sr, rgba([240, 244, 252])); for (const x of [CX - 240, CX - 160, CX + 160, CX + 240, 200, 1140]) { const pv = P2(); pv.rect(x - 22, 70, 44, 26); pv.moveTo(x - 32, 72); pv.quadraticCurveTo(x, 58, x + 32, 72); pv.closePath(); fillPath(ctx, pv, rgba([40, 46, 56])); const sn = P2(); sn.moveTo(x - 32, 70); sn.quadraticCurveTo(x, 56, x + 32, 70); sn.lineTo(x + 28, 72); sn.quadraticCurveTo(x, 62, x - 28, 72); sn.closePath(); fillPath(ctx, sn, rgba([240, 244, 252])); rect(ctx, x - 14, 78, 28, 10, rgba([255, 200, 120], 0.8)); glow(ctx, x, 84, 30, [255, 180, 100], 0.4, true); } const fl = []; for (let i = 0; i < 300; i++) fl.push([between(R, 0, SW), between(R, 0, SH), between(R, 0.6, 1.8)]); dots(ctx, fl, rgba([255, 255, 255], 0.75)); }
  const ranks = P2(); if (!o.calm) for (let x = 140; x < SW - 140; x += between(R, 11, 16)) { if (x > HERO_L[0] - 10 && x < HERO_R[1] + 10) continue; soldierPath(ranks, x, 96, between(R, 20, 24), { helmet: style === 'korean' ? 'kabuto' : null, spearSide: R() < 0.5 ? -1 : 1 }); } fillPath(ctx, ranks, dark);
  const bc = o.banners || [[200, 30, 40], [250, 200, 40], [40, 100, 180], [240, 240, 240]];
  if (!o.calm) for (const [i, x] of [180, 260, 340, 1000, 1080, 1160].entries()) { line(ctx, x, 40, x, 96, dark, 1.3); rect(ctx, x + 0.6, 42, 10, 22, rgba(bc[i % bc.length])); }
  if (o.elephants) { for (const [x, s, f] of [[510, 64, false], [600, 56, false], [770, 60, true], [860, 56, true]]) { rimIcon(ctx, 'elephant', x, 97, s, dark, [255, 180, 100], { flip: f }); const hp = P2(), hx = x + (f ? 0.07 : -0.07) * s, hy = 97 - s * 0.74; hp.moveTo(hx - s * 0.1, hy); hp.quadraticCurveTo(hx, hy - s * 0.3, hx + s * 0.1, hy); hp.closePath(); fillPath(ctx, hp, style === 'thai' ? rgba([200, 150, 50]) : dark); } }
  else if (!o.calm) for (const [x, f] of [[520, false], [600, false], [760, true], [840, true]]) rimIcon(ctx, 'cavalry', x, 97, 50, dark, [255, 180, 100], { flip: f });
  else { const pp = P2(); for (const [x, h] of [[520, 40], [560, 34], [800, 38], [850, 32]]) personPath(pp, x, 96, h); fillPath(ctx, pp, dark); for (const x of [530, 810]) { const um = P2(); um.moveTo(x - 18, 96 - 46); um.quadraticCurveTo(x, 96 - 60, x + 18, 96 - 46); um.closePath(); fillPath(ctx, um, rgba([200, 40, 50])); line(ctx, x, 96 - 56, x, 96 - 30, dark, 1); } }
  if (o.rockets) { additive(ctx, () => { const ar = P2(); for (let i = 0; i < 30; i++) { const x0 = between(R, 400, 520), y0 = between(R, 40, 80); ar.moveTo(x0, y0); ar.quadraticCurveTo(x0 + 120, y0 - 70, x0 + between(R, 260, 420), between(R, 0, 40)); } strokePath(ctx, ar, rgba([255, 190, 90], 0.45), 0.9); }); const hw = P2(); hw.rect(420, 84, 50, 8); hw.ellipse(426, 94, 5, 5, 0, 0, TAU); hw.ellipse(464, 94, 5, 5, 0, 0, TAU); fillPath(ctx, hw, dark); }
  if (o.calm) { anchored(ctx, 'L', () => { pineTree(ctx, 80, 340, 300, '#0a0e16'); const s = P2(); for (let k = 0; k < 6; k++) s.ellipse(80 + (k % 2 ? 30 : -30), 90 + k * 40, 40 - k * 2, 8, 0, 0, TAU); fillPath(ctx, s, rgba([235, 240, 250])); }); anchored(ctx, 'R', () => { glow(ctx, SW - 70, 200, 160, [255, 190, 120], 0.3, true); chochin(ctx, SW - 100, 40, 40, 30, [240, 240, 220]); }); rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#b8c4d8'], [1, '#141a28']])); finish(ctx, { split: 0.2 }); return; }
  anchored(ctx, 'L', () => { glow(ctx, 50, 170, 200, [255, 150, 70], 0.4, true); for (const [x, c] of [[40, bc[0]], [96, bc[1 % bc.length]], [150, bc[2 % bc.length]]]) { line(ctx, x, -5, x, 300, '#08070a', 3); rect(ctx, x + 1.5, 4, 32, 120, rgba(c)); } });
  anchored(ctx, 'R', () => { glow(ctx, SW - 50, 170, 200, [255, 150, 70], 0.35, true); if (o.elephants) rimIcon(ctx, 'elephant', SW - 70, 340, 250, '#08070a', [255, 180, 100], { flip: true }); else rimIcon(ctx, 'archer', SW - 90, 330, 240, '#08070a', [255, 180, 100], { flip: true }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#4a3022'], [1, '#0e0a08']]));
  finish(ctx, { split: 0.35 });
};

// A mud-brick citadel. o.style: 'oman' (round towers, palms) | 'bam' (stepped) | 'ark' (sloped walls) | 'cairo' (domes, pyramids)
// o.troops: 'camel' | 'horseArchers' | 'mamluk' | 'cavalry'
TEMPLATES.desertCitadel = (ctx, R, o) => {
  const style = o.style || 'oman', dark = '#120a08', mud = o.mud || [190, 140, 96];
  skyPreset(ctx, 'golden'); ground(ctx, ['#e0a060', '#6a4024', '#1a0e08']);
  sunDisc(ctx, CX - 300, 74, 22, [255, 120, 50], [255, 214, 130], 80);
  if (style === 'cairo') { for (const [x, w] of [[1000, 90], [1090, 70], [1150, 40]]) pyramid(ctx, x, 80, w, rgba([200, 150, 100]), rgba([150, 100, 70])); }
  ridge(ctx, R, 82, 10, rgba([180, 120, 80]), { bottom: 96 });
  if (style === 'oman' || style === 'cairo') for (let x = 40; x < SW; x += between(R, 30, 70)) if (Math.abs(x - CX) > 200) palm(ctx, R, x, 84, between(R, 26, 40), rgba([60, 50, 30]));
  const m = P2(), fillC = lin(ctx, 0, 10, 0, 98, [[0, rgba(shade(mud, 0.1))], [1, rgba(shade(mud, -0.5))]]);
  if (style === 'ark') { m.moveTo(CX - 260, 98); m.lineTo(CX - 220, 36); m.lineTo(CX + 220, 36); m.lineTo(CX + 260, 98); m.closePath(); for (const x of [CX - 200, CX - 70, CX + 70, CX + 200]) { m.moveTo(x - 16, 40); m.lineTo(x - 12, 22); m.quadraticCurveTo(x, 14, x + 12, 22); m.lineTo(x + 16, 40); m.closePath(); } m.rect(CX - 36, 20, 72, 30); }
  else if (style === 'bam') { for (let t = 0; t < 4; t++) m.rect(CX - 280 + t * 50, 90 - t * 16, 560 - t * 100, 16); m.rect(CX - 20, 10, 40, 30); for (const x of [CX - 260, CX + 260]) m.rect(x - 12, 56, 24, 40); }
  else { m.rect(CX - 240, 52, 480, 46); for (const x of [CX - 240, CX - 100, CX + 100, CX + 240]) { m.moveTo(x - 20, 98); m.lineTo(x - 20, 34); m.quadraticCurveTo(x, 26, x + 20, 34); m.lineTo(x + 20, 98); m.closePath(); } if (style === 'cairo') { m.moveTo(CX - 40, 40); m.quadraticCurveTo(CX, -4, CX + 40, 40); m.closePath(); m.rect(CX - 60, 40, 120, 14); for (const x of [CX - 70, CX + 70]) { m.rect(x - 3, 0, 6, 40); m.moveTo(x - 4, 0); m.lineTo(x, -10); m.lineTo(x + 4, 0); m.closePath(); } } }
  fillPath(ctx, m, fillC);
  const cren = P2(); for (let x = CX - 240; x < CX + 240; x += 9) { cren.moveTo(x, 52); cren.lineTo(x + 2.5, 47); cren.lineTo(x + 5, 52); cren.closePath(); } if (style !== 'ark' && style !== 'bam') fillPath(ctx, cren, rgba(shade(mud, 0.05)));
  const wins = []; for (let i = 0; i < 24; i++) wins.push([between(R, CX - 220, CX + 220), between(R, 40, 90)]); for (const [x, y] of wins.slice(0, 12)) { rect(ctx, x - 1.4, y, 2.8, 5, rgba([40, 20, 10], 0.8)); }
  rect(ctx, CX - 18, 66, 36, 32, '#0a0605'); glow(ctx, CX, 90, 50, [255, 150, 70], 0.5, true);
  horizonHaze(ctx, 88, 8, [255, 200, 140], 0.45);
  const tr = o.troops || 'camel';
  const left = [[490, 52], [560, 56], [620, 48]], right = [[760, 50], [830, 56], [900, 50]];
  for (const [i, [x, s]] of [...left, ...right].entries()) {
    const f = i >= 3;
    if (tr === 'camel') { rimIcon(ctx, 'camel', x, 98, s, dark, [255, 200, 130], { flip: f }); const rd = P2(); personPath(rd, x - (f ? -1 : 1) * s * 0.06, 98 - s * 0.62, s * 0.4); fillPath(ctx, rd, dark); line(ctx, x, 98 - s * 0.9, x + (f ? -1 : 1) * s * 0.3, 98 - s * 1.4, dark, 1.2); }
    else { rimIcon(ctx, 'cavalry', x, 98, s, dark, [255, 200, 130], { flip: f }); if (tr === 'horseArchers') { const b = P2(); b.arc(x + (f ? -1 : 1) * s * 0.2, 98 - s * 0.62, s * 0.18, -1.2, 1.2); strokePath(ctx, b, dark, 1.2); } }
  }
  const fc = o.flags || [[200, 30, 40], [240, 230, 210], [30, 120, 60]];
  for (const [i, x] of [180, 280, 380, 980, 1080, 1180].entries()) { line(ctx, x, 44, x, 96, dark, 1.3); const fl = P2(); fl.moveTo(x, 44); fl.lineTo(x + 18, 50); fl.lineTo(x, 58); fl.closePath(); fillPath(ctx, fl, rgba(fc[i % fc.length])); }
  const ranks = P2(); for (let x = 120; x < SW - 120; x += between(R, 10, 15)) { if (x > HERO_L[0] - 10 && x < HERO_R[1] + 10) continue; soldierPath(ranks, x, 96, between(R, 20, 24), { turban: true, spearSide: 1 }); } fillPath(ctx, ranks, dark);
  anchored(ctx, 'L', () => { glow(ctx, 50, 170, 200, [255, 170, 80], 0.4, true); rimIcon(ctx, tr === 'camel' ? 'camel' : 'cavalry', 70, 340, 250, '#0c0806', [255, 200, 130]); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 50, 170, 200, [255, 170, 80], 0.35, true); palm(ctx, R, SW - 60, 340, 280, '#0c0806', { lean: -0.2 }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#8a5a34'], [1, '#140a06']]));
  finish(ctx, { split: 0.35 });
};

// A frontier fort. o.style: 'stockade' | 'stone' | 'adobe'; o.troops: 'redcoats' | 'continental' | 'cavalry' | 'texian'
TEMPLATES.frontierFort = (ctx, R, o) => {
  const style = o.style || 'stockade', dark = '#0c0a0a', tr = o.troops || 'cavalry';
  skyPreset(ctx, o.sky || 'dusk'); ground(ctx, style === 'adobe' ? ['#d89a5a', '#5a3a22', '#140c08'] : ['#8a8a50', '#2a2a18', '#0c0c08']);
  glow(ctx, CX - 300, 84, 360, [255, 130, 60], 0.45, true);
  if (style === 'stockade') mountains(ctx, R, 84, 40, [110, 100, 130], { snow: [240, 240, 250], bottom: 98 }); else ridge(ctx, R, 84, 16, rgba([100, 90, 100]), { bottom: 98 });
  const f = P2();
  if (style === 'stockade') { for (let x = CX - 300; x < CX + 300; x += 7) { f.moveTo(x, 98); f.lineTo(x, 50 + (x % 3)); f.lineTo(x + 3, 44 + (x % 3)); f.lineTo(x + 6, 50 + (x % 3)); f.lineTo(x + 6, 98); f.closePath(); } for (const x of [CX - 300, CX + 300]) { f.rect(x - 20, 28, 40, 30); f.moveTo(x - 24, 28); f.lineTo(x, 14); f.lineTo(x + 24, 28); f.closePath(); } fillPath(ctx, f, lin(ctx, 0, 14, 0, 98, [[0, '#7a5a3a'], [1, '#2a1a10']])); }
  else if (style === 'stone') { f.rect(CX - 300, 50, 600, 48); for (let x = CX - 300; x < CX + 300; x += 12) f.rect(x, 44, 7, 6); f.moveTo(CX - 330, 98); f.lineTo(CX - 300, 50); f.lineTo(CX - 280, 98); f.closePath(); f.moveTo(CX + 280, 98); f.lineTo(CX + 300, 50); f.lineTo(CX + 330, 98); f.closePath(); fillPath(ctx, f, lin(ctx, 0, 44, 0, 98, [[0, '#9a9488'], [1, '#3a3630']])); }
  else { f.moveTo(CX - 110, 98); f.lineTo(CX - 110, 40); f.lineTo(CX - 60, 40); f.quadraticCurveTo(CX - 40, 30, CX - 30, 14); f.quadraticCurveTo(CX, 6, CX + 30, 14); f.quadraticCurveTo(CX + 40, 30, CX + 60, 40); f.lineTo(CX + 110, 40); f.lineTo(CX + 110, 98); f.closePath(); f.rect(CX - 360, 62, 250, 36); f.rect(CX + 110, 62, 250, 36); fillPath(ctx, f, lin(ctx, 0, 6, 0, 98, [[0, '#e0c8a0'], [1, '#7a6040']])); for (const x of [CX - 70, CX + 70]) { rect(ctx, x - 8, 50, 16, 20, rgba([60, 40, 30])); } }
  rect(ctx, CX - 20, 62, 40, 36, '#0a0605'); glow(ctx, CX, 90, 50, [255, 150, 70], 0.5, true);
  // the flag
  line(ctx, CX + (style === 'adobe' ? 0 : 0), style === 'adobe' ? 12 : 50, CX, -10, dark, 1.6);
  const fl = o.flag || [[200, 30, 40], [250, 250, 250], [30, 50, 120]]; const fw = 40, fh = 24; const p = P2(); p.rect(CX, -8, fw, fh); fillPath(ctx, p, rgba(fl[0])); if (fl[1]) { const s = P2(); for (let k = 1; k < 7; k += 2) s.rect(CX, -8 + k * fh / 7, fw, fh / 7); fillPath(ctx, s, rgba(fl[1])); } if (fl[2]) rect(ctx, CX, -8, fw * 0.42, fh * 0.55, rgba(fl[2])); if (o.flagCross) { rect(ctx, CX + fw * 0.42, -8, 3, fh, rgba([250, 250, 250])); rect(ctx, CX, -8 + fh / 2 - 1.5, fw, 3, rgba([250, 250, 250])); dots(ctx, [[CX + 8, -2, 1.6], [CX + 30, -1, 1.6], [CX + 18, 4, 1.6], [CX + 8, 10, 1.6], [CX + 30, 10, 1.6]], rgba([250, 250, 250])); }
  if (o.rockets) { additive(ctx, () => { const tr = P2(); for (const [x0, x1, y1] of [[200, 420, 6], [300, 560, 20], [1140, 900, 10], [1060, 820, 26]]) { tr.moveTo(x0, 70); tr.quadraticCurveTo((x0 + x1) / 2, -30, x1, y1); } strokePath(ctx, tr, rgba([255, 90, 50], 0.7), 1.4); }); for (const [x, y] of [[420, 6], [560, 20], [900, 10], [820, 26]]) firework(ctx, R, x, y, 14, [255, 120, 60]); }
  // troops
  const coat = tr === 'redcoats' ? [190, 30, 30] : tr === 'continental' ? [40, 60, 130] : null;
  if (tr === 'cavalry') { for (const [x, f2] of [[480, false], [550, false], [620, false], [760, true], [830, true], [900, true]]) rimIcon(ctx, 'cavalry', x, 98, 50, dark, [255, 190, 120], { flip: f2 }); }
  else { const ranks = P2(); for (let x = 440; x < 950; x += 14) { if (x > DEALER[0] - 20 && x < DEALER[1] + 20) continue; soldierPath(ranks, x, 98, 30, { spearSide: 1 }); } fillPath(ctx, ranks, dark); if (coat) { const c = P2(); for (let x = 440; x < 950; x += 14) { if (x > DEALER[0] - 20 && x < DEALER[1] + 20) continue; c.rect(x - 3, 98 - 23, 6, 9); } fillPath(ctx, c, rgba(coat)); } withBlur(ctx, 5, () => { for (let k = 0; k < 6; k++) oval(ctx, 460 + k * 80, 66, 18, 7, rgba([220, 220, 220], 0.35)); }); }
  for (const x of [CX - 360, CX + 360]) iconAt(ctx, 'cannon', x, 98, 34, dark, { flip: x > CX });
  anchored(ctx, 'L', () => { glow(ctx, 50, 170, 200, [255, 160, 80], 0.4, true); if (tr === 'cavalry') rimIcon(ctx, 'cavalry', 70, 340, 240, '#08080a', [255, 190, 120]); else { const s = P2(); soldierPath(s, 90, 340, 240, { spearSide: 1 }); fillPath(ctx, s, '#08080a'); } });
  anchored(ctx, 'R', () => { glow(ctx, SW - 50, 170, 200, [255, 160, 80], 0.35, true); iconAt(ctx, 'cannon', SW - 100, 330, 200, '#08080a', { flip: true }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, style === 'adobe' ? '#8a6a44' : '#4a4a30'], [1, '#0c0a08']]));
  finish(ctx, { split: 0.35 });
};

// Stone-age and island forts: o.kind 'maya' (step pyramids, jaguar warriors) | 'inca' (terraces, megaliths) | 'pa' (palisade hill, war canoes)
TEMPLATES.ancientFort = (ctx, R, o) => {
  const kind = o.kind || 'maya', dark = '#0a0c0a';
  skyPreset(ctx, kind === 'inca' ? 'dawn' : 'dusk'); ground(ctx, kind === 'pa' ? ['#3a6a8a', '#14304a', '#060e18'] : ['#5a7a4a', '#1e2c1a', '#080c06']);
  glow(ctx, CX - 320, 84, 360, [255, 140, 70], 0.4, true);
  if (kind === 'maya') { forestLine(ctx, R, 88, 24, rgba([30, 50, 34])); stepPyramid(ctx, CX, 96, 240, rgba([150, 140, 110])); stepPyramid(ctx, 300, 92, 120, rgba([110, 104, 84])); stepPyramid(ctx, 1080, 92, 140, rgba([110, 104, 84])); withBlur(ctx, 8, () => oval(ctx, CX, 20, 40, 10, rgba([200, 190, 190], 0.4))); glow(ctx, CX, 30, 30, [255, 150, 60], 0.6, true); }
  if (kind === 'inca') { mountains(ctx, R, 70, 50, [120, 120, 150], { snow: [245, 245, 250], bottom: 90 }); for (let t = 0; t < 6; t++) { const y = 96 - t * 9, p = P2(); p.moveTo(CX - 330 + t * 30, y); p.lineTo(CX + 330 - t * 30, y); p.lineTo(CX + 330 - t * 30, y - 9); p.lineTo(CX - 330 + t * 30, y - 9); p.closePath(); fillPath(ctx, p, rgba(mix([150, 140, 120], [90, 84, 74], t / 6))); const st = P2(); for (let x = CX - 330 + t * 30; x < CX + 330 - t * 30; x += between(R, 8, 16)) { st.moveTo(x, y); st.lineTo(x + 1, y - 9); } strokePath(ctx, st, rgba([60, 50, 40], 0.5), 0.8); rect(ctx, CX - 330 + t * 30, y - 9, 660 - t * 60, 2, rgba([90, 140, 60], 0.8)); } const tz = P2(); tz.moveTo(CX - 14, 42); tz.lineTo(CX - 10, 18); tz.lineTo(CX + 10, 18); tz.lineTo(CX + 14, 42); tz.closePath(); fillPath(ctx, tz, '#0a0605'); }
  if (kind === 'pa') { water(ctx, R, 70, 100, [40, 90, 120], { n: 40 }); const h = P2(); h.moveTo(CX - 320, 96); h.quadraticCurveTo(CX - 160, 30, CX, 22); h.quadraticCurveTo(CX + 160, 30, CX + 320, 96); h.closePath(); fillPath(ctx, h, rgba([50, 70, 44])); for (const [y, w] of [[30, 60], [46, 130], [62, 200]]) { const pal = P2(); for (let x = CX - w; x < CX + w; x += 5) { pal.moveTo(x, y + 6); pal.lineTo(x + 1, y - 4); pal.lineTo(x + 2, y + 6); } strokePath(ctx, pal, rgba([60, 40, 26]), 1.4); } const wh = P2(); wh.moveTo(CX - 20, 22); wh.lineTo(CX, 8); wh.lineTo(CX + 20, 22); wh.closePath(); fillPath(ctx, wh, rgba([80, 40, 30])); for (const [x, s, f] of [[480, 60, false], [880, 66, true]]) { canoe(ctx, x, 90, s, dark, { crew: 6 }); const pr = P2(); pr.moveTo(x + (f ? -1 : 1) * s, 88); pr.quadraticCurveTo(x + (f ? -1 : 1) * s * 1.1, 74, x + (f ? -1 : 1) * s * 1.02, 68); pr.lineTo(x + (f ? -1 : 1) * s * 0.96, 86); pr.closePath(); fillPath(ctx, pr, dark); } }
  // warriors
  const ranks = P2(); for (let x = 140; x < SW - 140; x += between(R, 12, 18)) { if (kind === 'pa' && x > 380 && x < 980) continue; if (x > DEALER[0] - 40 && x < DEALER[1] + 40) continue; soldierPath(ranks, x, 97, between(R, 22, 28), { spearSide: R() < 0.5 ? -1 : 1 }); } fillPath(ctx, ranks, dark);
  if (kind === 'maya') { const sh = P2(); for (let x = 140; x < SW - 140; x += 40) { if (x > DEALER[0] - 40 && x < DEALER[1] + 40) continue; sh.ellipse(x - 4, 80, 5, 5, 0, 0, TAU); } fillPath(ctx, sh, rgba([200, 160, 60])); const pl = P2(); for (let x = 140; x < SW - 140; x += 40) { pl.moveTo(x, 72); pl.lineTo(x - 6, 62); pl.lineTo(x + 6, 62); pl.closePath(); } fillPath(ctx, pl, rgba([40, 150, 110])); }
  if (kind === 'inca') for (const [x, f] of [[480, false], [560, true], [800, false], [880, true]]) llama(ctx, x, 97, 40, dark, { flip: f });
  anchored(ctx, 'L', () => { glow(ctx, 50, 170, 200, [255, 160, 80], 0.4, true); const s = P2(); soldierPath(s, 90, 340, 240, { spearSide: 1 }); fillPath(ctx, s, '#08080a'); if (kind === 'maya') { const hd = P2(); for (let k = 0; k < 7; k++) { const a = -Math.PI / 2 + (k - 3) * 0.3; hd.moveTo(90, 120); hd.lineTo(90 + Math.cos(a) * 60, 120 + Math.sin(a) * 60); } strokePath(ctx, hd, rgba([40, 150, 110]), 6); } });
  anchored(ctx, 'R', () => { glow(ctx, SW - 50, 170, 200, [255, 160, 80], 0.35, true); if (kind === 'pa') canoe(ctx, SW - 60, 330, 160, '#08080a', { crew: 0 }); else if (kind === 'inca') llama(ctx, SW - 90, 340, 240, '#08080a', { flip: true }); else palm(ctx, R, SW - 50, 340, 280, '#08080a', { lean: -0.2 }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#3a4a30'], [1, '#080c06']]));
  finish(ctx, { split: 0.3 });
};

TEMPLATES.radarBase = (ctx, R, o) => {
  const dark = '#06080c';
  skyPreset(ctx, 'arctic'); ground(ctx, ['#dfe8f4', '#6a7a9a', '#141a2a']);
  stars(ctx, R, 160, [0, 0, SW, 60], { bright: 4 }); aurora(ctx, R, 16, [[60, 255, 150], [80, 200, 255]], { bands: 4 });
  mountains(ctx, R, 84, 26, [40, 50, 70], { snow: [220, 230, 245], bottom: 96 });
  for (const [x, r] of [[480, 30], [880, 34]]) { const d = P2(); d.arc(x, 90, r, Math.PI, 0); d.closePath(); fillPath(ctx, d, lin(ctx, x - r, 0, x + r, 0, [[0, '#b8c4d4'], [1, '#5a6478']])); const g = P2(); for (let a = 0.2; a < Math.PI; a += 0.3) { g.moveTo(x + Math.cos(Math.PI + a) * r, 90 + Math.sin(Math.PI + a) * r); g.lineTo(x, 90 - r); } strokePath(ctx, g, rgba([40, 50, 70], 0.4), 0.6); }
  const ant = P2(); for (const x of [380, 600, 760, 1000]) { ant.rect(x - 1, 40, 2, 52); ant.rect(x - 14, 40, 28, 2); ant.rect(x - 10, 52, 20, 2); } fillPath(ctx, ant, rgba([30, 36, 50])); for (const x of [380, 600, 760, 1000]) glow(ctx, x, 40, 6, [255, 60, 60], 0.8, true);
  const hut = P2(); hut.rect(560, 80, 60, 14); hut.rect(760, 80, 60, 14); fillPath(ctx, hut, rgba([40, 44, 56])); for (const x of [570, 590, 770, 790]) rect(ctx, x, 84, 6, 4, rgba([255, 210, 140]));
  const sn = []; for (let i = 0; i < 200; i++) sn.push([between(R, 0, SW), between(R, 0, SH), 0.8]); dots(ctx, sn, rgba([255, 255, 255], 0.5));
  anchored(ctx, 'L', () => { iconAt(ctx, 'polar-bear', 80, 330, 220, '#0a0e14'); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 70, 200, 160, [255, 190, 120], 0.25, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#9aa8c4'], [1, '#141a2a']]));
  finish(ctx, { split: 0.15 });
};

// ---------- animals ----------
// Under the sea. o.kind: 'reef' | 'whaleShark' | 'manta' | 'whales' | 'wreck'
TEMPLATES.underwater = (ctx, R, o) => {
  const kind = o.kind || 'reef';
  sky(ctx, ['#2ab0d8', '#0e6aa0', '#06305a', '#03183a'], 0, SH);
  additive(ctx, () => { for (let i = 0; i < 10; i++) { const x = between(R, 100, 1250); beam(ctx, x, -10, Math.PI / 2 + between(R, -0.2, 0.2), 140, 0.12, [200, 240, 255], 0.25); } });
  const bub = []; for (let i = 0; i < 80; i++) bub.push([between(R, 0, SW), between(R, 0, 100), between(R, 0.6, 1.6)]); dots(ctx, bub, rgba([220, 245, 255], 0.5));
  const dark = '#04182a';
  if (kind === 'reef' || kind === 'manta' || kind === 'whaleShark') { const cr = [[240, 110, 120], [250, 180, 80], [200, 90, 200], [80, 200, 170]]; for (let x = -20; x < SW + 20; x += between(R, 14, 30)) { const c = pick(R, cr), h = between(R, 10, 26), p = P2(); if (R() < 0.5) { p.moveTo(x, 98); for (let k = -2; k <= 2; k++) { p.moveTo(x, 98); p.lineTo(x + k * 4, 98 - h * (1 - Math.abs(k) * 0.2)); } strokePath(ctx, p, rgba(c, 0.9), 2.4); } else { p.ellipse(x, 98 - h * 0.4, h * 0.6, h * 0.45, 0, 0, TAU); fillPath(ctx, p, rgba(c, 0.85)); } } }
  if (kind === 'wreck') { const w = P2(); w.moveTo(380, 98); w.lineTo(420, 64); w.lineTo(900, 70); w.lineTo(960, 98); w.closePath(); w.rect(600, 30, 4, 40); w.rect(760, 40, 4, 32); w.moveTo(560, 40); w.lineTo(640, 44); strokePath(ctx, w, rgba([10, 40, 60]), 1); fillPath(ctx, w, rgba([10, 40, 60])); for (let i = 0; i < 20; i++) circle(ctx, between(R, 420, 920), between(R, 68, 96), between(R, 1, 3), rgba([60, 120, 140], 0.6)); }
  // schools of fish
  const fish = []; for (let k = 0; k < 3; k++) { const fx = between(R, 300, 1000), fy = between(R, 20, 70); for (let i = 0; i < 40; i++) fish.push([fx + between(R, -60, 60), fy + between(R, -14, 14)]); }
  const fp = P2(); for (const [x, y] of fish) { fp.moveTo(x - 3, y); fp.quadraticCurveTo(x, y - 1.6, x + 3, y); fp.quadraticCurveTo(x, y + 1.6, x - 3, y); fp.lineTo(x - 5, y - 1.4); fp.lineTo(x - 5, y + 1.4); fp.closePath(); } fillPath(ctx, fp, rgba([200, 230, 250], 0.75));
  if (kind === 'whaleShark') { const s = P2(); s.moveTo(380, 50); s.quadraticCurveTo(560, 30, 760, 44); s.quadraticCurveTo(820, 50, 800, 60); s.quadraticCurveTo(600, 70, 380, 54); s.lineTo(320, 36); s.lineTo(340, 52); s.lineTo(318, 70); s.closePath(); s.moveTo(560, 36); s.lineTo(580, 20); s.lineTo(600, 36); s.closePath(); fillPath(ctx, s, rgba([20, 50, 80])); const sp = []; for (let i = 0; i < 60; i++) sp.push([between(R, 400, 780), between(R, 40, 58), 1]); dots(ctx, sp, rgba([200, 230, 255], 0.7)); }
  if (kind === 'manta') for (const [x, y, s] of [[520, 40, 70], [860, 56, 50]]) { const m = P2(); m.moveTo(x, y - s * 0.2); m.quadraticCurveTo(x - s * 0.5, y - s * 0.3, x - s, y + s * 0.1); m.quadraticCurveTo(x - s * 0.4, y + s * 0.1, x - s * 0.1, y + s * 0.3); m.lineTo(x, y + s * 0.9); m.lineTo(x + s * 0.1, y + s * 0.3); m.quadraticCurveTo(x + s * 0.4, y + s * 0.1, x + s, y + s * 0.1); m.quadraticCurveTo(x + s * 0.5, y - s * 0.3, x, y - s * 0.2); m.closePath(); fillPath(ctx, m, rgba([10, 30, 50])); }
  if (kind === 'whales') { iconAt(ctx, 'sperm-whale', 600, 90, 160, rgba([10, 30, 50])); }
  if (kind === 'reef') { for (const [x, y, s] of [[520, 44, 40], [860, 52, 34]]) { const t = P2(); t.ellipse(x, y, s * 0.6, s * 0.4, 0, 0, TAU); for (const k of [-1, 1]) { t.moveTo(x + k * s * 0.3, y); t.lineTo(x + k * s * 0.8, y - s * 0.3); t.lineTo(x + k * s * 0.5, y + s * 0.1); t.closePath(); } t.ellipse(x + s * 0.7, y - s * 0.05, s * 0.16, s * 0.12, 0, 0, TAU); fillPath(ctx, t, rgba([20, 60, 70])); } }
  anchored(ctx, 'L', () => { const k = P2(); for (let i = 0; i < 6; i++) { const x = 20 + i * 24; k.moveTo(x, 340); k.quadraticCurveTo(x + between(R, -30, 30), 220, x + between(R, -20, 20), 100 + i * 10); } strokePath(ctx, k, rgba([30, 120, 90]), 7); });
  anchored(ctx, 'R', () => { const k = P2(); for (let i = 0; i < 6; i++) { const x = SW - 20 - i * 24; k.moveTo(x, 340); k.quadraticCurveTo(x + between(R, -30, 30), 220, x + between(R, -20, 20), 100 + i * 10); } strokePath(ctx, k, rgba([30, 120, 90]), 7); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#c8b890'], [1, '#2a2418']]));
  finish(ctx, { split: 0.1, vignette: 0.5 });
};

// ---------- bars ----------
// Lounges with a character. o.style: 'havana' | 'tango' | 'cantina' | 'jazz' | 'riad' | 'teaHouse' | 'yurt' | 'lodge' | 'honkyTonk' | 'rooftop' | 'balcony'
TEMPLATES.lounge = (ctx, R, o) => {
  const st = o.style || 'havana', dark = '#0c0808';
  const P = {
    havana: { wall: [40, 110, 110], light: [255, 190, 110] }, tango: { wall: [110, 20, 30], light: [255, 170, 100] }, cantina: { wall: [200, 120, 60], light: [255, 190, 100] },
    jazz: { wall: [40, 30, 60], light: [255, 170, 90] }, riad: { wall: [180, 90, 60], light: [255, 180, 90] }, teaHouse: { wall: [60, 100, 120], light: [255, 190, 110] },
    yurt: { wall: [160, 40, 40], light: [255, 190, 110] }, lodge: { wall: [110, 70, 40], light: [255, 170, 80] }, honkyTonk: { wall: [70, 40, 30], light: [255, 120, 60] },
    rooftop: { wall: [20, 24, 40], light: [255, 200, 140] }, balcony: { wall: [200, 180, 150], light: [255, 190, 110] },
    jiufen: { wall: [110, 50, 30], light: [255, 150, 80] }, karaoke: { wall: [40, 14, 60], light: [255, 90, 200] },
    safari: { wall: [120, 80, 40], light: [255, 180, 90] }, distillery: { wall: [120, 60, 40], light: [255, 170, 90] },
  }[st];
  const wall = P.wall;
  if (st === 'rooftop') { skyPreset(ctx, 'blueHour', 100); skyline(ctx, R, 78, rgba([20, 24, 40]), { h: 40, lit: 0.4 }); if (o.landmark) o.landmark(ctx, R); rect(ctx, -20, 78, SW + 40, 3, rgba([220, 230, 255], 0.5)); for (let x = -20; x < SW + 20; x += 60) rect(ctx, x, 78, 2, 16, rgba([220, 230, 255], 0.4)); rect(ctx, 0, 100, SW, SH - 100, '#0a0c14'); }
  else if (st === 'safari') { skyPreset(ctx, 'golden', 100); sunDisc(ctx, CX + 260, 84, 22, [255, 110, 50], [255, 214, 130], 90); ridge(ctx, R, 88, 10, rgba([140, 80, 60]), { bottom: 96 }); for (const x of [300, 420, 980, 1100]) tree(ctx, R, 'acacia', x, 90, between(R, 30, 44), rgba([30, 20, 16])); giraffe(ctx, 1040, 90, 46, rgba([30, 20, 16])); rect(ctx, 0, 100, SW, SH - 100, '#1a0e08'); thatch(ctx, R, -20, SW + 20, 0, 16, [150, 110, 60]); const po = P2(); for (let x = 40; x < SW; x += 180) po.rect(x, 0, 8, 100); fillPath(ctx, po, rgba([50, 30, 16])); }
  else rect(ctx, 0, 0, SW, SH, rgba(shade(wall, -0.65)));
  if (st !== 'rooftop' && st !== 'safari') rect(ctx, 0, 0, SW, 96, lin(ctx, 0, 0, 0, 96, [[0, rgba(shade(wall, -0.5))], [1, rgba(shade(wall, -0.1))]]));
  glow(ctx, CX, 50, 560, P.light, 0.3, true);
  // wall decor per style
  if (st === 'havana') { for (const x of [CX - 260, CX + 260]) { line(ctx, x, 0, x, 12, dark, 1.4); const f = P2(); for (let k = 0; k < 4; k++) { const a = k * Math.PI / 2 + 0.3; f.ellipse(x + Math.cos(a) * 24, 14 + Math.sin(a) * 3, 24, 3, 0, 0, TAU); } fillPath(ctx, f, rgba([60, 40, 26])); } for (const x of [300, 1040]) { const sh = P2(); sh.rect(x - 30, 20, 60, 60); fillPath(ctx, sh, rgba([30, 70, 70])); const sl = P2(); for (let y = 24; y < 78; y += 5) sl.rect(x - 28, y, 56, 2); fillPath(ctx, sl, rgba([60, 130, 130])); } }
  if (st === 'tango') { const dr = P2(); for (const x of [120, 260, 1080, 1220]) { dr.rect(x - 30, 0, 60, 96); } fillPath(ctx, dr, rgba([150, 30, 40])); const fold = P2(); for (let x = 90; x < 1250; x += 12) { if (x > 290 && x < 1050) continue; fold.moveTo(x, 0); fold.lineTo(x, 96); } strokePath(ctx, fold, rgba([60, 10, 16], 0.5), 2); for (const x of [400, 940]) { glow(ctx, x, 20, 60, [255, 200, 140], 0.6, true); const ch = []; for (let k = 0; k < 10; k++) ch.push([x + Math.cos(k / 10 * TAU) * 16, 20 + Math.sin(k / 10 * TAU) * 4, 1.4]); dots(ctx, ch, rgba([255, 240, 200])); } const bn = P2(); personPath(bn, 1000, 94, 46); bn.rect(986, 66, 28, 14); fillPath(ctx, bn, dark); for (const x of [CX - 260, CX + 260]) { glow(ctx, x, 24, 50, P.light, 0.5, true); } const pr = P2(); for (const [x, y] of [[480, 50], [840, 50]]) { personPath(pr, x, y + 40, 40); personPath(pr, x + 10, y + 40, 38); } fillPath(ctx, pr, dark); }
  if (st === 'cantina') { for (let k = 0; k < 4; k++) { const y = 6 + k * 10, cols = [[230, 40, 120], [250, 200, 40], [40, 160, 220], [120, 200, 60], [240, 110, 40]]; const w = P2(); w.moveTo(-20, y); w.quadraticCurveTo(CX, y + 10, SW + 20, y); strokePath(ctx, w, rgba([30, 20, 20], 0.6), 0.6); for (let x = 0; x < SW; x += 22) { const yy = y + 10 * 2 * (x / SW) * (1 - x / SW) * 2 * 0.5 + 1; const f = P2(); f.rect(x, yy, 16, 12); fillPath(ctx, f, rgba(cols[(x / 22 + k) % 5 | 0], 0.85)); } } }
  if (st === 'jazz') { for (let y = 0; y < 96; y += 7) for (let x = (y / 7) % 2 ? -20 : -6; x < SW + 20; x += 28) rect(ctx, x, y, 26, 6, rgba(shade([110, 50, 36], -0.2 - ((x * 3 + y) % 7) * 0.05))); for (const x of [CX - 160, CX + 160]) beam(ctx, x, -4, Math.PI / 2, 100, 0.35, [255, 200, 130], 0.35, { blur: 4 }); const pn = P2(); pn.moveTo(300, 92); pn.lineTo(300, 70); pn.quadraticCurveTo(340, 56, 400, 66); pn.lineTo(400, 92); pn.closePath(); fillPath(ctx, pn, dark); for (const x of [CX - 260, CX + 260]) glow(ctx, x, 30, 80, [255, 140, 60], 0.4, true); const s = P2(); personPath(s, 520, 94, 54); fillPath(ctx, s, dark); line(ctx, 528, 60, 548, 46, dark, 3); circle(ctx, 550, 44, 4, dark); const s2 = P2(); personPath(s2, 840, 94, 52); fillPath(ctx, s2, dark); const db = P2(); db.ellipse(860, 74, 10, 16, 0, 0, TAU); db.rect(858, 36, 3, 40); fillPath(ctx, db, rgba([90, 50, 20])); const bal = P2(); for (let x = -20; x < SW + 20; x += 8) bal.rect(x, 4, 1.4, 14); bal.rect(-20, 4, SW + 40, 2); bal.rect(-20, 18, SW + 40, 2); fillPath(ctx, bal, dark); }
  if (st === 'riad' || st === 'teaHouse') { for (let i = -3; i <= 3; i++) { if (i === 0) continue; const x = CX + i * 160; const a = P2(); cuspedArch(a, x - 40, x + 40, 14, 92, 0.5); fillPath(ctx, a, rgba(shade(wall, -0.55))); const t = P2(); for (let y = 30; y < 90; y += 8) for (let xx = x - 36; xx < x + 36; xx += 8) { t.moveTo(xx, y); t.lineTo(xx + 4, y + 4); t.lineTo(xx, y + 8); t.lineTo(xx - 4, y + 4); t.closePath(); } ctx.save(); ctx.clip(a); fillPath(ctx, t, rgba(st === 'riad' ? [40, 120, 110] : [40, 90, 160], 0.4)); ctx.restore(); } for (let k = 0; k < 9; k++) brassLantern(ctx, 120 + k * 140, 0, 12 + (k % 3) * 8, 6); }
  if (st === 'teaHouse') { for (const x of [470, 880]) { const s = P2(); s.ellipse(x, 74, 14, 12, 0, 0, TAU); s.rect(x - 6, 54, 12, 10); s.moveTo(x - 8, 54); s.quadraticCurveTo(x, 44, x + 8, 54); s.closePath(); fillPath(ctx, s, lin(ctx, x - 14, 0, x + 14, 0, [[0, '#6a4a14'], [0.5, '#e0b050'], [1, '#5a3a10']])); } }
  if (st === 'yurt') { const r = P2(); for (let k = -20; k <= 20; k++) { r.moveTo(CX, -40); r.lineTo(CX + k * 40, 80); } strokePath(ctx, r, rgba([180, 60, 50]), 2); const lat = P2(); for (let x = -20; x < SW + 20; x += 12) { lat.moveTo(x, 50); lat.lineTo(x + 12, 90); lat.moveTo(x + 12, 50); lat.lineTo(x, 90); } strokePath(ctx, lat, rgba([140, 90, 50], 0.7), 1.4); circle(ctx, CX, -10, 40, rgba([255, 220, 160], 0.6)); }
  if (st === 'lodge') { for (let y = 0; y < 96; y += 12) rect(ctx, -20, y, SW + 40, 11, lin(ctx, 0, y, 0, y + 11, [[0, '#8a5a30'], [1, '#4a2a14']])); const fp = P2(); fp.rect(CX - 200, 40, 70, 56); fillPath(ctx, fp, rgba([80, 80, 80])); glow(ctx, CX - 165, 84, 60, [255, 140, 40], 0.7, true); iconAt(ctx, 'buffalo-head', CX + 230, 60, 60, '#2a180c'); }
  if (st === 'honkyTonk') { const g = P2(); g.moveTo(CX - 280, 50); g.quadraticCurveTo(CX - 300, 30, CX - 280, 20); g.lineTo(CX - 230, 20); g.quadraticCurveTo(CX - 210, 30, CX - 230, 50); g.closePath(); g.rect(CX - 230, 32, 70, 4); additive(ctx, () => withBlur(ctx, 4, () => strokePath(ctx, g, rgba([255, 80, 120], 0.8), 4))); strokePath(ctx, g, rgba([255, 200, 220]), 1.2); const b = P2(); b.moveTo(CX + 240, 20); b.lineTo(CX + 250, 50); b.lineTo(CX + 280, 50); b.lineTo(CX + 270, 36); b.lineTo(CX + 266, 20); b.closePath(); additive(ctx, () => withBlur(ctx, 4, () => strokePath(ctx, b, rgba([80, 200, 255], 0.8), 4))); strokePath(ctx, b, rgba([200, 240, 255]), 1.2); guitarist(ctx, 520, 94, 60, dark); guitarist(ctx, 840, 94, 58, dark, { flip: true }); for (let x = 420; x < 960; x += 120) beam(ctx, x, 0, Math.PI / 2, 100, 0.4, [255, 180, 90], 0.25, { blur: 4 }); }
  if (st === 'balcony') { for (let i = -3; i <= 3; i++) { if (i === 0) continue; const x = CX + i * 170, b = P2(); b.rect(x - 50, 10, 100, 40); fillPath(ctx, b, rgba([90, 50, 26])); const lat = P2(); for (let xx = x - 46; xx < x + 46; xx += 6) lat.rect(xx, 14, 2, 32); fillPath(ctx, lat, rgba([140, 90, 50])); rect(ctx, x - 50, 50, 100, 4, rgba([60, 34, 16])); } }
  if (st === 'jiufen') { for (let y = 0; y < 96; y += 16) rect(ctx, -20, y, SW + 40, 2, rgba([60, 26, 14])); for (let x = -20; x < SW + 20; x += 90) rect(ctx, x, 0, 6, 96, rgba([60, 26, 14])); for (const y of [8, 34]) for (let x = 30 + (y % 20); x < SW; x += 70) { if (y > 30 && Math.abs(x - CX) < 60) continue; chochin(ctx, x, y, 3, 7, [220, 40, 30]); } for (const x of [470, 880]) { const tp = P2(); tp.ellipse(x, 78, 12, 8, 0, 0, TAU); tp.rect(x - 2, 66, 4, 4); tp.moveTo(x + 10, 76); tp.lineTo(x + 20, 70); tp.lineTo(x + 12, 80); tp.closePath(); fillPath(ctx, tp, rgba([110, 60, 40])); for (const k of [-24, 24]) { const cp = P2(); cp.rect(x + k - 4, 78, 8, 6); fillPath(ctx, cp, rgba([230, 220, 200])); } } }
  if (st === 'karaoke') { const sc = P2(); sc.rect(CX - 180, 6, 360, 60); fillPath(ctx, sc, lin(ctx, CX - 180, 0, CX + 180, 0, [[0, '#ff3aa0'], [0.5, '#7a3aff'], [1, '#3ad8ff']])); glow(ctx, CX, 36, 260, [200, 80, 255], 0.35, true); const ly = P2(); ly.rect(CX - 140, 48, 200, 4); ly.rect(CX - 100, 56, 200, 4); fillPath(ctx, ly, rgba([255, 255, 255], 0.9)); rect(ctx, CX - 140, 48, 90, 4, rgba([255, 230, 60])); circle(ctx, CX - 300, 20, 14, rgba([220, 220, 240])); additive(ctx, () => { for (let k = 0; k < 14; k++) { const a = k * TAU / 14; line(ctx, CX - 300, 20, CX - 300 + Math.cos(a) * 300, 20 + Math.sin(a) * 120, rgba(pick(R, [[255, 80, 200], [80, 220, 255], [255, 230, 80]]), 0.18), 1.4); } }); for (const [x, f] of [[520, false], [830, true]]) { const sg = P2(); personPath(sg, x, 94, 54, { armUp: 1 }); fillPath(ctx, sg, dark); line(ctx, x + (f ? -1 : 1) * 10, 94 - 54 * 0.86, x + (f ? -1 : 1) * 14, 94 - 54 * 0.96, rgba([200, 200, 210]), 2.4); } }
  if (st === 'distillery') { for (let y = 0; y < 96; y += 8) for (let x = (y / 8) % 2 ? -20 : -4; x < SW + 20; x += 32) rect(ctx, x, y, 30, 7, rgba(shade(wall, -0.25 - ((x * 7 + y) % 5) * 0.06))); for (const x of [380, 960]) { const s2 = P2(); s2.ellipse(x, 70, 30, 26, 0, 0, TAU); s2.moveTo(x - 6, 46); s2.lineTo(x - 4, 20); s2.quadraticCurveTo(x + 20, 4, x + 70, 18); s2.lineTo(x + 70, 22); s2.quadraticCurveTo(x + 22, 10, x + 4, 24); s2.lineTo(x + 6, 46); s2.closePath(); fillPath(ctx, s2, lin(ctx, x - 30, 0, x + 30, 0, [[0, '#6a3010'], [0.45, '#e09050'], [1, '#4a2008']])); } for (const [x0, x1] of [[60, 300], [1040, 1300]]) for (let row = 0; row < 3; row++) for (let x = x0 + row * 12; x < x1; x += 30) { const b = P2(); b.ellipse(x, 86 - row * 22, 14, 11, 0, 0, TAU); fillPath(ctx, b, lin(ctx, x - 14, 0, x + 14, 0, [[0, '#3a2010'], [0.5, '#8a5a2a'], [1, '#2a1608']])); rect(ctx, x - 14, 82 - row * 22, 28, 1.4, rgba([40, 30, 26])); } }
  // the bar itself
  if (st !== 'jazz' && st !== 'honkyTonk' && st !== 'tango') {
    const pal = { glass: [[130, 80, 30], [200, 190, 170], [60, 90, 50], [220, 230, 220]], liquid: [[190, 110, 30], [230, 200, 120], [240, 240, 240]], label: [[240, 230, 200], [200, 40, 40], [20, 60, 40]], cap: [[30, 20, 15]] };
    if (st !== 'yurt' && st !== 'riad' && st !== 'teaHouse' && st !== 'jiufen' && st !== 'distillery') { bottleRow(ctx, R, 440, 620, 82, 26, pal, { kinds: ['rum', 'whisky', 'tall', 'round'] }); bottleRow(ctx, R, 730, 940, 82, 26, pal, { kinds: ['rum', 'whisky', 'tall', 'round'] }); }
  }
  rect(ctx, -20, 84, SW + 40, 10, lin(ctx, 0, 84, 0, 94, [[0, rgba(shade(wall, -0.2))], [1, rgba(shade(wall, -0.6))]]));
  for (const x of [380, 960, 1030]) { const g = P2(); g.moveTo(x - 5, 72); g.lineTo(x + 5, 72); g.lineTo(x + 4, 84); g.lineTo(x - 4, 84); g.closePath(); fillPath(ctx, g, rgba(st === 'cantina' ? [250, 230, 160] : [255, 200, 120], 0.8)); }
  anchored(ctx, 'L', () => { glow(ctx, 70, 200, 200, P.light, 0.3, true); if (st === 'havana' || st === 'cantina' || st === 'rooftop') palm(ctx, R, 60, 340, 260, dark, { lean: 0.1 }); else if (st === 'riad' || st === 'teaHouse' || st === 'yurt') { const rug = P2(); rug.rect(20, 120, 140, 220); fillPath(ctx, rug, rgba([150, 30, 40])); const pt = P2(); for (let y = 130; y < 330; y += 20) for (let x = 30; x < 150; x += 20) { pt.moveTo(x, y); pt.lineTo(x + 10, y + 10); pt.lineTo(x, y + 20); pt.lineTo(x - 10, y + 10); pt.closePath(); } fillPath(ctx, pt, rgba([230, 180, 80], 0.6)); } else { for (const [x, y] of [[60, 300], [150, 300], [105, 222]]) { const k = P2(); k.ellipse(x, y, 44, 40, 0, 0, TAU); fillPath(ctx, k, lin(ctx, x - 44, 0, x + 44, 0, [[0, '#3a2210'], [0.5, '#8a5a2a'], [1, '#2a180a']])); } } });
  anchored(ctx, 'R', () => { glow(ctx, SW - 80, 170, 180, P.light, 0.35, true); if (st === 'riad' || st === 'teaHouse') brassLantern(ctx, SW - 100, 40, 80, 18); else if (st === 'cantina' || st === 'havana') { const g = P2(); guitarist(ctx, SW - 100, 340, 230, dark, { flip: true }); } else iconAt(ctx, 'old-microphone', SW - 110, 330, 200, dark); });
  if (st === 'riad' || st === 'teaHouse') tiles(ctx, F - 10, [40, 120, 110], [230, 220, 200], 20); else planks(ctx, F - 10, shade(wall, -0.3));
  finish(ctx, { split: 0.25, vignette: 0.5 });
};

// Casino floor. o.style: 'macau' (gold, red) | 'vegas' (neon) | 'boardwalk' (sea, pier lights)
TEMPLATES.casino = (ctx, R, o) => {
  const st = o.style || 'vegas', gold = [230, 180, 70], dark = '#0a0608';
  rect(ctx, 0, 0, SW, SH, st === 'macau' ? '#2a0606' : '#08061a');
  if (st === 'boardwalk') { skyPreset(ctx, 'blueHour', 60); water(ctx, R, 46, 60, [30, 50, 80], { n: 20 }); const pier = []; for (let x = 0; x < SW; x += 10) pier.push([x, 44, 1]); dots(ctx, pier, rgba([255, 220, 140])); }
  // chandeliers or neon signs
  if (st === 'macau') { for (const x of [CX - 280, CX + 280]) { glow(ctx, x, 16, 70, [255, 220, 150], 0.6, true); for (let k = 0; k < 18; k++) { const a = k / 18 * TAU; line(ctx, x + Math.cos(a) * 26, 14 + Math.sin(a) * 5, x + Math.cos(a) * 26, 26 + (k % 3) * 4, rgba([255, 240, 200], 0.8), 0.8); } } rect(ctx, -20, 0, SW + 40, 6, rgba(gold)); }
  else { const neon = (p, c) => { additive(ctx, () => withBlur(ctx, 5, () => strokePath(ctx, p, rgba(c, 0.85), 5))); strokePath(ctx, p, rgba(mix(c, [255, 255, 255], 0.7)), 1.4); };
    const star = P2(); for (let k = 0; k < 10; k++) { const a = -Math.PI / 2 + k * Math.PI / 5, r = k % 2 ? 8 : 20; (k ? star.lineTo.bind(star) : star.moveTo.bind(star))(CX - 260 + Math.cos(a) * r, 34 + Math.sin(a) * r); } star.closePath(); neon(star, [255, 220, 60]);
    const cards = P2(); for (const [x, y] of [[CX + 240, 24], [CX + 270, 30]]) cards.rect(x, y, 22, 30); neon(cards, [255, 60, 140]);
    const dice = P2(); dice.rect(CX - 40, 6, 30, 30); dice.rect(CX + 10, 6, 30, 30); neon(dice, [80, 220, 255]); }
  // slot machines along the back, roulette and tables in the hero zones
  for (let x = -20; x < SW + 20; x += 34) { if (x > DEALER[0] - 40 && x < DEALER[1] + 20) continue; const p = P2(); p.rect(x, 40, 28, 52); fillPath(ctx, p, lin(ctx, x, 0, x + 28, 0, [[0, '#2a2a3a'], [0.5, '#5a5a70'], [1, '#1a1a26']])); rect(ctx, x + 4, 46, 20, 14, rgba(pick(R, [[255, 60, 120], [80, 220, 255], [255, 200, 60], [120, 255, 140]]), 0.85)); glow(ctx, x + 14, 50, 14, [255, 230, 180], 0.3, true); rect(ctx, x + 2, 36, 24, 4, rgba(st === 'macau' ? gold : [255, 80, 160])); }
  for (const x of [520, 840]) { const rw = P2(); rw.ellipse(x, 84, 40, 10, 0, 0, TAU); fillPath(ctx, rw, rgba([20, 90, 40])); const wh = P2(); wh.ellipse(x, 80, 18, 5, 0, 0, TAU); fillPath(ctx, wh, rgba([120, 20, 20])); const sp = []; for (let k = 0; k < 12; k++) { const a = k / 12 * TAU; sp.push([x + Math.cos(a) * 15, 80 + Math.sin(a) * 4, 1]); } dots(ctx, sp, rgba(gold)); const chips = []; for (let k = 0; k < 10; k++) chips.push([x + between(R, -30, 30), 86 + between(R, -2, 2), 2.4]); dots(ctx, chips, rgba(pick(R, [[230, 40, 40], [40, 80, 220], [240, 240, 240]]))); }
  crowd(ctx, R, -10, SW + 10, 96, 12, dark, { hands: 0.15 });
  anchored(ctx, 'L', () => { glow(ctx, 80, 160, 200, st === 'macau' ? [255, 200, 100] : [255, 80, 160], 0.4, true); for (const [x, y] of [[60, 220], [130, 260]]) { const p = P2(); p.rect(x - 30, y - 60, 60, 120); fillPath(ctx, p, lin(ctx, x - 30, 0, x + 30, 0, [[0, '#2a2a3a'], [0.5, '#6a6a80'], [1, '#1a1a26']])); rect(ctx, x - 22, y - 50, 44, 30, rgba([255, 200, 60], 0.85)); } });
  anchored(ctx, 'R', () => { glow(ctx, SW - 80, 160, 200, st === 'macau' ? [255, 200, 100] : [80, 220, 255], 0.4, true); const chips = []; for (let k = 0; k < 8; k++) chips.push([SW - 100, 300 - k * 10, 30]); for (const [x, y, r] of chips) { const c = P2(); c.ellipse(x, y, r, r * 0.3, 0, 0, TAU); fillPath(ctx, c, rgba(k2c(y))); } function k2c(y) { return [[230, 40, 40], [40, 80, 220], [240, 240, 240], [30, 30, 30]][Math.round(y / 10) % 4]; } });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, st === 'macau' ? '#6a1010' : '#2a1040'], [1, '#060408']]));
  const pat = P2(); for (let x = 0; x < SW; x += 40) for (let y = F; y < SH; y += 40) { pat.moveTo(x, y); pat.lineTo(x + 20, y + 20); pat.lineTo(x, y + 40); pat.lineTo(x - 20, y + 20); pat.closePath(); } strokePath(ctx, pat, rgba(gold, 0.35), 1);
  finish(ctx, { split: 0.2, vignette: 0.5 });
};

// ---------- sport ----------
// A fight ring. o.style: 'muayThai' | 'lucha' | 'boxing'
TEMPLATES.fightRing = (ctx, R, o) => {
  const st = o.style || 'boxing', dark = '#08060a', ropeC = st === 'lucha' ? [[230, 40, 120], [250, 200, 40], [40, 160, 220]] : [[230, 40, 40], [240, 240, 240], [40, 80, 220]];
  rect(ctx, 0, 0, SW, SH, '#060508');
  stands(ctx, R, 10, 70, st === 'lucha' ? [[255, 255, 255], [230, 40, 120], [250, 200, 40]] : [[255, 255, 255], [230, 60, 60], [60, 120, 220]], { alpha: 0.55 });
  for (const x of [CX - 200, CX, CX + 200]) beam(ctx, x, 0, Math.PI / 2, 110, 0.4, [255, 250, 235], 0.22, { blur: 4 });
  const posts = P2(); for (const x of [CX - 340, CX + 340]) posts.rect(x - 4, 40, 8, 56); fillPath(ctx, posts, rgba(st === 'lucha' ? [250, 200, 40] : [200, 200, 210]));
  ropeC.forEach((c, i) => { const r = P2(); r.moveTo(CX - 340, 50 + i * 12); r.quadraticCurveTo(CX, 54 + i * 12, CX + 340, 50 + i * 12); strokePath(ctx, r, rgba(c), 2.4); });
  rect(ctx, CX - 360, 90, 720, 8, rgba(st === 'lucha' ? [40, 60, 160] : [30, 30, 40]));
  const f1 = P2(); personPath(f1, CX - 140, 92, 62, { armUp: 1 }); fillPath(ctx, f1, dark); const f2 = P2(); personPath(f2, CX + 140, 92, 60, { armUp: st === 'muayThai' ? 0 : 1 }); fillPath(ctx, f2, dark);
  if (st === 'muayThai') { line(ctx, CX + 140, 60, CX + 100, 40, dark, 6); const mk = P2(); mk.ellipse(CX - 140, 34, 8, 2, 0, 0, TAU); fillPath(ctx, mk, rgba([230, 40, 40])); }
  if (st === 'lucha') for (const [x, c] of [[CX - 140, [230, 40, 120]], [CX + 140, [250, 200, 40]]]) { circle(ctx, x, 92 - 62 * 0.88, 62 * 0.075, rgba(c)); }
  if (st === 'boxing') for (const x of [CX - 128, CX + 128]) circle(ctx, x, 50, 5, rgba([200, 30, 30]));
  crowd(ctx, R, -10, SW + 10, 98, 13, dark, { hands: 0.4 });
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, ropeC[0], 0.3, true); const p = P2(); personPath(p, 90, 340, 240, { armUp: 2 }); fillPath(ctx, p, dark); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, ropeC[2], 0.3, true); const p = P2(); personPath(p, SW - 90, 340, 240, { armUp: 1 }); fillPath(ctx, p, dark); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#1a1622'], [1, '#040306']]));
  finish(ctx, { split: 0.25, vignette: 0.5 });
};

// Basketball on an outdoor court under palms and string lights.
TEMPLATES.streetCourt = (ctx, R, o) => {
  const dark = '#0a0a0c';
  skyPreset(ctx, 'pinkDusk'); ground(ctx, ['#8a7a6a', '#2a241c', '#0a0806']);
  for (let x = 30; x < SW; x += between(R, 60, 120)) palm(ctx, R, x, 84, between(R, 40, 60), rgba([20, 26, 24]));
  const roof = P2(); for (let x = -20; x < SW + 20; x += 40) { roof.rect(x, 60, 36, 24); roof.moveTo(x - 2, 60); roof.lineTo(x + 18, 50); roof.lineTo(x + 38, 60); roof.closePath(); } fillPath(ctx, roof, rgba([40, 36, 40]));
  stringLights(ctx, 0, 30, CX - 50, 26, 14, 14, [255, 200, 120], 1.5); stringLights(ctx, CX + 50, 26, SW, 30, 14, 14, [255, 200, 120], 1.5);
  rect(ctx, -20, 84, SW + 40, 14, rgba([60, 90, 120]));
  for (const gx of [380, 980]) { const h = P2(); h.rect(gx - 1.5, 36, 3, 60); h.rect(gx - 16, 30, 32, 20); fillPath(ctx, h, rgba([230, 230, 235], 0.9)); const r = P2(); r.ellipse(gx, 52, 9, 2.6, 0, 0, TAU); strokePath(ctx, r, rgba([255, 120, 30]), 1.6); }
  for (const [x, f, up] of [[470, false, 1], [540, false, 0], [610, true, 0], [760, false, 0], [830, true, 1], [900, true, 0]]) player(ctx, 'basketball', x, 96, 50, dark, { flip: f, armUp: up });
  circle(ctx, 486, 36, 4, rgba([230, 110, 40]));
  anchored(ctx, 'L', () => { palm(ctx, R, 40, 340, 280, dark, { lean: 0.3 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 70, 200, 160, [255, 190, 110], 0.3, true); const p = P2(); personPath(p, SW - 100, 330, 220, { armUp: 2 }); fillPath(ctx, p, dark); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#3a5a7a'], [1, '#08101a']]));
  rect(ctx, 0, F + 30, SW, 3, rgba([255, 255, 255], 0.5));
  finish(ctx, { split: 0.3 });
};

// On the water. o.kind: 'surf' | 'sailing' (foiling catamarans) | 'kitesurf' | 'yoles'
TEMPLATES.waterSport = (ctx, R, o) => {
  const kind = o.kind || 'surf', dark = '#06080c';
  skyPreset(ctx, kind === 'surf' ? 'golden' : 'day'); ground(ctx, ['#2a7aa0', '#103a5a', '#04121e']);
  sunDisc(ctx, CX + 260, 50, 18, [255, 140, 60], [255, 220, 150], 56);
  water(ctx, R, 56, 100, [40, 120, 160], { n: 80 }); reflection(ctx, R, CX + 260, 57, 90, [255, 210, 140], 60, 0.4);
  if (kind === 'surf') { for (const [x0, h] of [[-20, 30], [520, 26]]) { const wv = P2(); wv.moveTo(x0, 96); wv.quadraticCurveTo(x0 + 120, 96, x0 + 220, 96 - h); wv.quadraticCurveTo(x0 + 280, 96 - h * 1.3, x0 + 300, 96 - h * 0.6); wv.quadraticCurveTo(x0 + 380, 90, x0 + 520, 96); wv.closePath(); fillPath(ctx, wv, lin(ctx, 0, 96 - h * 1.3, 0, 96, [[0, '#7ac8e0'], [1, '#1a6a90']])); const fo = P2(); fo.moveTo(x0 + 200, 96 - h * 0.9); fo.quadraticCurveTo(x0 + 270, 96 - h * 1.4, x0 + 300, 96 - h * 0.6); strokePath(ctx, fo, rgba([255, 255, 255], 0.85), 2.4); } for (const [x, y, f] of [[640, 62, false], [430, 76, false], [990, 70, true]]) surfer(ctx, x, y, 28, dark, { flip: f }); }
  if (kind === 'sailing') for (const [x, s, c] of [[500, 60, [220, 40, 40]], [820, 56, [40, 80, 200]]]) { const h = P2(); h.moveTo(x - s * 0.7, 74); h.lineTo(x + s * 0.7, 74); h.lineTo(x + s * 0.5, 78); h.lineTo(x - s * 0.5, 78); h.closePath(); h.rect(x - 1, 74, 2, 14); fillPath(ctx, h, dark); const sl = P2(); sl.moveTo(x, 72); sl.quadraticCurveTo(x + s * 0.3, 40, x + 2, 4); sl.lineTo(x - s * 0.5, 70); sl.closePath(); fillPath(ctx, sl, rgba(c)); rect(ctx, x - 1, 4, 2, 70, rgba([20, 20, 20])); const sp = []; for (let k = 0; k < 20; k++) sp.push([x - s + between(R, -20, 0), 86 + between(R, -3, 3), 1.4]); dots(ctx, sp, rgba([255, 255, 255], 0.7)); }
  if (kind === 'kitesurf') for (const [x, kx, c] of [[520, 470, [255, 80, 40]], [840, 900, [40, 200, 160]], [960, 1010, [250, 200, 40]]]) { surfer(ctx, x, 86, 24, dark); const k = P2(); k.moveTo(kx - 30, 26); k.quadraticCurveTo(kx, 6, kx + 30, 26); k.lineTo(kx + 24, 30); k.quadraticCurveTo(kx, 14, kx - 24, 30); k.closePath(); fillPath(ctx, k, rgba(c)); line(ctx, kx - 24, 30, x, 74, rgba([20, 20, 20], 0.6), 0.6); line(ctx, kx + 24, 30, x, 74, rgba([20, 20, 20], 0.6), 0.6); }
  if (kind === 'yoles') for (const [x, c] of [[480, [240, 60, 60]], [600, [250, 200, 40]], [800, [40, 120, 220]], [920, [60, 180, 100]]]) { const h = P2(); h.moveTo(x - 30, 80); h.lineTo(x + 30, 80); h.lineTo(x + 24, 86); h.lineTo(x - 24, 86); h.closePath(); fillPath(ctx, h, dark); const sl = P2(); sl.moveTo(x, 78); sl.lineTo(x + 2, 20); sl.lineTo(x + 34, 74); sl.closePath(); fillPath(ctx, sl, rgba(c)); const cr = P2(); for (let k = 0; k < 4; k++) { const px = x - 30 + k * 10; personPath(cr, px - 14, 82, 16); cr.rect(px - 30, 78, 20, 1.4); } fillPath(ctx, cr, dark); }
  anchored(ctx, 'L', () => { iconAt(ctx, 'palm-tree', 60, 340, 280, dark); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 70, 200, 160, [255, 200, 120], 0.3, true); if (kind === 'surf') { const b = P2(); b.ellipse(SW - 100, 200, 30, 140, 0.15, 0, TAU); fillPath(ctx, b, rgba([240, 220, 180])); line(ctx, SW - 118, 70, SW - 82, 330, rgba([220, 60, 40]), 4); } });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#e0c890'], [1, '#2a2418']]));
  finish(ctx, { split: 0.3 });
};

// ---------- wild ----------
// A parade at night. o.style: 'carnival' | 'samba' | 'muertos'
TEMPLATES.parade = (ctx, R, o) => {
  const st = o.style || 'carnival', dark = '#0a0608';
  skyPreset(ctx, 'warmNight'); ground(ctx, ['#3a2030', '#160a10', '#060404']);
  stars(ctx, R, 60, [0, 0, SW, 30], { alpha: 0.6 });
  if (st === 'muertos') {
    for (let k = 0; k < 3; k++) { const y = 6 + k * 12; for (let x = 0; x < SW; x += 24) { const f = P2(); f.rect(x, y, 18, 10); f.moveTo(x, y + 10); for (let j = 0; j < 4; j++) f.lineTo(x + j * 4.5 + 2.25, y + 13); f.lineTo(x + 18, y + 10); fillPath(ctx, f, rgba(pick(R, [[230, 40, 120], [250, 200, 40], [40, 160, 220], [120, 200, 60], [240, 110, 40]]), 0.85)); } }
    const cand = []; for (let i = 0; i < 140; i++) cand.push([between(R, 0, SW), between(R, 70, 96)]); for (const [x, y] of cand.slice(0, 50)) glow(ctx, x, y, 10, [255, 170, 60], 0.35, true); dots(ctx, cand.map(([x, y]) => [x, y, 1.2]), rgba([255, 220, 140]));
    const mg = []; for (let i = 0; i < 300; i++) mg.push([between(R, 0, SW), between(R, 84, 98), between(R, 1.6, 3)]); dots(ctx, mg, rgba([250, 140, 20]));
    for (const x of [500, 860]) { const sk = P2(); sk.ellipse(x, 52, 24, 26, 0, 0, TAU); sk.rect(x - 14, 70, 28, 10); fillPath(ctx, sk, rgba([240, 236, 226])); for (const k of [-1, 1]) { circle(ctx, x + k * 9, 50, 6, rgba([20, 10, 20])); circle(ctx, x + k * 9, 50, 2.4, rgba([230, 40, 120])); } const nz = P2(); nz.moveTo(x, 58); nz.lineTo(x - 3, 64); nz.lineTo(x + 3, 64); nz.closePath(); fillPath(ctx, nz, rgba([20, 10, 20])); const fl = []; for (let k = 0; k < 8; k++) { const a = Math.PI + k * Math.PI / 7; fl.push([x + Math.cos(a) * 22, 44 + Math.sin(a) * 20, 3.4]); } dots(ctx, fl, rgba([250, 140, 20])); }
  } else {
    const cols = st === 'samba' ? [[40, 200, 80], [255, 220, 40], [40, 120, 255], [255, 255, 255]] : [[255, 60, 120], [255, 200, 40], [60, 200, 255], [160, 60, 255]];
    for (const [x, c] of [[480, cols[0]], [860, cols[1]]]) { const fl = P2(); fl.moveTo(x - 140, 96); fl.lineTo(x - 120, 60); fl.lineTo(x + 120, 60); fl.lineTo(x + 140, 96); fl.closePath(); fillPath(ctx, fl, lin(ctx, 0, 60, 0, 96, [[0, rgba(c)], [1, rgba(shade(c, -0.5))]])); const lt = []; for (let k = 0; k < 30; k++) lt.push([x - 120 + k * 8, 62, 1.4]); dots(ctx, lt, rgba([255, 240, 200])); }
    for (let k = 0; k < 10; k++) { const x = 440 + k * 52 + (k > 4 ? 30 : 0); if (x > DEALER[0] - 10 && x < DEALER[1] + 10) continue; const c = cols[k % cols.length]; const fan = P2(); for (let j = -6; j <= 6; j++) { const a = -Math.PI / 2 + j * 0.2; fan.moveTo(x, 70); fan.lineTo(x + Math.cos(a) * 36, 70 + Math.sin(a) * 36); } strokePath(ctx, fan, rgba(c, 0.9), 3); const d2 = P2(); dancer(ctx, x, 96, 36, dark, { armUp: 2 }); }
    const cf = [[], []]; for (let i = 0; i < 220; i++) cf[i % 2].push([between(R, 0, SW), between(R, 0, 100), between(R, 0.8, 1.6)]); dots(ctx, cf[0], rgba(cols[0], 0.9)); dots(ctx, cf[1], rgba(cols[1], 0.9));
  }
  crowd(ctx, R, -10, SW + 10, 98, 12, dark, { hands: 0.4 });
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, [255, 120, 160], 0.35, true); const p = P2(); dancer(ctx, 90, 340, 240, dark, { armUp: 2 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, [255, 200, 80], 0.35, true); const p = P2(); dancer(ctx, SW - 90, 340, 240, dark, { armUp: 1 }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#3a2030'], [1, '#060404']]));
  finish(ctx, { split: 0.25 });
};

// Observatory domes on a ridge under the Milky Way.
TEMPLATES.observatory = (ctx, R, o) => {
  skyPreset(ctx, 'deepNight'); ground(ctx, ['#3a2a2a', '#140c0c', '#060404']);
  stars(ctx, R, 300, [0, 0, SW, 80], { bright: 10, size: 0.85 }); milkyWay(ctx, R, 200, -30, 1150, 100, 50);
  const rg = P2(); rg.moveTo(-20, 98); rg.quadraticCurveTo(300, 70, 600, 72); rg.quadraticCurveTo(900, 70, SW + 20, 96); rg.closePath(); fillPath(ctx, rg, rgba([30, 20, 22]));
  for (const [x, r] of [[470, 16], [560, 22], [800, 26], [900, 18]]) { const d = P2(); d.arc(x, 72, r, Math.PI, 0); d.closePath(); d.rect(x - r, 72, r * 2, 8); fillPath(ctx, d, lin(ctx, x - r, 0, x + r, 0, [[0, '#a0a4b4'], [1, '#3a3c48']])); rect(ctx, x - 2, 72 - r, 4, r, rgba([10, 10, 16])); }
  additive(ctx, () => line(ctx, 800, 48, 700, -20, rgba([60, 255, 80], 0.6), 1));
  anchored(ctx, 'L', () => { glow(ctx, 60, 220, 160, [255, 80, 60], 0.15, true); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 220, 160, [255, 80, 60], 0.15, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#2a1c1c'], [1, '#040202']]));
  finish(ctx, { split: 0.1 });
};

// Desert night: buttes or cactus flats under the Milky Way. o.land: 'buttes' | 'cactus'
TEMPLATES.desertNight = (ctx, R, o) => {
  const dark = '#0a0608';
  skyPreset(ctx, 'deepNight'); ground(ctx, ['#4a2a22', '#1a0e0c', '#060404']);
  stars(ctx, R, 260, [0, 0, SW, 84], { bright: 8, size: 0.85 }); milkyWay(ctx, R, 300, -30, 1050, 100, 44);
  if (o.land === 'dunes') { for (const [y, c] of [[78, [70, 40, 34]], [88, [50, 28, 24]]]) { const d = P2(); d.moveTo(-20, 100); for (let x = -20; x <= SW + 20; x += 20) d.lineTo(x, y - Math.abs(Math.sin(x * 0.006 + y)) * 14); d.lineTo(SW + 20, 100); d.closePath(); fillPath(ctx, d, rgba(c)); } for (const [x, f] of [[460, false], [520, false], [580, false], [820, true], [880, true]]) iconAt(ctx, 'camel', x, 92, 34, dark, { flip: f }); for (const x of [380, 960]) { const t = P2(); t.moveTo(x - 30, 92); t.lineTo(x, 74); t.lineTo(x + 30, 92); t.closePath(); fillPath(ctx, t, rgba([90, 50, 40])); glow(ctx, x, 88, 30, [255, 170, 80], 0.5, true); } }
  else if (o.land === 'buttes') { const b = P2(); for (const [x, w, h] of [[300, 70, 50], [520, 40, 64], [880, 90, 46], [1060, 40, 58]]) { b.moveTo(x - w * 0.8, 92); b.lineTo(x - w * 0.5, 92 - h * 0.5); b.lineTo(x - w * 0.42, 92 - h); b.lineTo(x + w * 0.42, 92 - h); b.lineTo(x + w * 0.5, 92 - h * 0.5); b.lineTo(x + w * 0.8, 92); b.closePath(); } fillPath(ctx, b, rgba([40, 20, 20])); }
  else { mesas(ctx, R, 90, rgba([36, 22, 24])); const cac = P2(); for (const x of [420, 560, 800, 940, 1060]) { const h = between(R, 26, 46); cac.rect(x - 3, 96 - h, 6, h); cac.rect(x - 12, 96 - h * 0.7, 4, h * 0.3); cac.rect(x - 12, 96 - h * 0.45, 12, 4); cac.rect(x + 8, 96 - h * 0.8, 4, h * 0.35); cac.rect(x, 96 - h * 0.5, 12, 4); } fillPath(ctx, cac, dark); }
  glow(ctx, CX + 180, 92, 60, [255, 140, 60], 0.4, true);
  anchored(ctx, 'L', () => { glow(ctx, 60, 220, 160, [255, 140, 60], 0.15, true); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 220, 160, [255, 140, 60], 0.15, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#2a1814'], [1, '#040202']]));
  finish(ctx, { split: 0.15 });
};

// Sea stacks or arches at sunset. o.arches
TEMPLATES.seaRocks = (ctx, R, o) => {
  skyPreset(ctx, o.sky || 'pinkDusk'); ground(ctx, ['#3a6a8a', '#14304a', '#060e18']);
  sunDisc(ctx, CX - 240, 60, 20, [255, 120, 60], [255, 210, 140], 66);
  water(ctx, R, 66, 100, [40, 90, 130], { n: 60 }); reflection(ctx, R, CX - 240, 67, 96, [255, 200, 130], 50, 0.45);
  const rk = P2();
  const shape = o.shape || 'stack';
  if (shape === 'karst' || shape === 'pitons' || shape === 'basalt') {
    const list = shape === 'pitons' ? [[880, 60, 84], [1010, 46, 70], [380, 30, 30]] : shape === 'basalt' ? [[300, 50, 34], [420, 30, 46], [880, 70, 40], [1000, 26, 52]] : [[300, 22, 50], [380, 30, 64], [470, 18, 40], [860, 26, 70], [940, 34, 56], [1040, 20, 44]];
    for (const [x, w, h] of list) { if (shape === 'basalt') { rk.moveTo(x - w, 98); rk.lineTo(x - w * 0.9, 98 - h); rk.lineTo(x + w * 0.9, 98 - h); rk.lineTo(x + w, 98); rk.closePath(); } else { rk.moveTo(x - w, 98); rk.quadraticCurveTo(x - w * 0.7, 98 - h * 0.7, x - w * 0.25, 98 - h); rk.quadraticCurveTo(x, 98 - h * 1.06, x + w * 0.25, 98 - h); rk.quadraticCurveTo(x + w * 0.7, 98 - h * 0.7, x + w, 98); rk.closePath(); } }
  } else
  for (const [x, w, h] of [[440, 40, 60], [560, 26, 44], [800, 50, 70], [920, 30, 40]]) { if (o.arches && x === 800) { rk.moveTo(x - w, 98); rk.lineTo(x - w * 0.8, 98 - h); rk.quadraticCurveTo(x, 98 - h * 1.1, x + w * 0.8, 98 - h); rk.lineTo(x + w, 98); rk.lineTo(x + w * 0.4, 98); rk.quadraticCurveTo(x, 98 - h * 0.6, x - w * 0.4, 98); rk.closePath(); } else { rk.moveTo(x - w, 98); rk.lineTo(x - w * 0.7, 98 - h); rk.quadraticCurveTo(x, 98 - h * 1.08, x + w * 0.7, 98 - h); rk.lineTo(x + w, 98); rk.closePath(); } }
  fillPath(ctx, rk, lin(ctx, 0, 30, 0, 98, [[0, rgba(o.rockC || [200, 130, 90])], [1, rgba([60, 40, 40])]]));
  if (shape === 'basalt') { const cl = P2(); for (let x = 240; x < 1040; x += 6) { cl.moveTo(x, 50); cl.lineTo(x, 98); } ctx.save(); ctx.clip(rk); strokePath(ctx, cl, rgba([20, 20, 26], 0.35), 1); ctx.restore(); }
  if (shape === 'karst' || shape === 'pitons') { ctx.save(); ctx.clip(rk); const gr = []; for (let i = 0; i < 400; i++) gr.push([between(R, 260, 1100), between(R, 14, 80), between(R, 2, 5)]); dots(ctx, gr, rgba([40, 80, 40], 0.75)); ctx.restore(); }
  const sf = P2(); for (let x = -20; x < SW + 20; x += 20) { sf.moveTo(x, 94); sf.quadraticCurveTo(x + 10, 90, x + 20, 94); } strokePath(ctx, sf, rgba([255, 255, 255], 0.5), 1.2);
  birds(ctx, R, 380, 10, 980, 40, 7, rgba([30, 20, 24], 0.8), 4);
  anchored(ctx, 'L', () => { const c = P2(); c.moveTo(-20, 340); c.lineTo(-20, 60); c.quadraticCurveTo(80, 80, 120, 200); c.lineTo(160, 340); c.closePath(); fillPath(ctx, c, '#1a1210'); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 70, 200, 160, [255, 190, 120], 0.25, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, o.sand ? '#e8c8c0' : '#1c3a50'], [1, '#04080c']]));
  finish(ctx, { split: 0.3 });
};

// A bay glowing blue at night, kayaks drawing light. o.mode 'bio'
TEMPLATES.glowBay = (ctx, R, o) => {
  const dark = '#04060a';
  skyPreset(ctx, 'night'); ground(ctx, ['#0a1a2a', '#040a12', '#020408']);
  stars(ctx, R, 220, [0, 0, SW, 60], { bright: 6 }); milkyWay(ctx, R, 200, -30, 1100, 70, 40);
  forestLine(ctx, R, 70, 16, rgba([8, 12, 14])); for (let x = 40; x < SW; x += between(R, 60, 120)) palm(ctx, R, x, 70, between(R, 30, 44), rgba([6, 10, 12]));
  rect(ctx, 0, 70, SW, 30, lin(ctx, 0, 70, 0, 100, [[0, '#0a2a3c'], [1, '#04121c']]));
  additive(ctx, () => { const t = P2(); for (let i = 0; i < 220; i++) { const x = between(R, 0, SW), y = between(R, 72, 98); t.moveTo(x, y); t.lineTo(x + between(R, 4, 20), y + between(R, -1, 1)); } strokePath(ctx, t, rgba([60, 220, 255], 0.75), 1.6); glow(ctx, CX, 86, 500, [40, 200, 255], 0.25); });
  moon(ctx, 1040, 18, 8, { halo: 6 });
  for (const [x, f] of [[480, false], [860, true]]) { canoe(ctx, x, 86, 26, dark, { crew: 2 }); additive(ctx, () => { const tr = P2(); tr.moveTo(x - (f ? -1 : 1) * 26, 86); tr.quadraticCurveTo(x - (f ? -1 : 1) * 70, 90, x - (f ? -1 : 1) * 130, 88); strokePath(ctx, tr, rgba([80, 230, 255], 0.8), 2.4); glow(ctx, x, 88, 30, [60, 220, 255], 0.4); }); }
  anchored(ctx, 'L', () => { palm(ctx, R, 40, 340, 280, dark, { lean: 0.3 }); });
  anchored(ctx, 'R', () => { palm(ctx, R, SW - 50, 340, 260, dark, { lean: -0.3 }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#061420'], [1, '#020408']]));
  additive(ctx, () => { const t = P2(); for (let i = 0; i < 60; i++) { const x = between(R, 0, SW), y = between(R, F, SH); t.moveTo(x, y); t.lineTo(x + between(R, 10, 40), y); } strokePath(ctx, t, rgba([60, 220, 255], 0.3), 1.2); });
  finish(ctx, { split: 0.1 });
};

// Musicians around a fire in the desert (desert blues).
TEMPLATES.campfireBand = (ctx, R, o) => {
  const dark = '#08050a';
  skyPreset(ctx, 'deepNight'); ground(ctx, ['#4a2a20', '#1a0e0a', '#060404']);
  stars(ctx, R, 240, [0, 0, SW, 80], { bright: 8 }); milkyWay(ctx, R, 900, -30, 1300, 90, 30);
  ridge(ctx, R, 90, 16, rgba([30, 18, 20]), { bottom: 100 });
  for (const x of [380, 1000]) { const t = P2(); t.moveTo(x - 40, 94); t.lineTo(x - 30, 70); t.lineTo(x + 30, 70); t.lineTo(x + 40, 94); t.closePath(); fillPath(ctx, t, rgba([60, 30, 30])); }
  glow(ctx, CX - 180, 88, 120, [255, 140, 50], 0.7, true); glow(ctx, CX + 180, 88, 120, [255, 140, 50], 0.7, true);
  for (const fx of [CX - 180, CX + 180]) { const f = P2(); f.moveTo(fx - 10, 96); f.quadraticCurveTo(fx - 14, 80, fx, 66); f.quadraticCurveTo(fx + 14, 80, fx + 10, 96); f.closePath(); additive(ctx, () => fillPath(ctx, f, lin(ctx, 0, 66, 0, 96, [[0, rgba([255, 240, 170], 0.3)], [1, rgba([255, 120, 30], 0.9)]]))); }
  for (const [x, f] of [[440, false], [520, false], [600, true], [760, false], [850, true], [920, true]]) { guitarist(ctx, x, 96, 46, dark, { flip: f }); const tb = P2(); tb.moveTo(x - 7, 96 - 46 * 0.94); tb.quadraticCurveTo(x, 96 - 46 * 1.06, x + 7, 96 - 46 * 0.94); tb.closePath(); fillPath(ctx, tb, rgba([40, 60, 140])); }
  rimIcon(ctx, 'camel', 1100, 96, 40, dark, [255, 150, 70], { flip: true });
  anchored(ctx, 'L', () => { glow(ctx, 60, 220, 160, [255, 140, 60], 0.3, true); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 220, 160, [255, 140, 60], 0.3, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#3a2018'], [1, '#040202']]));
  glow(ctx, CX, F, 400, [255, 130, 50], 0.18, true);
  finish(ctx, { split: 0.15 });
};
