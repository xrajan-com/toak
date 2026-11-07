// Wild cards: night skies, nature and festivals.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

TEMPLATES.milkyWayDesert = (ctx, R, o) => {
  const dark = '#06050c';
  sky(ctx, ['#03040e', '#070b26', '#141640', '#3a2440', '#8a4a3a'], 0, HORIZON);
  ground(ctx, ['#2a1a20', '#120a0e', '#06040a']);
  stars(ctx, R, 260, [0, 0, SW, 84], { bright: 10, size: 0.85 });
  milkyWay(ctx, R, 180, -30, 1180, 100, 46, { c1: [200, 180, 255], c2: [255, 210, 180] });
  milkyWay(ctx, R, 420, 10, 900, 60, 30, { c1: [255, 220, 200], c2: [255, 190, 160] });
  // dunes
  ridge(ctx, R, 88, 16, rgba([30, 22, 34]), { freqs: [0.004, 0.012], bottom: 110 });
  const dn = ridgeFn(R, 10, [0.006, 0.02]);
  ridge(ctx, R, 92, 10, rgba([14, 10, 16]), { fn: dn, bottom: 110 });
  // a lone khejri tree, a resting camel, a campfire with travellers
  const tree = P2(); tree.moveTo(520, 92); tree.quadraticCurveTo(524, 72, 514, 58); tree.lineTo(518, 57); tree.quadraticCurveTo(530, 70, 526, 92); tree.closePath(); fillPath(ctx, tree, dark);
  canopy(ctx, R, 516, 52, 76, 16, [24, 18, 26], [10, 8, 12], { n: 46 });
  glow(ctx, 820, 88, 90, [255, 130, 50], 0.55, true);
  const fire = P2(); fire.moveTo(820, 76); fire.quadraticCurveTo(826, 84, 822, 90); fire.lineTo(818, 90); fire.quadraticCurveTo(814, 84, 820, 76); fillPath(ctx, fire, rgba([255, 200, 100]));
  const ppl = P2(); personPath(ppl, 800, 92, 22); personPath(ppl, 842, 92, 20); fillPath(ctx, ppl, dark);
  rimIcon(ctx, 'camel', 900, 94, 40, dark, [255, 150, 70], { flip: true, dx: -1.4 });
  rimIcon(ctx, 'camel', 750, 94, 34, dark, [255, 150, 70], { dx: 1.4 });
  // corners: a lit camp tent on the left, a dune crest on the right
  anchored(ctx, 'L', () => {
    glow(ctx, 90, 250, 160, [255, 150, 70], 0.4, true);
    const t = P2(); t.moveTo(-10, 330); t.lineTo(90, 170); t.lineTo(200, 330); t.closePath(); fillPath(ctx, t, lin(ctx, 0, 170, 0, 330, [[0, '#3a2018'], [1, '#160a08']]));
    const door = P2(); door.moveTo(70, 330); door.lineTo(92, 230); door.lineTo(116, 330); door.closePath(); fillPath(ctx, door, rgba([255, 170, 80], 0.9));
    glow(ctx, 92, 300, 60, [255, 160, 70], 0.5, true);
  });
  anchored(ctx, 'R', () => { const d = P2(); d.moveTo(SW + 10, 140); d.quadraticCurveTo(SW - 120, 180, SW - 230, 360); d.lineTo(SW + 10, 360); d.closePath(); fillPath(ctx, d, '#0a070c'); });
  glow(ctx, CX + 160, F + 20, 300, [255, 120, 50], 0.12, true);
  finish(ctx, { split: 0.2, vignette: 0.5 });
};

TEMPLATES.kiteFestival = (ctx, R, o) => {
  const dark = '#2a1620', pinkCity = [222, 130, 120];
  sky(ctx, ['#2c5a8c', '#5a86b0', '#a6b6c4', '#f0c48c', '#f6a870'], 0, HORIZON);
  ground(ctx, [shade(pinkCity, -0.1), shade(pinkCity, -0.55), shade(pinkCity, -0.8)]);
  glow(ctx, CX - 280, 80, 300, [255, 200, 130], 0.4, true);
  // kites everywhere, strings down to the roofs
  const cols = [[236, 40, 90], [255, 200, 40], [40, 170, 90], [120, 60, 200], [255, 120, 30], [30, 140, 220], [250, 245, 235]];
  const strings = P2(), ks = [];
  for (let i = 0; i < 46; i++) {
    const x = between(R, 20, SW - 20), y = between(R, 4, 58), s = between(R, 4, 9) * (y < 30 ? 0.8 : 1.1);
    if (x > DEALER[0] - 10 && x < DEALER[1] + 10 && y > 50) continue;
    ks.push([x, y, s]); strings.moveTo(x, y + s); strings.quadraticCurveTo(x + between(R, -40, 40), y + 40, x + between(R, -80, 80), 92);
  }
  strokePath(ctx, strings, rgba([255, 255, 255], 0.25), 0.5);
  for (const [x, y, s] of ks) { const a = pick(R, cols); let b = pick(R, cols); if (b === a) b = cols[(cols.indexOf(a) + 2) % cols.length]; kite(ctx, x, y, s, a, b, between(R, -0.4, 0.4)); }
  const birds = P2(); for (const [bx, by, s] of [[600, 30, 4], [612, 26, 3.5], [900, 18, 4]]) { birds.moveTo(bx - s, by - s * 0.4); birds.quadraticCurveTo(bx - s * 0.4, by - s * 0.6, bx, by); birds.quadraticCurveTo(bx + s * 0.4, by - s * 0.6, bx + s, by - s * 0.4); } strokePath(ctx, birds, rgba([40, 30, 40], 0.8), 1.1);
  // the old city's rooftops: pink plaster, parapets, a temple shikhara, people with charkhis
  const roofs = P2(); roofs.moveTo(-20, 120); let rx = -20; const tops = [];
  while (rx < SW + 20) { const w = between(R, 40, 90), h = between(R, 10, 26); roofs.lineTo(rx, 92 - h); for (let k = 0; k < w; k += 8) { roofs.lineTo(rx + k, 92 - h); roofs.lineTo(rx + k, 90 - h); roofs.lineTo(rx + k + 4, 90 - h); roofs.lineTo(rx + k + 4, 92 - h); } roofs.lineTo(rx + w, 92 - h); tops.push([rx, rx + w, 92 - h]); rx += w; }
  roofs.lineTo(SW + 20, 120); roofs.closePath();
  fillPath(ctx, roofs, lin(ctx, 0, 60, 0, 100, [[0, rgba(pinkCity)], [1, rgba(shade(pinkCity, -0.3))]]));
  const win = []; for (const [a, b, t] of tops) for (let x = a + 6; x < b - 6; x += 12) if (R() < 0.5) win.push([x, t + 8 + R() * 6]);
  for (const [x, y] of win) rect(ctx, x - 1.6, y, 3.2, 5, rgba([90, 50, 60], 0.7));
  const temple = P2(); temple.moveTo(380, 70); temple.quadraticCurveTo(384, 44, 396, 34); temple.quadraticCurveTo(408, 44, 412, 70); temple.closePath(); temple.rect(395, 26, 2, 8); fillPath(ctx, temple, rgba(shade(pinkCity, -0.15)));
  pennant(ctx, 397, 24, 10, 5, [255, 120, 30]);
  const ppl = P2();
  for (const [a, b, t] of tops) { if (R() < 0.55 && (b < DEALER[0] - 10 || a > DEALER[1] + 10)) { const x = between(R, a + 8, b - 8); personPath(ppl, x, t, between(R, 16, 22), { armUp: R() < 0.6 ? 1 : 2 }); } }
  fillPath(ctx, ppl, dark);
  // corners: a big kite on the left, wires with a caught kite on the right
  anchored(ctx, 'L', () => { kite(ctx, 70, 150, 70, [236, 40, 90], [255, 200, 40], -0.3, { band: [250, 245, 235] }); line(ctx, 90, 230, 200, 460, rgba([255, 255, 255], 0.35), 0.8); });
  anchored(ctx, 'R', () => {
    const w = P2(); w.moveTo(SW + 10, 110); w.quadraticCurveTo(SW - 120, 140, SW - 260, 104); w.moveTo(SW + 10, 140); w.quadraticCurveTo(SW - 120, 170, SW - 260, 134); strokePath(ctx, w, rgba([30, 20, 24], 0.8), 1.4);
    kite(ctx, SW - 110, 150, 40, [40, 170, 90], [120, 60, 200], 0.5); kite(ctx, SW - 60, 210, 30, [255, 120, 30], [250, 245, 235], -0.2);
  });
  // the terrace floor with a spool
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, rgba(shade(pinkCity, -0.25))], [1, rgba(shade(pinkCity, -0.7))]]));
  for (const x of [130, SW - 130]) { oval(ctx, x, F + 40, 22, 10, rgba([0, 0, 0], 0.25)); const sp = P2(); sp.rect(x - 16, F + 14, 32, 22); fillPath(ctx, sp, lin(ctx, x - 16, 0, x + 16, 0, [[0, '#a05a20'], [0.5, '#e8a050'], [1, '#804010']])); const th = P2(); for (let k = 0; k < 8; k++) { th.moveTo(x - 14, F + 16 + k * 2.5); th.lineTo(x + 14, F + 16 + k * 2.5); } strokePath(ctx, th, rgba([236, 40, 90], 0.8), 1); }
  finish(ctx, { split: 0.25, vignette: 0.4, dim: 0.08 });
};

TEMPLATES.fujiStars = (ctx, R, o) => {
  sky(ctx, ['#03061a', '#0a1236', '#18245a', '#2c3a72'], 0, HORIZON);
  ground(ctx, ['#1a2448', '#0a1024', '#04060e']);
  stars(ctx, R, 220, [0, 0, SW, 80], { bright: 8 });
  milkyWay(ctx, R, 980, -20, 1240, 90, 30, { c1: [140, 150, 255], c2: [200, 170, 255] });
  // Fuji behind the dealer
  const fx = CX, fb = 88, fw = 380, peak = 10, cap = P2(), m = P2();
  m.moveTo(fx - fw, fb + 4); m.quadraticCurveTo(fx - fw * 0.35, fb - 18, fx - 26, peak); m.lineTo(fx + 26, peak); m.quadraticCurveTo(fx + fw * 0.35, fb - 18, fx + fw, fb + 4); m.closePath();
  fillPath(ctx, m, lin(ctx, 0, peak, 0, fb, [[0, '#34406e'], [1, '#121a38']]));
  cap.moveTo(fx - 26, peak); cap.lineTo(fx + 26, peak); cap.quadraticCurveTo(fx + 70, 30, fx + 92, 44);
  for (let k = 0; k < 9; k++) { const x0 = fx + 92 - (k + 1) * 184 / 9; cap.lineTo(x0 + 10, 44 - (k % 2 ? 6 : -4)); cap.lineTo(x0, 46 - (k % 3) * 4); }
  cap.quadraticCurveTo(fx - 70, 30, fx - 26, peak); cap.closePath();
  fillPath(ctx, cap, lin(ctx, fx - 90, 0, fx + 90, 0, [[0, '#f4f6ff'], [0.55, '#c8d0f0'], [1, '#7a86b8']]));
  // the pagoda among blossoms (left), a torii in the lake (right)
  ridge(ctx, R, 92, 18, rgba([10, 14, 30]), { freqs: [0.01, 0.03], x0: 300, x1: 620, env: (x) => Math.sin(((x - 300) / 320) * Math.PI), bottom: 110 });
  canopy(ctx, R, 520, 70, 120, 26, [255, 200, 220], [180, 110, 150], { n: 70 });
  iconAt(ctx, 'pagoda', 470, 82, 62, '#160a12');
  for (let k = 0; k < 5; k++) glow(ctx, 470, 36 + k * 9, 9, [255, 120, 80], 0.35, true);
  torii(ctx, 860, 96, 46, '#e04a26', '#200c08');
  glow(ctx, 860, 80, 50, [255, 120, 60], 0.2, true);
  // lake: reflections in the strip and under the rail
  rect(ctx, 0, 86, SW, 8, rgba([20, 30, 70], 0.6));
  const refl = P2(); for (let i = 0; i < 30; i++) { const x = between(R, 0, SW), y = between(R, 88, 94); refl.moveTo(x, y); refl.lineTo(x + between(R, 8, 30), y); } strokePath(ctx, refl, rgba([200, 210, 255], 0.25), 0.8);
  // corners: cherry blossom branches
  anchored(ctx, 'L', () => { blossomBranch(ctx, R, -10, 70, 0.35, 190, '#1a0e12', [[255, 190, 210], [255, 240, 245]], { depth: 3, width: 9, glow: true }); });
  anchored(ctx, 'R', () => { blossomBranch(ctx, R, SW + 10, 110, Math.PI - 0.3, 170, '#1a0e12', [[255, 190, 210], [255, 240, 245]], { depth: 3, width: 8 }); torii(ctx, SW - 110, 420, 200, '#d8401e', '#1c0a06'); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#101a3a'], [1, '#03050c']]));
  const rf = P2(); for (let i = 0; i < 70; i++) { const x = between(R, 0, SW), y = between(R, F, SH); rf.moveTo(x, y); rf.lineTo(x + between(R, 10, 50), y); } strokePath(ctx, rf, rgba([180, 200, 255], 0.14), 1);
  for (const x of [200, SW - 200]) { const l = P2(); for (let y = F + 4; y < SH; y += 6) { l.moveTo(x - between(R, 4, 14), y); l.lineTo(x + between(R, 4, 14), y); } strokePath(ctx, l, rgba([255, 140, 80], 0.25), 1.2); }
  finish(ctx, { split: 0.25, vignette: 0.45 });
};

TEMPLATES.hanabi = (ctx, R, o) => {
  const dark = '#06070e';
  sky(ctx, ['#020414', '#070c2a', '#141a44', '#2a2a50'], 0, HORIZON);
  ground(ctx, ['#1a1a34', '#0a0a18', '#04040a']);
  stars(ctx, R, 60, [0, 0, SW, 40], { bright: 2, alpha: 0.6 });
  withBlur(ctx, 12, () => { for (let i = 0; i < 8; i++) oval(ctx, between(R, 200, 1150), between(R, 30, 80), between(R, 60, 120), 18, rgba([140, 120, 160], 0.12)); });
  // the fireworks
  firework(ctx, R, 520, 34, 46, [255, 80, 90]);
  firework(ctx, R, 860, 30, 52, [255, 210, 90], { rays: 54 });
  firework(ctx, R, 700, 6, 34, [120, 255, 160]);
  firework(ctx, R, 350, 18, 30, [200, 120, 255]);
  firework(ctx, R, 1030, 18, 34, [90, 200, 255]);
  // willow: golden trails drooping
  additive(ctx, () => { const w = P2(); for (let i = 0; i < 26; i++) { const a = -Math.PI / 2 + (i - 13) * 0.18, l = between(R, 30, 46); w.moveTo(620, 22); w.quadraticCurveTo(620 + Math.cos(a) * l, 22 + Math.sin(a) * l, 620 + Math.cos(a) * l * 1.3, 22 + Math.sin(a) * l + 60); } strokePath(ctx, w, rgba([255, 190, 90], 0.35), 0.8); });
  // the city across the river: towers and a broadcast tower
  const city = P2(); city.moveTo(-20, 100); let x = -20; while (x < SW + 20) { const w = between(R, 14, 36), h = between(R, 6, 24); city.lineTo(x, 84 - h); city.lineTo(x + w, 84 - h); x += w + 2; } city.lineTo(SW + 20, 100); city.closePath(); fillPath(ctx, city, rgba([14, 16, 34]));
  const tw = P2(); tw.moveTo(1100, 84); tw.lineTo(1106, 20); tw.lineTo(1108, 4); tw.lineTo(1110, 20); tw.lineTo(1116, 84); tw.closePath(); fillPath(ctx, tw, rgba([20, 24, 44])); glow(ctx, 1108, 6, 8, [255, 60, 60], 0.8, true); dots(ctx, [[1108, 40, 1.5], [1108, 56, 1.5]], rgba([150, 220, 255]));
  const wl = []; for (let i = 0; i < 140; i++) wl.push([between(R, 0, SW), between(R, 66, 84), 0.7]); dots(ctx, wl, rgba([255, 220, 160], 0.6));
  // the riverbank crowd in yukata with fans, yatai lanterns
  crowd(ctx, R, -10, SW + 10, 88, 15, dark, { hands: 0.12 });
  for (const xx of [220, 300, 1050, 1130]) { for (let k = -1; k <= 1; k++) chochin(ctx, xx + k * 14, 60, 4, 4.5, [235, 60, 40]); rect(ctx, xx - 26, 58, 52, 3, '#1a1010'); }
  // corners: yatai stall roofs with lanterns
  anchored(ctx, 'L', () => { const r = P2(); r.moveTo(-10, 110); r.lineTo(210, 90); r.lineTo(220, 112); r.lineTo(-10, 132); r.closePath(); fillPath(ctx, r, '#1a0e0c'); for (let k = 0; k < 4; k++) chochin(ctx, 30 + k * 48, 114 - k * 5, 6, 12, [235, 60, 40]); glow(ctx, 100, 220, 160, [255, 150, 60], 0.3, true); });
  anchored(ctx, 'R', () => { const r = P2(); r.moveTo(SW + 10, 110); r.lineTo(SW - 210, 90); r.lineTo(SW - 220, 112); r.lineTo(SW + 10, 132); r.closePath(); fillPath(ctx, r, '#1a0e0c'); for (let k = 0; k < 4; k++) chochin(ctx, SW - 30 - k * 48, 114 - k * 5, 6, 12, k % 2 ? [250, 245, 230] : [235, 60, 40]); glow(ctx, SW - 100, 220, 160, [255, 150, 60], 0.3, true); });
  // the river under the rail, full of reflections
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#0c1028'], [1, '#02030a']]));
  for (const [rx2, c] of [[520, [255, 80, 90]], [860, [255, 210, 90]], [350, [200, 120, 255]], [1030, [90, 200, 255]]]) { const l = P2(); for (let y = F + 2; y < SH; y += 5) { l.moveTo(rx2 - between(R, 6, 30), y); l.lineTo(rx2 + between(R, 6, 30), y); } additive(ctx, () => strokePath(ctx, l, rgba(c, 0.28), 1.4)); }
  finish(ctx, { split: 0.2, vignette: 0.45 });
};
