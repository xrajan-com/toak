// Bars, pubs and casinos.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

// ---------- bottles (from the first bar prototypes) ----------
const BOTTLES = ['wine', 'whisky', 'gin', 'round', 'champagne', 'rum', 'tall', 'decanter'];
function bottlePath(kind, x, base, h) {
  const p = P2(); const w = h * ({ wine: .26, whisky: .36, gin: .32, round: .42, champagne: .30, rum: .38, tall: .22, decanter: .46, sake: .34 }[kind]);
  const nw = w * ({ wine: .30, whisky: .34, gin: .36, round: .26, champagne: .30, rum: .38, tall: .36, decanter: .22, sake: .3 }[kind]);
  const sh = h * ({ wine: .55, whisky: .66, gin: .70, round: .52, champagne: .52, rum: .62, tall: .62, decanter: .50, sake: .58 }[kind]);
  const l = x - w / 2, r = x + w / 2, top = base - h;
  if (kind === 'round' || kind === 'decanter') {
    const cy = base - sh * 0.48, rr = Math.min(w / 2, sh * 0.5);
    p.moveTo(x - nw / 2, top); p.lineTo(x - nw / 2, cy - rr * 0.9); p.quadraticCurveTo(l, cy - rr * 0.8, l, cy);
    p.quadraticCurveTo(l, base, x, base); p.quadraticCurveTo(r, base, r, cy); p.quadraticCurveTo(r, cy - rr * 0.8, x + nw / 2, cy - rr * 0.9);
    p.lineTo(x + nw / 2, top); p.closePath();
  } else {
    const shoulder = base - sh, curve = (kind === 'whisky' || kind === 'gin' || kind === 'rum') ? h * 0.06 : h * 0.16;
    p.moveTo(x - nw / 2, top); p.lineTo(x - nw / 2, shoulder - curve); p.quadraticCurveTo(l, shoulder - curve * 0.4, l, shoulder);
    p.lineTo(l, base - h * 0.02); p.quadraticCurveTo(l, base, l + w * 0.1, base); p.lineTo(r - w * 0.1, base); p.quadraticCurveTo(r, base, r, base - h * 0.02);
    p.lineTo(r, shoulder); p.quadraticCurveTo(r, shoulder - curve * 0.4, x + nw / 2, shoulder - curve); p.lineTo(x + nw / 2, top); p.closePath();
  }
  return { p, w, nw, sh, l, r, top };
}
function bottle(ctx, x, base, h, kind, glass, liquid, label, o = {}) {
  const b = bottlePath(kind, x, base, h);
  ctx.fillStyle = lin(ctx, b.l, 0, b.r, 0, [[0, rgba(mix(glass, [0, 0, 0], .45), .95)], [.35, rgba(glass, .92)], [1, rgba(mix(glass, [0, 0, 0], .6), .95)]]);
  ctx.fill(b.p);
  ctx.save(); ctx.clip(b.p);
  const lvl = base - b.sh * (o.level ?? 0.85);
  rect(ctx, b.l - 2, lvl, b.w + 4, base - lvl, lin(ctx, 0, lvl, 0, base, [[0, rgba(liquid, .85)], [1, rgba(mix(liquid, [0, 0, 0], .5), .95)]]));
  if (label) { const ly = base - b.sh * .62, lh = b.sh * .34; rect(ctx, b.l, ly, b.w, lh, rgba(label, .92)); }
  rect(ctx, b.l, b.top, b.w * 0.3, h, lin(ctx, b.l, 0, b.l + b.w * 0.3, 0, [[0, 'rgba(255,255,255,0)'], [0.6, 'rgba(255,255,255,0.32)'], [1, 'rgba(255,255,255,0)']]));
  ctx.restore();
  rect(ctx, x - b.nw / 2 - 0.5, b.top - 0.5, b.nw + 1, h * (kind === 'champagne' ? .2 : .08), o.cap ? rgba(o.cap) : '#1a1110');
}
function bottleRow(ctx, R, x0, x1, base, h, pal, o = {}) {
  let x = x0 + h * 0.2;
  while (x < x1 - h * 0.2) {
    if (o.skip && x > o.skip[0] && x < o.skip[1]) { x = o.skip[1]; continue; }
    const kinds = o.kinds || BOTTLES, kind = pick(R, kinds);
    const hh = h * (0.72 + R() * 0.28) * (kind === 'round' || kind === 'decanter' ? .8 : 1);
    bottle(ctx, x, base, hh, kind, pick(R, pal.glass), pick(R, pal.liquid), R() < 0.8 ? pick(R, pal.label) : null, { level: 0.5 + R() * 0.45, cap: pick(R, pal.cap || [[30, 20, 18]]) });
    x += hh * (kind === 'round' || kind === 'decanter' ? .52 : .40) + R() * h * 0.08;
  }
}
function shelf(ctx, x0, x1, y, t, top, front) {
  rect(ctx, x0, y, x1 - x0, t * .35, rgba(top));
  rect(ctx, x0, y + t * .35, x1 - x0, t * .65, lin(ctx, 0, y + t * .35, 0, y + t, [[0, rgba(front)], [1, rgba(mix(front, [0, 0, 0], .5))]]));
  rect(ctx, x0, y + t, x1 - x0, t * .6, 'rgba(0,0,0,.45)');
}
function backlight(ctx, x0, x1, y, hgt, c, a) { rect(ctx, x0, y - hgt, x1 - x0, hgt, lin(ctx, 0, y - hgt, 0, y, [[0, rgba(c, 0)], [1, rgba(c, a)]])); }
function drape(ctx, x, top, w, h, c, o = {}) {
  const d = o.side || 1, p = P2();
  p.moveTo(x, top); p.lineTo(x + d * w, top); p.quadraticCurveTo(x + d * w * 0.55, top + h * 0.45, x + d * w * 0.18, top + h); p.lineTo(x, top + h); p.closePath();
  fillPath(ctx, p, lin(ctx, x, 0, x + d * w, 0, [[0, rgba(shade(c, -0.45))], [0.4, rgba(c)], [1, rgba(shade(c, -0.55))]]));
  const folds = P2(); for (let k = 1; k < 5; k++) { folds.moveTo(x + d * w * k / 5, top); folds.quadraticCurveTo(x + d * w * k / 5 * 0.6, top + h * 0.5, x + d * w * k / 5 * 0.2, top + h); } strokePath(ctx, folds, rgba([0, 0, 0], 0.3), 2);
  if (o.tie) { rect(ctx, x, top + h * 0.55, d * w * 0.4, 4, rgba(o.tie)); }
}

TEMPLATES.palaceRooftop = (ctx, R, o) => {
  const stone = [236, 196, 170], marble = [244, 238, 228];
  sky(ctx, ['#060a1e', '#0f1838', '#1e2850', '#2c3060'], 0, HORIZON);
  stars(ctx, R, 90, [0, 0, SW, 70], { bright: 4 });
  moon(ctx, 880, 22, 7, { crescent: '#0f1838', halo: 6 });
  // the old city under the parapet: the hill fort lit on the ridge, roofs and lights
  const hf = ridgeFn(R, 18, [0.006, 0.02]);
  ridge(ctx, R, 70, 18, rgba([22, 22, 44]), { fn: hf, bottom: 100 });
  const fortLine = []; for (let x = 0; x < SW; x += 6) if (Math.sin(x * 0.01) > -0.2) fortLine.push([x, 70 - hf(x) - 1.5, 0.9]);
  dots(ctx, fortLine, rgba([255, 200, 120], 0.8));
  const roofs = P2(); roofs.moveTo(-20, 110); let rx = -20; while (rx < SW + 20) { const w = between(R, 14, 40), h = between(R, 6, 18); roofs.lineTo(rx, 84 - h); roofs.lineTo(rx + w, 84 - h); rx += w; if (R() < 0.1) { roofs.lineTo(rx, 84 - h - 4); roofs.quadraticCurveTo(rx + 8, 84 - h - 16, rx + 16, 84 - h - 4); rx += 16; } } roofs.lineTo(SW + 20, 110); roofs.closePath();
  fillPath(ctx, roofs, rgba([40, 26, 46]));
  const lights = []; for (let i = 0; i < 160; i++) lights.push([between(R, 0, SW), between(R, 70, 88), between(R, 0.6, 1.2)]); dots(ctx, lights, rgba([255, 196, 120], 0.85));
  // the colonnade of cusped arches: the bar's frame, warm pink sandstone lit from below
  const fac = P2(); fac.rect(-20, -10, SW + 40, 104);
  const arches = [];
  for (let i = -6; i <= 6; i++) { const w = i === 0 ? 112 : 96, x = CX + i * 116; arches.push([x - w / 2, x + w / 2]); }
  for (const [a, b] of arches) cuspedArch(fac, a, b, 12, 94, 0.36);
  ctx.fillStyle = lin(ctx, 0, -10, 0, 94, [[0, rgba(shade(stone, -0.72))], [0.45, rgba(shade(stone, -0.42))], [1, rgba(shade(stone, -0.08))]]); ctx.fill(fac, 'evenodd');
  for (const [a, b] of arches) { const p = P2(); cuspedArch(p, a, b, 12, 94, 0.36); strokePath(ctx, p, rgba([255, 214, 170], 0.45), 1.6); }
  // pillars' inlay and lamp sconces
  for (let i = -6; i <= 6; i++) { const x = CX + i * 116 + 58; rect(ctx, x - 1, 30, 2, 60, rgba([150, 50, 60], 0.55)); glow(ctx, x, 60, 22, [255, 160, 80], 0.3, true); }
  for (const [a, b] of arches) { const x = (a + b) / 2; if (Math.abs(x - CX) < 10) continue; brassLantern(ctx, x, 12, 12, 7); }
  brassLantern(ctx, CX, 10, 4, 9);
  // parapet with jaali lattice and candles
  const par = P2(); par.rect(-20, 80, SW + 40, 14); fillPath(ctx, par, lin(ctx, 0, 80, 0, 94, [[0, rgba(shade(marble, -0.2))], [1, rgba(shade(marble, -0.55))]]));
  const jal = P2(); for (let x = -20; x < SW + 20; x += 8) { jal.moveTo(x, 83); jal.lineTo(x + 4, 87); jal.lineTo(x, 91); jal.moveTo(x + 4, 83); jal.lineTo(x, 87); jal.lineTo(x + 4, 91); } strokePath(ctx, jal, rgba([150, 110, 90], 0.45), 0.8);
  for (let x = 60; x < SW - 60; x += 46) { if (Math.abs(x - CX) < 50) continue; glow(ctx, x, 77, 16, [255, 170, 80], 0.5, true); rect(ctx, x - 1.5, 76, 3, 5, rgba([250, 240, 220])); circle(ctx, x, 74.5, 1.4, rgba([255, 220, 140])); }
  // cocktails and decanters on the parapet in the hero zones
  const pal = { glass: [[200, 210, 220], [160, 90, 50], [60, 110, 70]], liquid: [[230, 150, 60], [190, 60, 70], [240, 200, 120]], label: [[240, 230, 200], [190, 40, 60]], cap: [[200, 160, 80]] };
  bottleRow(ctx, R, 470, 610, 80, 24, pal, { kinds: ['decanter', 'round', 'wine', 'gin'] });
  bottleRow(ctx, R, 735, 920, 80, 24, pal, { kinds: ['decanter', 'round', 'wine', 'gin'] });
  // corners: saffron drapes and a potted palm
  anchored(ctx, 'L', () => { drape(ctx, -4, -10, 120, 300, [230, 120, 30], { tie: [240, 200, 90] }); palm(ctx, R, 70, 330, 220, '#0c1a12', { lean: 0.05, fronds: 11 }); const pot = P2(); pot.moveTo(40, 330); pot.lineTo(100, 330); pot.lineTo(92, 380); pot.lineTo(48, 380); pot.closePath(); fillPath(ctx, pot, lin(ctx, 40, 0, 100, 0, [[0, '#5a3010'], [0.4, '#b07030'], [1, '#4a2808']])); });
  anchored(ctx, 'R', () => { drape(ctx, SW + 4, -10, 120, 300, [200, 40, 90], { side: -1, tie: [240, 200, 90] }); for (const [x, y, s] of [[SW - 90, 110, 9], [SW - 140, 150, 7], [SW - 60, 190, 8]]) brassLantern(ctx, x, 60, y - 60, s); });
  // marble floor with inlay
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, rgba(shade(marble, -0.55))], [1, rgba(shade(marble, -0.85))]]));
  const inl = P2(); for (let x = -40; x < SW + 40; x += 60) { const y = F + 50; inl.moveTo(x, y); inl.lineTo(x + 30, y - 20); inl.lineTo(x + 60, y); inl.lineTo(x + 30, y + 20); inl.closePath(); } strokePath(ctx, inl, rgba([170, 60, 70], 0.5), 2);
  glow(ctx, 200, F + 20, 200, [255, 170, 80], 0.2, true); glow(ctx, SW - 200, F + 20, 200, [255, 170, 80], 0.2, true);
  finish(ctx, { split: 0.3, vignette: 0.45 });
};

// Komodaru: a sake barrel wrapped in straw, with a painted label panel.
function sakeBarrel(ctx, x, base, w, c, o = {}) {
  const h = w * 0.9, p = P2(); p.moveTo(x - w / 2, base); p.lineTo(x - w * 0.47, base - h); p.lineTo(x + w * 0.47, base - h); p.lineTo(x + w / 2, base); p.closePath();
  fillPath(ctx, p, lin(ctx, x - w / 2, 0, x + w / 2, 0, [[0, '#8a6a3a'], [0.4, '#d8bd84'], [1, '#6a4e26']]));
  const band = P2(); for (const t of [0.12, 0.88]) { band.moveTo(x - w * 0.49, base - h * t); band.lineTo(x + w * 0.49, base - h * t); } strokePath(ctx, band, rgba([60, 40, 20], 0.8), w * 0.04, 'butt');
  const lab = P2(); lab.rect(x - w * 0.3, base - h * 0.78, w * 0.6, h * 0.56); fillPath(ctx, lab, rgba(c));
  circle(ctx, x, base - h * 0.5, w * 0.14, rgba(o.mark || [245, 240, 225]));
  rect(ctx, x - w * 0.47, base - h - w * 0.06, w * 0.94, w * 0.06, '#5a4020');
}
TEMPLATES.izakaya = (ctx, R, o) => {
  const wood = [92, 58, 34];
  rect(ctx, 0, 0, SW, SH, '#140c08');
  // slatted wall, warm
  for (let x = 0; x < SW; x += 9) rect(ctx, x, 0, 7, 110, lin(ctx, 0, 0, 0, 110, [[0, rgba(shade(wood, -0.55))], [1, rgba(shade(wood, -0.15))]]));
  glow(ctx, CX, 60, 520, [255, 150, 70], 0.28, true);
  // ceiling beam with the lantern row
  rect(ctx, 0, 0, SW, 9, '#0c0705');
  for (let x = 120, i = 0; x < SW - 100; x += 74, i++) { if (Math.abs(x - CX) < 60) continue; chochin(ctx, x, 9, 6 + (i % 2) * 6, 11, i % 3 === 2 ? [250, 245, 230] : [226, 52, 36]); }
  // menu tags along the wall (flanks)
  for (let x = 140; x < SW - 140; x += 13) { if (x > 420 && x < 960) continue; rect(ctx, x, 40, 10, 30, rgba([236, 226, 200], 0.88)); rect(ctx, x + 4, 44, 2, 18, rgba([40, 30, 26], 0.7)); }
  // noren behind the dealer
  const nx = CX, nw = 150;
  for (let k = 0; k < 4; k++) { const x0 = nx - nw / 2 + k * nw / 4 + 1, p = P2(); p.moveTo(x0, 12); p.lineTo(x0 + nw / 4 - 2, 12); p.lineTo(x0 + nw / 4 - 2, 78); p.quadraticCurveTo(x0 + nw / 8, 82, x0, 78); p.closePath(); fillPath(ctx, p, lin(ctx, 0, 12, 0, 80, [[0, '#1d2a5a'], [1, '#121a3c']])); }
  circle(ctx, nx, 38, 16, rgba([238, 232, 216])); circle(ctx, nx, 38, 11, rgba([24, 34, 74])); circle(ctx, nx, 38, 6, rgba([238, 232, 216]));
  rect(ctx, nx - nw / 2 - 6, 9, nw + 12, 4, '#3a2412');
  // shelf of sake bottles and barrels in the hero zones
  backlight(ctx, 440, 960, 88, 34, [255, 170, 90], 0.45);
  const pal = { glass: [[60, 110, 80], [200, 200, 190], [90, 60, 40], [40, 60, 110]], liquid: [[240, 235, 220], [220, 200, 150]], label: [[245, 240, 225], [200, 40, 40], [30, 30, 30]], cap: [[20, 20, 20], [200, 40, 40]] };
  bottleRow(ctx, R, 445, 612, 88, 34, pal, { kinds: ['sake', 'sake', 'tall', 'round'] });
  bottleRow(ctx, R, 732, 950, 88, 34, pal, { kinds: ['sake', 'sake', 'tall', 'round'] });
  shelf(ctx, 0, SW, 88, 6, shade(wood, 0.2), shade(wood, -0.2));
  for (const [x, w, c] of [[300, 40, [200, 40, 40]], [345, 36, [30, 30, 30]], [1030, 40, [30, 60, 120]], [1075, 36, [200, 40, 40]]]) sakeBarrel(ctx, x, 88, w, c);
  // steam
  withBlur(ctx, 4, () => { const st = P2(); for (const x of [520, 560, 790, 860]) { st.moveTo(x, 86); st.quadraticCurveTo(x - 8, 70, x + 4, 56); st.quadraticCurveTo(x + 14, 44, x + 2, 30); } strokePath(ctx, st, rgba([255, 245, 230], 0.18), 6); });
  // corners: a stack of barrels left, a great lantern right
  anchored(ctx, 'L', () => {
    glow(ctx, 80, 220, 200, [255, 150, 70], 0.3, true);
    for (const [x, b, w, c] of [[50, 330, 96, [200, 40, 40]], [146, 330, 96, [30, 30, 30]], [98, 246, 96, [30, 60, 120]]]) sakeBarrel(ctx, x, b, w, c);
  });
  anchored(ctx, 'R', () => { rect(ctx, SW - 40, -10, 18, 400, lin(ctx, SW - 40, 0, SW - 22, 0, [[0, '#4a2c14'], [1, '#1c0e06']])); chochin(ctx, SW - 110, 60, 30, 46, [226, 52, 36], { mark: true }); });
  // hinoki counter
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#b8966a'], [0.2, '#8e6c44'], [1, '#3e2a16']]));
  const grain = P2(); for (let i = 0; i < 26; i++) { const y = between(R, F, SH); grain.moveTo(0, y); grain.quadraticCurveTo(SW / 2, y + between(R, -4, 4), SW, y + between(R, -3, 3)); } strokePath(ctx, grain, rgba([90, 60, 30], 0.18), 1);
  for (const x of [80, 140, 1210, 1260]) { oval(ctx, x, F + 30, 12, 4, rgba([0, 0, 0], 0.25)); const cup = P2(); cup.moveTo(x - 9, F + 18); cup.lineTo(x + 9, F + 18); cup.lineTo(x + 6, F + 30); cup.lineTo(x - 6, F + 30); cup.closePath(); fillPath(ctx, cup, lin(ctx, x - 9, 0, x + 9, 0, [[0, '#d8d2c8'], [0.5, '#ffffff'], [1, '#a8a29a']])); }
  finish(ctx, { split: 0.25, vignette: 0.5 });
};
