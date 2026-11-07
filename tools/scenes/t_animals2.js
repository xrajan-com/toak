// Animals, part 2: one wildlife template, configured per kingdom.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

// A big cat: lion (o.mane), leopard, tiger, cheetah. pose: walk | sit | lie.
function bigCat(ctx, x, base, h, c, o = {}) {
  const d = o.flip ? -1 : 1, s = h / 60, p = P2(), pose = o.pose || 'walk', slim = o.slim ? 0.8 : 1;
  if (pose === 'lie') {
    p.ellipse(x, base - 12 * s, 34 * s, 11 * s, 0, 0, TAU);
    p.ellipse(x + d * 32 * s, base - 22 * s, 11 * s, 10 * s, 0, 0, TAU);
    p.rect(x + d * 30 * s - (d < 0 ? 22 * s : 0), base - 5 * s, 22 * s, 5 * s);
    if (o.mane) p.ellipse(x + d * 28 * s, base - 22 * s, 16 * s, 15 * s, 0, 0, TAU);
  } else if (pose === 'sit') {
    p.ellipse(x, base - 22 * s, 16 * s, 22 * s, d * 0.25, 0, TAU);
    p.ellipse(x + d * 8 * s, base - 46 * s, 10 * s, 10 * s, 0, 0, TAU);
    if (o.mane) p.ellipse(x + d * 5 * s, base - 42 * s, 17 * s, 18 * s, 0, 0, TAU);
    p.rect(x + d * 6 * s - 3 * s, base - 22 * s, 6 * s, 22 * s); p.rect(x + d * 14 * s - 3 * s, base - 22 * s, 6 * s, 22 * s);
    p.ellipse(x - d * 8 * s, base - 4 * s, 16 * s, 5 * s, 0, 0, TAU);
  } else {
    p.ellipse(x, base - 30 * s, 28 * s, 10 * s * slim, 0, 0, TAU);
    p.ellipse(x - d * 16 * s, base - 30 * s, 12 * s, 11 * s * slim, 0, 0, TAU);
    p.ellipse(x + d * 14 * s, base - 31 * s, 12 * s, 12 * s * slim, 0, 0, TAU);
    p.ellipse(x + d * 30 * s, base - 36 * s, 9 * s, 8 * s, 0, 0, TAU);
    p.ellipse(x + d * 37 * s, base - 33 * s, 5 * s, 4 * s, 0, 0, TAU);
    if (o.mane) p.ellipse(x + d * 25 * s, base - 36 * s, 14 * s, 15 * s, d * 0.3, 0, TAU);
    for (const [lx, ph] of [[-20, 0.3], [-12, -0.2], [12, -0.25], [20, 0.25]]) { const ax = x + d * lx * s, ay = base - 26 * s; p.moveTo(ax - 3 * s, ay); p.lineTo(ax + d * ph * 8 * s - 2.4 * s, base); p.lineTo(ax + d * ph * 8 * s + 2.4 * s, base); p.lineTo(ax + 3 * s, ay); p.closePath(); }
  }
  for (const k of [-1, 1]) { const ex = x + d * (pose === 'walk' ? 28 : pose === 'sit' ? 8 : 32) * s + k * 5 * s, ey = base - (pose === 'walk' ? 43 : pose === 'sit' ? 55 : 30) * s; p.moveTo(ex - 3 * s, ey + 2 * s); p.lineTo(ex, ey - 3 * s); p.lineTo(ex + 3 * s, ey + 2 * s); p.closePath(); }
  fillPath(ctx, p, c);
  const t = P2(); if (pose === 'sit') { t.moveTo(x - d * 12 * s, base - 4 * s); t.quadraticCurveTo(x - d * 30 * s, base - 2 * s, x - d * 32 * s, base - 14 * s); } else { t.moveTo(x - d * 26 * s, base - (pose === 'lie' ? 14 : 32) * s); t.quadraticCurveTo(x - d * 44 * s, base - (pose === 'lie' ? 10 : 26) * s, x - d * 42 * s, base - (pose === 'lie' ? 2 : 10) * s); }
  strokePath(ctx, t, c, 3 * s);
}
function gharial(ctx, x, base, h, c, o = {}) { const d = o.flip ? -1 : 1, s = h / 20, p = P2(); p.moveTo(x - d * 40 * s, base - 2 * s); p.quadraticCurveTo(x - d * 10 * s, base - 9 * s, x + d * 16 * s, base - 7 * s); p.lineTo(x + d * 46 * s, base - 4 * s); p.lineTo(x + d * 46 * s, base - 2 * s); p.lineTo(x + d * 16 * s, base - 2 * s); p.closePath(); for (const lx of [-14, 8]) { p.moveTo(x + d * lx * s, base - 4 * s); p.lineTo(x + d * (lx + 4) * s, base); p.lineTo(x + d * (lx + 7) * s, base); p.lineTo(x + d * (lx + 4) * s, base - 4 * s); p.closePath(); } fillPath(ctx, p, c); const r = P2(); for (let k = -30; k < 10; k += 5) { r.moveTo(x + d * k * s, base - 7.5 * s); r.lineTo(x + d * (k + 2) * s, base - 9.5 * s); r.lineTo(x + d * (k + 4) * s, base - 7.5 * s); } fillPath(ctx, r, c); }
function wolf(ctx, x, base, h, c, o = {}) { const d = o.flip ? -1 : 1, s = h / 60, p = P2(); p.ellipse(x - d * 4 * s, base - 22 * s, 14 * s, 20 * s, d * 0.35, 0, TAU); p.moveTo(x + d * 2 * s, base - 34 * s); p.lineTo(x + d * 10 * s, base - 56 * s); p.lineTo(x + d * 18 * s, base - 62 * s); p.lineTo(x + d * 22 * s, base - 70 * s); p.lineTo(x + d * 18 * s, base - 54 * s); p.lineTo(x + d * 12 * s, base - 40 * s); p.closePath(); p.moveTo(x + d * 9 * s, base - 58 * s); p.lineTo(x + d * 8 * s, base - 66 * s); p.lineTo(x + d * 13 * s, base - 60 * s); p.closePath(); p.rect(x + d * 4 * s - 2.5 * s, base - 22 * s, 5 * s, 22 * s); p.moveTo(x - d * 14 * s, base - 4 * s); p.quadraticCurveTo(x - d * 30 * s, base - 2 * s, x - d * 34 * s, base - 10 * s); p.lineTo(x - d * 28 * s, base - 4 * s); p.lineTo(x - d * 14 * s, base); p.closePath(); fillPath(ctx, p, c); }
function turtle(ctx, x, base, s, c, o = {}) { const d = o.flip ? -1 : 1, p = P2(); p.ellipse(x, base - s * 0.28, s * 0.6, s * 0.3, 0, Math.PI, TAU); p.rect(x - s * 0.6, base - s * 0.3, s * 1.2, s * 0.08); p.ellipse(x + d * s * 0.72, base - s * 0.2, s * 0.16, s * 0.11, 0, 0, TAU); for (const k of [-1, 1]) { p.moveTo(x + k * s * 0.3, base - s * 0.22); p.lineTo(x + k * s * 0.55, base); p.lineTo(x + k * s * 0.2, base - s * 0.18); p.closePath(); } fillPath(ctx, p, c); }
function hornbill(ctx, x, y, s, c, o = {}) { const d = o.flip ? -1 : 1, p = P2(); p.ellipse(x, y, s * 0.5, s * 0.28, d * -0.3, 0, TAU); p.ellipse(x + d * s * 0.42, y - s * 0.3, s * 0.18, s * 0.17, 0, 0, TAU); p.moveTo(x - d * s * 0.4, y + s * 0.1); p.lineTo(x - d * s * 1.2, y + s * 0.6); p.lineTo(x - d * s * 1.1, y + s * 0.75); p.lineTo(x - d * s * 0.3, y + s * 0.25); p.closePath(); fillPath(ctx, p, c); const b = P2(); b.moveTo(x + d * s * 0.52, y - s * 0.38); b.quadraticCurveTo(x + d * s * 1.0, y - s * 0.4, x + d * s * 1.15, y - s * 0.05); b.quadraticCurveTo(x + d * s * 0.85, y - s * 0.2, x + d * s * 0.52, y - s * 0.22); b.closePath(); fillPath(ctx, b, rgba(o.bill || [240, 190, 60])); const cq = P2(); cq.moveTo(x + d * s * 0.5, y - s * 0.45); cq.quadraticCurveTo(x + d * s * 0.8, y - s * 0.62, x + d * s * 0.95, y - s * 0.38); cq.lineTo(x + d * s * 0.55, y - s * 0.38); cq.closePath(); fillPath(ctx, cq, rgba(o.bill || [240, 190, 60])); }

function animal(ctx, R, a, dark, rim) {
  const { kind, x, s } = a, base = a.base ?? 95, flip = !!a.flip;
  const drawOne = (col, dx, dy) => {
    const X = x + dx, Y = base + dy;
    switch (kind) {
      case 'lion': return bigCat(ctx, X, Y, s, col, { flip, mane: true, pose: a.pose });
      case 'lioness': case 'leopard': return bigCat(ctx, X, Y, s, col, { flip, pose: a.pose });
      case 'cheetah': return bigCat(ctx, X, Y, s, col, { flip, pose: a.pose, slim: true });
      case 'giraffe': return giraffe(ctx, X, Y, s, col, { flip });
      case 'rhino': return rhino(ctx, X, Y, s, col, { flip });
      case 'antelope': return antelope(ctx, X, Y, s, col, { flip, spiral: a.spiral });
      case 'horse': return horse(ctx, X, Y, s, col, { flip, pose: a.pose, rider: a.rider });
      case 'bear': return bear(ctx, X, Y, s, col, { flip });
      case 'moose': return moose(ctx, X, Y, s, col, { flip });
      case 'gharial': return gharial(ctx, X, Y, s, col, { flip });
      case 'turtle': return turtle(ctx, X, Y, s, col, { flip });
      case 'wolf': return wolf(ctx, X, Y, s, col, { flip });
      default: return iconAt(ctx, kind, X, Y, s, col, { flip });
    }
  };
  if (rim) drawOne(rgba(rim, 0.85), flip ? 1.3 : -1.3, -0.7);
  drawOne(dark, 0, 0);
}

const LANDS = {
  savanna: { sky: 'golden', ground: ['#e8a050', '#7a4a20', '#20120a'], far: 'hills', farC: [140, 80, 70], tree: 'acacia' },
  dryForest: { sky: 'golden', ground: ['#d89a50', '#6a4422', '#1c1008'], far: 'hills', farC: [120, 80, 70], tree: 'teak' },
  grassland: { sky: 'golden', ground: ['#d0a860', '#6a5a2a', '#1c180a'], far: 'hills', farC: [130, 100, 90], tree: 'acacia' },
  jungle: { sky: 'pinkDusk', ground: ['#4a6a3a', '#1e2c18', '#0a1008'], far: 'forest', farC: [40, 60, 50], tree: 'sal' },
  riverbank: { sky: 'golden', ground: ['#b88a58', '#4a3a24', '#140e08'], far: 'hills', farC: [120, 90, 90], tree: 'none', water: true },
  mustard: { sky: 'golden', ground: ['#f0d040', '#8a7a20', '#201c08'], far: 'trees', farC: [70, 80, 50], tree: 'none', field: [250, 210, 50] },
  wetGrass: { sky: 'dawn', ground: ['#b8b888', '#4a5a3a', '#121810'], far: 'hills', farC: [90, 110, 130], tree: 'none', tall: true },
  snow: { sky: 'blueHour', ground: ['#e6ecf6', '#6a789c', '#1a2036'], far: 'mountains', farC: [150, 160, 200], tree: 'pine', snow: true },
  forest: { sky: 'dusk', ground: ['#6a6a40', '#2a2a18', '#0c0c08'], far: 'forest', farC: [50, 60, 60], tree: 'pine' },
  outback: { sky: 'golden', ground: ['#e07840', '#7a3018', '#1e0c06'], far: 'none', farC: [150, 70, 50], tree: 'gum' },
  ice: { sky: 'arctic', ground: ['#d8e6f2', '#6a88a8', '#142030'], far: 'ice', farC: [200, 220, 240], tree: 'none' },
  plains: { sky: 'golden', ground: ['#d8a860', '#6a4a24', '#1c1008'], far: 'mountains', farC: [110, 100, 130], tree: 'none' },
  coast: { sky: 'dusk', ground: ['#3a6a8a', '#14304a', '#060e18'], far: 'none', farC: [40, 60, 80], tree: 'none', sea: true },
  beachNight: { sky: 'night', ground: ['#b8b0a0', '#4a4640', '#121110'], far: 'none', farC: [40, 60, 80], tree: 'none', surf: true },
};
function tree(ctx, R, kind, x, base, h, dark) {
  if (kind === 'acacia') { const t = P2(); t.moveTo(x - 1.5, base); t.lineTo(x - 1, base - h * 0.6); t.lineTo(x - h * 0.2, base - h * 0.85); t.lineTo(x - h * 0.18, base - h * 0.88); t.lineTo(x, base - h * 0.66); t.lineTo(x + h * 0.2, base - h * 0.88); t.lineTo(x + h * 0.22, base - h * 0.85); t.lineTo(x + 1.5, base - h * 0.6); t.lineTo(x + 1.5, base); t.closePath(); fillPath(ctx, t, dark); canopy(ctx, R, x, base - h * 0.92, h * 1.1, h * 0.16, [60, 40, 30], [24, 14, 10], { n: 40 }); return; }
  if (kind === 'pine') return iconAt(ctx, 'pine-tree', x, base, h, dark);
  if (kind === 'palm') return palm(ctx, R, x, base, h, dark);
  const t = P2(); t.moveTo(x - 2, base); t.quadraticCurveTo(x - 1, base - h * 0.5, x - 2, base - h * 0.7); t.lineTo(x + 2, base - h * 0.7); t.quadraticCurveTo(x + 1, base - h * 0.5, x + 2, base); t.closePath(); fillPath(ctx, t, dark);
  canopy(ctx, R, x, base - h * 0.78, h * (kind === 'gum' ? 0.5 : 0.62), h * 0.4, [50, 50, 36], [18, 18, 14], { n: 30 });
}

// o: { land, sky, sun|moon, animals: [{kind,x,s,flip,pose,base}], cornerL, cornerR, birds, trees: [x...] }
TEMPLATES.wildlife = (ctx, R, o) => {
  const L = LANDS[o.land || 'savanna'], dark = o.dark || '#160c0a', rim = o.rim ?? [255, 190, 110];
  skyPreset(ctx, o.sky || L.sky);
  ground(ctx, o.ground || L.ground);
  if (o.moon) moon(ctx, o.moon[0], o.moon[1], o.moon[2] || 9, { halo: 6 });
  else if (o.sun !== false) sunDisc(ctx, (o.sun || [CX - 300, 76])[0], (o.sun || [CX - 300, 76])[1], (o.sun || [0, 0, 22])[2] || 22, [255, 120, 50], [255, 214, 130], 84);
  if (o.stars) stars(ctx, R, o.stars, [0, 0, SW, 50], { bright: 3 });
  const farC = rgba(o.farC || L.farC);
  if (L.far === 'hills') ridge(ctx, R, 84, 16, farC, { freqs: [0.004, 0.012], bottom: 100 });
  if (L.far === 'mountains') mountains(ctx, R, 84, 34, farC, { bottom: 100, snow: L.snow || o.snowCaps ? [240, 244, 255] : null });
  if (L.far === 'forest') forestLine(ctx, R, 86, 26, farC);
  if (L.far === 'trees') forestLine(ctx, R, 84, 14, farC);
  if (L.far === 'ice') { const p = P2(); p.moveTo(-20, 90); let x = -20; while (x < SW + 20) { const w = between(R, 30, 90); p.lineTo(x, 84 - between(R, 2, 14)); p.lineTo(x + w, 84 - between(R, 2, 14)); x += w; } p.lineTo(SW + 20, 90); p.closePath(); fillPath(ctx, p, lin(ctx, 0, 70, 0, 90, [[0, '#e8f2ff'], [1, '#9ab4d0']])); }
  if (o.landmark) o.landmark(ctx, R);
  if (o.sandbank) rect(ctx, 0, 84, SW, 14, lin(ctx, 0, 84, 0, 98, [[0, '#c8a878'], [1, '#7a6040']]));
  if (L.water || o.water) { water(ctx, R, o.sandbank ? 74 : 82, o.sandbank ? 84 : 96, o.waterC || [60, 80, 90], { n: 40 }); if (o.sun !== false && !o.moon) reflection(ctx, R, (o.sun || [CX - 300])[0], 82, 96, [255, 200, 120], 50, 0.4); }
  if (L.sea) { water(ctx, R, 60, 100, [40, 80, 110], { n: 60 }); }
  if (L.surf) { water(ctx, R, 56, 76, [30, 50, 80], { n: 50 }); const sf = P2(); for (let x = -20; x < SW + 20; x += 24) { sf.moveTo(x, 76); sf.quadraticCurveTo(x + 12, 72, x + 24, 76); } strokePath(ctx, sf, rgba([230, 240, 255], 0.7), 1.6); rect(ctx, 0, 76, SW, 24, lin(ctx, 0, 76, 0, 100, [[0, '#a8a090'], [1, '#5a5448']])); }
  if (L.field || o.field) { const f = o.field || L.field; rect(ctx, 0, 84, SW, 14, lin(ctx, 0, 84, 0, 98, [[0, rgba(f)], [1, rgba(shade(f, -0.4))]])); const fl = []; for (let i = 0; i < 400; i++) fl.push([between(R, 0, SW), between(R, 80, 92), between(R, 0.8, 1.8)]); dots(ctx, fl, rgba(shade(f, 0.2))); }
  if (L.tall) { const g = P2(); for (let x = -10; x < SW + 10; x += 2.5) { const h = between(R, 8, 18); g.moveTo(x, 96); g.quadraticCurveTo(x + between(R, -2, 2), 96 - h * 0.6, x + between(R, -4, 4), 96 - h); } strokePath(ctx, g, rgba([150, 150, 100], 0.8), 0.8); }
  horizonHaze(ctx, 84, 8, o.haze || [255, 200, 140], 0.35);
  for (const tx of o.trees || []) tree(ctx, R, o.tree || L.tree, tx, 92, between(R, 40, 60), dark);
  for (const a of o.animals || []) animal(ctx, R, a, dark, rim);
  if (o.birds) birds(ctx, R, 380, 10, 980, 40, o.birds, rgba([30, 20, 24], 0.8), 4);
  if (o.extra) o.extra(ctx, R);
  if (o.cornerL) anchored(ctx, 'L', () => { glow(ctx, 40, 170, 220, o.glow || [255, 160, 80], 0.35, true); o.cornerL(ctx, R, dark, rim); });
  if (o.cornerR) anchored(ctx, 'R', () => { glow(ctx, SW - 40, 170, 220, o.glow || [255, 160, 80], 0.3, true); o.cornerR(ctx, R, dark, rim); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, rgba(o.floor || shade(col(L.ground[1]), 0.1))], [1, rgba(shade(o.floor || col(L.ground[1]), -0.7))]]));
  const tufts = P2(); for (let i = 0; i < 70; i++) { const x = between(R, 0, SW), y = between(R, F, SH); tufts.moveTo(x, y); tufts.lineTo(x - 2, y - 6); tufts.moveTo(x, y); tufts.lineTo(x + 2, y - 7); } strokePath(ctx, tufts, rgba([0, 0, 0], 0.25), 1);
  finish(ctx, { split: 0.3, vignette: 0.45 });
};
