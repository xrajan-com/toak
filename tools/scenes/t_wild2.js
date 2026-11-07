// Wild cards, part 2: cities at night, festivals, lanterns, launches, peaks, waters.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

// A city skyline at night across water. o: { sky, skylineH, water: 'river'|'sea'|false,
//   bridge: 'suspension'|'arch'|'stone'|'cable', landmark(ctx,R), fireworks: [[x,y,r,c]...], lightsC, corners: 'trees'|'lamps'|'rail' }
TEMPLATES.cityNight = (ctx, R, o) => {
  const wl = o.water === false ? 98 : (o.waterline ?? 74), lightsC = o.lightsC || [255, 210, 140];
  skyPreset(ctx, o.sky || 'blueHour');
  ground(ctx, ['#14182a', '#0a0c18', '#04050a']);
  stars(ctx, R, 40, [0, 0, SW, 30], { alpha: 0.6 });
  if (o.moon) moon(ctx, o.moon[0], o.moon[1], o.moon[2] || 7, { halo: 6 });
  skyline(ctx, R, wl, rgba(o.cityC || [26, 28, 46]), { h: o.skylineH || 46, lit: 0.4, winColor: lightsC, spires: o.spires ?? 0.15, env: o.env });
  if (o.landmark) o.landmark(ctx, R);
  if (o.fireworks) for (const [x, y, r, c] of o.fireworks) firework(ctx, R, x, y, r, c);
  if (o.water !== false) {
    water(ctx, R, wl, 100, o.waterC || [20, 30, 60], { n: 60, glintA: 0.12 });
    const refl = P2(); for (let i = 0; i < 160; i++) { const x = between(R, 0, SW), y = between(R, wl + 1, 98); refl.moveTo(x, y); refl.lineTo(x + between(R, 2, 8), y); } additive(ctx, () => strokePath(ctx, refl, rgba(lightsC, 0.35), 1));
    if (o.fireworks) for (const [x, , , c] of o.fireworks) reflection(ctx, R, x, wl + 1, 98, c, 30, 0.3);
  }
  const brC = rgba(o.bridgeC || [30, 30, 44]);
  if (o.bridge === 'suspension') suspensionBridge(ctx, 760, 1240, wl - 4, 40, brC, { lights: lightsC });
  if (o.bridge === 'arch') { archBridge(ctx, 780, 1200, wl - 6, o.archH || 16, brC); if (o.bridgeC) { const bl = []; for (let x = 780; x < 1200; x += 8) bl.push([x, wl - 7, 1]); dots(ctx, bl, rgba(lightsC)); } }
  if (o.bridge === 'stone') stoneArches(ctx, 760, 1220, wl - 2, 8, rgba([40, 36, 44]));
  if (o.bridge === 'cable') { const p = P2(); p.rect(700, wl - 6, 600, 3); p.moveTo(940, wl - 6); p.lineTo(946, wl - 54); p.lineTo(952, wl - 6); p.closePath(); fillPath(ctx, p, rgba([30, 30, 44])); const cb = P2(); for (let k = 1; k <= 10; k++) { cb.moveTo(946, wl - 50 + k * 2); cb.lineTo(946 - k * 22, wl - 5); cb.moveTo(946, wl - 50 + k * 2); cb.lineTo(946 + k * 22, wl - 5); } strokePath(ctx, cb, rgba(lightsC, 0.5), 0.6); }
  if (o.promenade) { const arc = []; for (let t = 0; t <= 1; t += 0.008) arc.push([lerp(80, 620, t), wl + 4 + Math.sin(t * Math.PI) * 10, 1]); dots(ctx, arc, rgba([255, 220, 140])); for (const [x, y] of arc.filter((_, i) => i % 8 === 0)) glow(ctx, x, y, 8, [255, 200, 120], 0.3, true); }
  anchored(ctx, 'L', () => { if (o.corners === 'trees') canopy(ctx, R, 40, 80, 200, 140, [20, 30, 24], [8, 12, 10]); else { for (const y of [140, 230]) { line(ctx, 60, y - 60, 60, y + 120, '#0c0c12', 3); glow(ctx, 60, y - 64, 30, lightsC, 0.5, true); circle(ctx, 60, y - 64, 5, rgba([255, 240, 200])); } } });
  anchored(ctx, 'R', () => { if (o.corners === 'trees') canopy(ctx, R, SW - 40, 80, 200, 140, [20, 30, 24], [8, 12, 10]); else { line(ctx, SW - 70, 80, SW - 70, 340, '#0c0c12', 3); glow(ctx, SW - 70, 76, 30, lightsC, 0.5, true); circle(ctx, SW - 70, 76, 5, rgba([255, 240, 200])); } });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#1a1c28'], [1, '#05060a']]));
  if (o.water !== false) { const rf = P2(); for (let i = 0; i < 70; i++) { const x = between(R, 0, SW), y = between(R, F, SH); rf.moveTo(x, y); rf.lineTo(x + between(R, 10, 40), y); } additive(ctx, () => strokePath(ctx, rf, rgba(lightsC, 0.18), 1)); }
  finish(ctx, { split: 0.25, vignette: 0.45 });
};

// Night market / bazaar: stall roofs, lanterns, glitter, a crowd.
// o: { lanternC: [colours], awningC: [colours], sparkle, landmark(ctx,R), steam }
TEMPLATES.nightBazaar = (ctx, R, o) => {
  const dark = '#0a0608';
  skyPreset(ctx, o.sky || 'warmNight');
  ground(ctx, ['#3a2420', '#160c0a', '#060404']);
  if (o.landmark) o.landmark(ctx, R);
  else skyline(ctx, R, 70, rgba([30, 20, 30]), { h: 30, lit: 0.25 });
  // strings of lanterns across the lane
  const lc = o.lanternC || [[255, 80, 60], [255, 200, 80], [255, 120, 200]];
  for (const [x0, x1, y, sag] of [[-20, 640, 12, 16], [700, SW + 20, 10, 18], [-20, SW + 20, 36, 14]]) { const w = P2(); w.moveTo(x0, y); w.quadraticCurveTo((x0 + x1) / 2, y + sag * 2, x1, y); strokePath(ctx, w, rgba([20, 14, 14], 0.8), 0.8); for (let t = 0.03; t < 1; t += 0.045) { const x = lerp(x0, x1, t), yy = y + sag * 2 * 2 * t * (1 - t) * 0.5 + 3; const c = lc[Math.floor(t * 100) % lc.length]; glow(ctx, x, yy + 2, 12, c, 0.5, true); oval(ctx, x, yy + 2, 3.2, 4, rgba(mix(c, [255, 255, 255], 0.3))); } }
  // stalls with awnings and lit goods
  const aw = o.awningC || [[200, 40, 50], [240, 200, 60], [40, 120, 90], [230, 110, 40]];
  for (let x = -10, i = 0; x < SW + 10; x += 96, i++) {
    if (Math.abs(x + 44 - CX) < 60) continue;
    const c = aw[i % aw.length], a = P2(); a.moveTo(x, 58); a.lineTo(x + 88, 58); a.lineTo(x + 92, 68); for (let k = 0; k < 6; k++) a.quadraticCurveTo(x + 92 - k * 16 - 8, 74, x + 92 - (k + 1) * 16, 68); a.lineTo(x - 4, 68); a.closePath();
    fillPath(ctx, a, rgba(c)); const st = P2(); for (let k = 0; k < 6; k += 2) st.rect(x + k * 16, 58, 16, 10); fillPath(ctx, st, rgba([250, 240, 220], 0.35));
    rect(ctx, x + 4, 70, 84, 22, lin(ctx, 0, 70, 0, 92, [[0, '#2a1a12'], [1, '#120a06']]));
    glow(ctx, x + 46, 78, 46, [255, 190, 110], 0.45, true);
    const goods = []; for (let k = 0; k < 26; k++) goods.push([x + between(R, 8, 84), between(R, 74, 88), between(R, 1, 2.2)]);
    dots(ctx, goods, rgba(o.sparkle ? pick(R, o.sparkle) : [255, 220, 150], 0.9));
  }
  if (o.steam) withBlur(ctx, 5, () => { const s = P2(); for (const x of [220, 480, 900, 1120]) { s.moveTo(x, 70); s.quadraticCurveTo(x - 10, 50, x + 4, 30); } strokePath(ctx, s, rgba([255, 240, 230], 0.2), 8); });
  crowd(ctx, R, -10, SW + 10, 90, 14, dark, { hands: 0.08 });
  anchored(ctx, 'L', () => { glow(ctx, 60, 160, 160, [255, 170, 90], 0.4, true); for (let k = 0; k < 5; k++) { const c = lc[k % lc.length]; chochin(ctx, 30 + k * 34, 90 + (k % 2) * 30, 10, 12, c); } });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 160, 160, [255, 170, 90], 0.4, true); for (let k = 0; k < 5; k++) { const c = lc[(k + 1) % lc.length]; chochin(ctx, SW - 30 - k * 34, 90 + (k % 2) * 30, 10, 12, c); } });
  tiles(ctx, F - 10, [70, 50, 40], [50, 34, 28], 22);
  glow(ctx, CX, F, 500, [255, 170, 90], 0.15, true);
  finish(ctx, { split: 0.25, vignette: 0.45 });
};

// Lanterns released into the sky (o.mode 'sky') or floating lamps on a river ('river').
TEMPLATES.lanterns = (ctx, R, o) => {
  const lc = o.c || [255, 170, 80], dark = '#06070c', river = o.mode === 'river';
  skyPreset(ctx, o.sky || 'deepNight');
  ground(ctx, ['#1a1a2a', '#0a0a14', '#04040a']);
  stars(ctx, R, 70, [0, 0, SW, 50], { bright: 2 });
  if (o.hills) mountains(ctx, R, 78, 30, [14, 18, 30], { bottom: 100 });
  if (o.landmark) o.landmark(ctx, R);
  if (!river) {
    const ls = []; for (let i = 0; i < 120; i++) { const y = between(R, -4, 80), s = lerp(1.2, 4, (y + 4) / 84) * between(R, 0.7, 1.2); ls.push([between(R, 0, SW), y, s]); }
    for (const [x, y, s] of ls) { glow(ctx, x, y, s * 4, lc, 0.35, true); }
    for (const [x, y, s] of ls) { const p = P2(); p.moveTo(x - s * 0.6, y - s); p.lineTo(x + s * 0.6, y - s); p.lineTo(x + s * 0.45, y + s * 0.7); p.lineTo(x - s * 0.45, y + s * 0.7); p.closePath(); fillPath(ctx, p, lin(ctx, 0, y - s, 0, y + s, [[0, rgba(shade(lc, 0.4))], [1, rgba(lc)]])); }
    crowd(ctx, R, -10, SW + 10, 92, 14, dark, { hands: 0.4 });
  } else {
    if (o.ghats) { for (let k = 0; k < 6; k++) rect(ctx, -20, 58 + k * 3, SW + 40, 3, rgba(mix([120, 90, 70], [50, 36, 30], k / 6))); const wins = indianFortCrest(ctx, R, 'rajput', 200, 1140, 58, 34, rgba([90, 60, 50]), [255, 140, 30]); dots(ctx, wins.map(([x, y]) => [x, y, 1]), rgba([255, 200, 120], 0.8)); }
    water(ctx, R, 76, 100, o.waterC || [20, 30, 50], { n: 30 });
    for (let i = 0; i < 90; i++) { const x = between(R, 0, SW), y = between(R, 78, 98), s = lerp(1, 2.6, (y - 78) / 20); glow(ctx, x, y, s * 5, lc, 0.45, true); oval(ctx, x, y, s, s * 0.5, rgba(shade(lc, 0.5))); reflection(ctx, R, x, y + 1, Math.min(100, y + 6), lc, s * 3, 0.3); }
    if (o.boats) for (const x of [420, 900]) canoe(ctx, x, 86, 30, dark, { crew: 2 });
  }
  anchored(ctx, 'L', () => { glow(ctx, 60, 200, 180, lc, 0.3, true); if (o.cornerTree !== false) canopy(ctx, R, 30, 90, 220, 150, [16, 20, 18], [6, 8, 8]); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 200, 180, lc, 0.3, true); if (o.cornerTree !== false) canopy(ctx, R, SW - 30, 90, 220, 150, [16, 20, 18], [6, 8, 8]); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#12121e'], [1, '#040408']]));
  const fl = []; for (let i = 0; i < 40; i++) fl.push([between(R, 0, SW), between(R, F, SH), between(R, 1, 2)]); for (const [x, y, s] of fl.slice(0, 16)) glow(ctx, x, y, 10, lc, 0.25, true); dots(ctx, fl, rgba(shade(lc, 0.3), 0.7));
  finish(ctx, { split: 0.2, vignette: 0.45 });
};

// A rocket on the pad at night, lifting off. o: { style: 'shuttle'|'soyuz'|'pslv', land: 'coast'|'steppe' }
TEMPLATES.rocketLaunch = (ctx, R, o) => {
  const dark = '#06070c';
  skyPreset(ctx, 'deepNight');
  ground(ctx, o.land === 'steppe' ? ['#3a3024', '#14100c', '#060504'] : ['#1a2a3a', '#0a121a', '#04060a']);
  stars(ctx, R, 160, [0, 0, SW, 70], { bright: 6 });
  if (o.land !== 'steppe') { water(ctx, R, 80, 100, [16, 30, 50], { n: 30 }); }
  // the plume and the climbing rocket behind the dealer
  const rx = CX + 6, ry = 14;
  additive(ctx, () => { withBlur(ctx, 10, () => { const pl = P2(); pl.moveTo(rx - 3, ry + 24); pl.quadraticCurveTo(rx - 30, 70, rx - 90, 92); pl.lineTo(rx + 90, 92); pl.quadraticCurveTo(rx + 30, 70, rx + 3, ry + 24); pl.closePath(); fillPath(ctx, pl, lin(ctx, 0, ry + 20, 0, 92, [[0, rgba([255, 230, 170], 0.9)], [0.4, rgba([255, 150, 60], 0.6)], [1, rgba([255, 100, 40], 0.15)]])); }); });
  glow(ctx, rx, ry + 30, 90, [255, 190, 100], 0.6, true);
  withBlur(ctx, 12, () => { for (let i = 0; i < 12; i++) oval(ctx, rx + between(R, -260, 260), between(R, 76, 96), between(R, 40, 90), 14, rgba([200, 170, 160], 0.3)); });
  const rk = P2(); rk.moveTo(rx, ry - 16); rk.quadraticCurveTo(rx + 4, ry - 10, rx + 4, ry); rk.lineTo(rx + 4, ry + 24); rk.lineTo(rx - 4, ry + 24); rk.lineTo(rx - 4, ry); rk.quadraticCurveTo(rx - 4, ry - 10, rx, ry - 16); if (o.style !== 'shuttle') { rk.rect(rx - 8, ry + 8, 3, 16); rk.rect(rx + 5, ry + 8, 3, 16); } fillPath(ctx, rk, rgba([240, 236, 230]));
  // pads, towers, viewers
  for (const [x, h] of [[440, 60], [900, 50]]) { const t = P2(); t.rect(x - 6, 92 - h, 12, h); for (let y = 92 - h; y < 92; y += 6) { t.moveTo(x - 6, y); t.lineTo(x + 6, y + 6); t.lineTo(x + 6, y + 7); t.lineTo(x - 6, y + 1); t.closePath(); } fillPath(ctx, t, rgba([20, 22, 30])); glow(ctx, x, 92 - h, 6, [255, 60, 60], 0.8, true); }
  crowd(ctx, R, -10, SW + 10, 94, 13, dark, { hands: 0.35, lights: [] });
  anchored(ctx, 'L', () => { glow(ctx, 50, 180, 200, [255, 160, 80], 0.3, true); if (o.land !== 'steppe') palm(ctx, R, 50, 340, 260, '#05060a', { lean: 0.25 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 50, 180, 200, [255, 160, 80], 0.3, true); const p = P2(); personPath(p, SW - 110, 330, 220, { armUp: 1 }); fillPath(ctx, p, '#05060a'); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#14161e'], [1, '#040408']]));
  glow(ctx, CX, F, 400, [255, 150, 70], 0.18, true);
  finish(ctx, { split: 0.2, vignette: 0.45 });
};

// Great peaks under the stars or at sunrise. o: { time: 'night'|'sunrise', peak: 'massif'|'spires'|'cone', snow, foreground: 'pines'|'tea'|'ruins'|'yurts'|'tents', milkyWay }
TEMPLATES.peaks = (ctx, R, o) => {
  const night = o.time !== 'sunrise';
  skyPreset(ctx, o.sky || (night ? 'night' : 'dawn'));
  ground(ctx, night ? ['#1a2236', '#0a0e18', '#04060a'] : ['#7a6a7a', '#2a2a36', '#0c0c12']);
  if (night) { stars(ctx, R, 220, [0, 0, SW, 70], { bright: 8 }); if (o.milkyWay !== false) milkyWay(ctx, R, 260, -30, 1100, 80, 34); }
  const lit = night ? [[200, 210, 240], [70, 80, 120]] : [[255, 214, 200], [120, 110, 150]];
  const pk = P2(), kind = o.peak || 'massif';
  if (kind === 'spires') { pk.moveTo(380, 88); for (const [x, y] of [[470, 50], [520, 30], [560, 46], [600, 10], [640, 30], [680, 4], [720, 26], [770, 18], [820, 48], [940, 88]]) pk.lineTo(x, y); }
  else if (kind === 'cone') { pk.moveTo(330, 88); pk.quadraticCurveTo(560, 70, 640, 10); pk.lineTo(704, 10); pk.quadraticCurveTo(780, 70, 1010, 88); }
  else if (kind === 'hills') { pk.moveTo(-20, 88); for (let x = -20; x <= SW + 20; x += 20) pk.lineTo(x, 44 + Math.sin(x * 0.006) * 14 + Math.sin(x * 0.019) * 6); pk.lineTo(SW + 20, 88); }
  else { pk.moveTo(280, 88); for (const [x, y] of [[440, 56], [530, 30], [600, 16], [650, 6], [700, 16], [760, 8], [840, 34], [960, 60], [1080, 88]]) pk.lineTo(x, y); }
  pk.closePath(); fillPath(ctx, pk, kind === 'hills' ? lin(ctx, 0, 30, 0, 88, [[0, rgba(night ? [40, 50, 70] : [90, 120, 110])], [1, rgba(night ? [20, 26, 40] : [40, 60, 50])]]) : lin(ctx, 0, 4, 0, 88, [[0, rgba(lit[0])], [0.4, rgba(mix(lit[0], lit[1], 0.5))], [1, rgba(lit[1])]]));
  if (kind === 'hills') withBlur(ctx, 8, () => { for (let i = 0; i < 10; i++) oval(ctx, between(R, 0, SW), between(R, 56, 80), between(R, 60, 140), 8, rgba([240, 230, 230], 0.45)); });
  const sh = P2(); if (kind !== 'hills') sh.moveTo(CX + 10, 4); sh.lineTo(CX + 120, 88); sh.lineTo(CX + 420, 88); sh.closePath(); fillPath(ctx, sh, rgba([20, 20, 50], 0.25));
  mountains(ctx, R, 90, 30, night ? [30, 36, 56] : [70, 76, 104], { bottom: 100, snow: o.snow !== false ? (night ? [180, 190, 220] : [240, 230, 240]) : null, snowLine: 0.7 });
  const fg = o.foreground || 'pines';
  if (fg === 'pines') forestLine(ctx, R, 94, 16, rgba([10, 16, 18]), { pines: true });
  if (fg === 'tea') { for (let y = 84; y < 100; y += 4) { const hl = P2(); hl.moveTo(-20, y); for (let x = -20; x <= SW + 20; x += 40) hl.quadraticCurveTo(x + 20, y - 3, x + 40, y); strokePath(ctx, hl, rgba([40, 80, 50], 0.9), 3); } }
  if (fg === 'ruins') { const r = P2(); r.rect(470, 70, 120, 24); for (let x = 470; x < 590; x += 10) r.rect(x, 66, 6, 4); r.rect(500, 58, 24, 12); fillPath(ctx, r, rgba([40, 34, 34])); }
  if (fg === 'yurts' || fg === 'tents') for (const x of [460, 530, 800, 880]) { const y = P2(); if (fg === 'yurts') { y.rect(x - 16, 82, 32, 12); y.moveTo(x - 18, 82); y.quadraticCurveTo(x, 68, x + 18, 82); y.closePath(); } else { y.moveTo(x - 16, 94); y.lineTo(x, 74); y.lineTo(x + 16, 94); y.closePath(); } fillPath(ctx, y, rgba([30, 26, 30])); glow(ctx, x, 88, 18, [255, 170, 80], 0.5, true); rect(ctx, x - 3, 86, 6, 8, rgba([255, 200, 120], 0.9)); }
  if (o.train) { const t = P2(); t.rect(420, 84, 26, 9); t.rect(426, 78, 6, 6); for (let k = 0; k < 3; k++) t.rect(450 + k * 28, 85, 25, 8); fillPath(ctx, t, rgba([30, 40, 70])); const tw = []; for (let k = 0; k < 3; k++) for (let j = 0; j < 4; j++) tw.push([453 + k * 28 + j * 6, 88, 1]); dots(ctx, tw, rgba([255, 220, 140])); withBlur(ctx, 5, () => oval(ctx, 420, 70, 16, 6, rgba([240, 240, 240], 0.4))); }
  if (o.extra) o.extra(ctx, R);
  anchored(ctx, 'L', () => { iconAt(ctx, 'pine-tree', 50, 340, 280, '#060a0c'); });
  anchored(ctx, 'R', () => { iconAt(ctx, 'pine-tree', SW - 60, 340, 260, '#060a0c'); glow(ctx, SW - 120, 260, 80, [255, 170, 80], 0.2, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, night ? '#14182a' : '#2a2a36'], [1, '#040408']]));
  finish(ctx, { split: 0.2, vignette: 0.45 });
};

// Calm water at dusk with boats, palms, nets. o.style: 'backwaters' | 'nile' | 'halong' | 'guilin' | 'floating'
TEMPLATES.waterway = (ctx, R, o) => {
  const style = o.style || 'backwaters', dark = '#0a0c0c', wc = o.waterC || [80, 100, 110];
  skyPreset(ctx, o.sky || 'golden');
  ground(ctx, [shade(wc, 0.1), shade(wc, -0.4), shade(wc, -0.8)]);
  sunDisc(ctx, o.sunX ?? CX - 240, 70, 20, [255, 120, 60], [255, 220, 140], 74);
  if (style === 'halong' || style === 'guilin') { karst(ctx, R, 74, 0, rgba([90, 90, 120]), { scale: 0.7 }); karst(ctx, R, 74, 0, rgba([50, 54, 76]), { scale: 1 }); }
  else if (style === 'nile') { ridge(ctx, R, 74, 10, rgba([140, 100, 80]), { bottom: 80 }); for (let x = 40; x < SW; x += between(R, 50, 120)) palm(ctx, R, x, 74, between(R, 26, 40), rgba([30, 30, 26])); }
  else { forestLine(ctx, R, 74, 10, rgba([30, 50, 36])); for (let x = 20; x < SW; x += between(R, 26, 60)) palm(ctx, R, x, 74, between(R, 30, 54), rgba([20, 34, 24])); }
  water(ctx, R, 74, 100, wc, { n: 50 }); reflection(ctx, R, o.sunX ?? CX - 240, 75, 98, [255, 200, 120], 50, 0.4);
  if (style === 'backwaters') {
    for (const [x, s] of [[520, 1], [860, 0.9]]) { const hb = P2(); hb.moveTo(x - 60 * s, 86); hb.quadraticCurveTo(x, 96, x + 60 * s, 84); hb.lineTo(x + 50 * s, 90); hb.lineTo(x - 50 * s, 90); hb.closePath(); hb.moveTo(x - 46 * s, 86); hb.quadraticCurveTo(x - 40 * s, 66 * s + 86 * (1 - s) - 0, x, 64 + (1 - s) * 10); hb.quadraticCurveTo(x + 40 * s, 66 + (1 - s) * 10, x + 46 * s, 86); hb.closePath(); fillPath(ctx, hb, rgba([40, 30, 20])); const ws = []; for (let k = -3; k <= 3; k++) ws.push([x + k * 11 * s, 80, 1.6]); dots(ctx, ws, rgba([255, 200, 120])); glow(ctx, x, 80, 40, [255, 170, 80], 0.3, true); }
    const net = P2(); const nx = 360, ny = 40; net.moveTo(nx, 86); net.lineTo(nx + 40, ny); net.moveTo(nx + 60, 86); net.lineTo(nx + 40, ny); net.moveTo(nx + 40, ny); net.quadraticCurveTo(nx + 10, ny + 10, nx - 30, ny + 30); net.lineTo(nx + 20, ny + 36); net.lineTo(nx + 70, ny + 26); net.quadraticCurveTo(nx + 60, ny + 10, nx + 40, ny); strokePath(ctx, net, dark, 1.2);
  }
  if (style === 'nile') { felucca(ctx, 520, 88, 50, dark, { sail: [240, 230, 210] }); felucca(ctx, 840, 86, 40, dark, { flip: true, sail: [240, 230, 210] }); }
  if (style === 'halong') { junk(ctx, 520, 88, 46, dark, { sail: [180, 60, 40] }); junk(ctx, 860, 86, 38, dark, { flip: true, sail: [180, 60, 40] }); }
  if (style === 'guilin') { for (const x of [540, 820]) { const r = P2(); r.rect(x - 30, 86, 60, 3); fillPath(ctx, r, dark); const f = P2(); personPath(f, x, 86, 22); fillPath(ctx, f, dark); glow(ctx, x + 20, 76, 16, [255, 170, 80], 0.6, true); const b = P2(); b.ellipse(x - 18, 80, 4, 3, 0, 0, TAU); fillPath(ctx, b, dark); } }
  if (style === 'floating') { for (const x of [460, 540, 620, 760, 840, 920]) { canoe(ctx, x, 88, 30, dark, { crew: 1 }); const fr = []; for (let k = 0; k < 8; k++) fr.push([x + between(R, -20, 20), 84 + between(R, -2, 1), between(R, 1.6, 2.6)]); dots(ctx, fr, rgba(pick(R, [[240, 120, 40], [240, 200, 40], [120, 180, 60], [200, 40, 60]]))); const h = P2(); h.moveTo(x - 6, 74); h.lineTo(x + 6, 74); h.lineTo(x, 70); h.closePath(); fillPath(ctx, h, rgba([200, 170, 110])); } }
  anchored(ctx, 'L', () => { if (style === 'halong' || style === 'guilin') { const r = P2(); r.moveTo(-20, 340); r.quadraticCurveTo(0, 40, 90, 60); r.quadraticCurveTo(160, 120, 170, 340); r.closePath(); fillPath(ctx, r, '#14181c'); } else palm(ctx, R, 40, 340, 280, dark, { lean: 0.3 }); });
  anchored(ctx, 'R', () => { if (style === 'halong' || style === 'guilin') { const r = P2(); r.moveTo(SW + 20, 340); r.quadraticCurveTo(SW, 60, SW - 100, 80); r.quadraticCurveTo(SW - 170, 140, SW - 160, 340); r.closePath(); fillPath(ctx, r, '#14181c'); } else palm(ctx, R, SW - 50, 340, 260, dark, { lean: -0.3 }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, rgba(shade(wc, -0.3))], [1, rgba(shade(wc, -0.85))]]));
  const rf = P2(); for (let i = 0; i < 60; i++) { const x = between(R, 0, SW), y = between(R, F, SH); rf.moveTo(x, y); rf.lineTo(x + between(R, 10, 40), y); } strokePath(ctx, rf, rgba([255, 220, 160], 0.15), 1);
  finish(ctx, { split: 0.3, vignette: 0.42 });
};

// Storm at sea with a lighthouse and lightning. o: { lighthouse: true, cliffs: true, rain }
TEMPLATES.storm = (ctx, R, o) => {
  const dark = '#06080a';
  skyPreset(ctx, 'storm');
  ground(ctx, ['#2a3a44', '#101820', '#04080a']);
  withBlur(ctx, 10, () => { for (let i = 0; i < 14; i++) oval(ctx, between(R, -50, SW + 50), between(R, -10, 40), between(R, 80, 180), between(R, 14, 26), rgba([20, 24, 34], 0.6)); });
  additive(ctx, () => { const l = P2(); let x = 420, y = -4; l.moveTo(x, y); while (y < 80) { x += between(R, -14, 14); y += between(R, 6, 12); l.lineTo(x, y); } strokePath(ctx, l, rgba([220, 230, 255], 0.9), 1.6); glow(ctx, 420, 20, 120, [180, 200, 255], 0.35); });
  water(ctx, R, 70, 100, [30, 50, 64], { n: 80, glintA: 0.25 });
  const waves = P2(); for (let x = -20; x < SW + 20; x += 30) { waves.moveTo(x, 76 + between(R, -2, 2)); waves.quadraticCurveTo(x + 10, 68, x + 22, 74); } strokePath(ctx, waves, rgba([220, 230, 240], 0.45), 1.6);
  if (o.cliffs !== false) { const c = P2(); c.moveTo(760, 100); c.lineTo(790, 62); c.lineTo(860, 54); c.lineTo(1000, 56); c.lineTo(1060, 70); c.lineTo(1100, 100); c.closePath(); fillPath(ctx, c, rgba([18, 22, 26])); }
  if (o.lighthouse !== false) lighthouse(ctx, 900, 56, 50, rgba([220, 220, 220]), { stripes: [200, 40, 40], beamAngle: -2.8 });
  if (o.ship) iconAt(ctx, 'galleon', 520, 86, 40, dark);
  const rn = P2(); for (let i = 0; i < 420; i++) { const x = between(R, 0, SW), y = between(R, 0, SH); rn.moveTo(x, y); rn.lineTo(x - 3, y + 10); } strokePath(ctx, rn, rgba([200, 210, 230], 0.22), 0.7);
  anchored(ctx, 'L', () => { if (o.palms !== false) palm(ctx, R, 40, 340, 280, dark, { lean: 0.5 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 200, 160, [255, 200, 120], 0.2, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#1a2228'], [1, '#04060a']]));
  finish(ctx, { split: 0.2, vignette: 0.5 });
};

// Waterfalls over cliffs. o: { style: 'monsoon'|'lakes'|'great'|'night', rainbow }
TEMPLATES.waterfalls = (ctx, R, o) => {
  const style = o.style || 'monsoon', night = style === 'night';
  skyPreset(ctx, o.sky || (night ? 'night' : style === 'monsoon' ? 'storm' : 'golden'));
  ground(ctx, night ? ['#1a2236', '#0a0e18', '#04060a'] : ['#3a5a4a', '#16241c', '#060c08']);
  const cliffC = night ? [30, 34, 46] : style === 'monsoon' ? [44, 60, 46] : [70, 80, 60];
  const cl = P2(); cl.moveTo(-20, 100); cl.lineTo(-20, 30); for (let x = -20; x <= SW + 20; x += 40) cl.lineTo(x, 26 + Math.sin(x * 0.02) * 6); cl.lineTo(SW + 20, 100); cl.closePath();
  fillPath(ctx, cl, lin(ctx, 0, 20, 0, 100, [[0, rgba(shade(cliffC, 0.2))], [1, rgba(shade(cliffC, -0.4))]]));
  canopy(ctx, R, CX, 20, SW * 1.2, 16, night ? [24, 30, 30] : [60, 100, 60], night ? [10, 14, 14] : [24, 50, 30], { n: 160 });
  const falls = style === 'great' ? [[380, 90], [480, 70], [560, 110], [760, 120], [860, 80], [960, 90]] : [[440, 40], [560, 26], [790, 34], [900, 22]];
  for (const [x, w] of falls) { const f = P2(); f.moveTo(x - w / 2, 28); f.quadraticCurveTo(x - w / 2 - 4, 60, x - w / 2 - 8, 96); f.lineTo(x + w / 2 + 8, 96); f.quadraticCurveTo(x + w / 2 + 4, 60, x + w / 2, 28); f.closePath(); fillPath(ctx, f, lin(ctx, 0, 28, 0, 96, [[0, rgba([230, 240, 245], 0.9)], [1, rgba([200, 220, 230], 0.6)]])); const st = P2(); for (let k = 0; k < w; k += 3) { st.moveTo(x - w / 2 + k, 30); st.lineTo(x - w / 2 + k + between(R, -3, 3), 94); } strokePath(ctx, st, rgba([255, 255, 255], 0.35), 0.8); if (night) glow(ctx, x, 70, w, [140, 180, 255], 0.25, true); }
  withBlur(ctx, 10, () => { for (let i = 0; i < 10; i++) oval(ctx, between(R, 340, 1000), between(R, 84, 96), between(R, 40, 90), 10, rgba([240, 245, 250], 0.4)); });
  if (o.rainbow) additive(ctx, () => { const cs = [[255, 60, 60], [255, 160, 40], [255, 240, 60], [60, 200, 80], [60, 120, 255], [140, 60, 200]]; cs.forEach((c, i) => { const a = P2(); a.arc(700, 140, 110 - i * 3, Math.PI * 1.1, Math.PI * 1.9); strokePath(ctx, a, rgba(c, 0.18), 3, 'butt'); }); });
  if (style === 'monsoon') { const rn = P2(); for (let i = 0; i < 300; i++) { const x = between(R, 0, SW), y = between(R, 0, SH); rn.moveTo(x, y); rn.lineTo(x - 2, y + 9); } strokePath(ctx, rn, rgba([220, 230, 240], 0.2), 0.7); }
  anchored(ctx, 'L', () => { canopy(ctx, R, 30, 120, 200, 200, night ? [20, 26, 26] : [50, 90, 50], night ? [8, 10, 10] : [20, 40, 20]); });
  anchored(ctx, 'R', () => { canopy(ctx, R, SW - 30, 120, 200, 200, night ? [20, 26, 26] : [50, 90, 50], night ? [8, 10, 10] : [20, 40, 20]); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#2a3a40'], [1, '#04080a']]));
  const rf = P2(); for (let i = 0; i < 60; i++) { const x = between(R, 0, SW), y = between(R, F, SH); rf.moveTo(x, y); rf.lineTo(x + between(R, 10, 40), y); } strokePath(ctx, rf, rgba([230, 240, 255], 0.15), 1);
  finish(ctx, { split: 0.2, vignette: 0.45 });
};

// A ring of dancers around light: garba, a bonfire, midsummer. o.center: 'lamp'|'fire'|'pole'
TEMPLATES.dancers = (ctx, R, o) => {
  const dark = '#0a0608', c = o.light || [255, 160, 60];
  skyPreset(ctx, o.sky || 'warmNight');
  ground(ctx, ['#3a2018', '#160a08', '#060404']);
  stars(ctx, R, 60, [0, 0, SW, 40], { bright: 2 });
  if (o.canopyLights !== false) for (let k = 0; k < 9; k++) { const a = (k / 8) * Math.PI; const ex = CX + Math.cos(Math.PI - a) * 620, ey = 2 + Math.sin(a) * 10; stringLights(ctx, CX, -6, ex, ey + 60, 12, 14, pick(R, o.bulbs || [[255, 200, 120], [255, 80, 120], [120, 200, 255], [255, 240, 120]]), 1.2, { noGlow: true }); }
  if (o.landmark) o.landmark(ctx, R);
  if (o.center === 'fire' || o.center === 'pole') {
    if (o.center === 'pole') { line(ctx, CX - 240, 10, CX - 240, 92, dark, 2.4); const ring = P2(); ring.ellipse(CX - 240, 24, 18, 5, 0, 0, TAU); strokePath(ctx, ring, rgba([60, 120, 50]), 3); }
    for (const fx of [CX - 240, CX + 240]) { glow(ctx, fx, 70, 120, [255, 140, 40], 0.7, true); const f = P2(); f.moveTo(fx - 18, 94); f.quadraticCurveTo(fx - 26, 60, fx, 30); f.quadraticCurveTo(fx + 26, 60, fx + 18, 94); f.closePath(); additive(ctx, () => fillPath(ctx, f, lin(ctx, 0, 30, 0, 94, [[0, rgba([255, 240, 170], 0.25)], [1, rgba([255, 120, 30], 0.9)]]))); const sp = []; for (let i = 0; i < 40; i++) sp.push([fx + between(R, -40, 40), between(R, 0, 60), 0.9]); dots(ctx, sp, rgba([255, 200, 120], 0.8)); }
  } else { for (const fx of [CX - 240, CX + 240]) { glow(ctx, fx, 70, 70, c, 0.6, true); const l = P2(); l.rect(fx - 6, 62, 12, 30); l.moveTo(fx - 10, 62); l.lineTo(fx, 50); l.lineTo(fx + 10, 62); l.closePath(); fillPath(ctx, l, rgba([200, 150, 60])); const ho = []; for (let k = 0; k < 10; k++) ho.push([fx + between(R, -4, 4), between(R, 64, 88), 1.2]); dots(ctx, ho, rgba([255, 230, 160])); } }
  // the ring of dancers in swirling skirts
  const cols = o.skirts || [[230, 40, 80], [255, 180, 30], [40, 160, 120], [120, 60, 200], [255, 100, 40]];
  for (const fx of [CX - 240, CX + 240]) for (let k = 0; k < 12; k++) {
    const a = (k / 12) * TAU + 0.3, x = fx + Math.cos(a) * 110, y = 94 + Math.sin(a) * 3, s = 30 + Math.sin(a) * 4;
    if (Math.abs(x - CX) < 50) continue;
    const p = P2(); personPath(p, x, y, s, { armUp: k % 3 === 0 ? 2 : 1 }); fillPath(ctx, p, dark);
    if (o.skirts !== false) { const sk = P2(); sk.moveTo(x - s * 0.1, y - s * 0.46); sk.quadraticCurveTo(x - s * 0.32, y - s * 0.1, x - s * 0.28, y - s * 0.04); sk.lineTo(x + s * 0.28, y - s * 0.04); sk.quadraticCurveTo(x + s * 0.32, y - s * 0.1, x + s * 0.1, y - s * 0.46); sk.closePath(); fillPath(ctx, sk, rgba(cols[k % cols.length], 0.95)); }
    if (o.sticks) line(ctx, x + s * 0.12, y - s * 0.8, x + s * 0.32, y - s * 1.05, rgba([240, 200, 80]), 1);
  }
  crowd(ctx, R, -10, SW + 10, 96, 12, dark, { hands: 0.3 });
  anchored(ctx, 'L', () => { glow(ctx, 60, 200, 180, c, 0.35, true); const p = P2(); personPath(p, 80, 330, 220, { armUp: 2 }); fillPath(ctx, p, dark); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 200, 180, c, 0.35, true); const p = P2(); personPath(p, SW - 90, 330, 230, { armUp: 1 }); fillPath(ctx, p, dark); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#3a2018'], [1, '#060404']]));
  glow(ctx, CX, F, 500, c, 0.18, true);
  finish(ctx, { split: 0.25, vignette: 0.45 });
};

// A flat white land under a full moon: salt desert, salt mirror, snowfield.
TEMPLATES.saltFlat = (ctx, R, o) => {
  const dark = '#0a0c14', mirror = o.mirror;
  skyPreset(ctx, o.sky || 'night');
  ground(ctx, ['#dfe6f2', '#7a86a6', '#1a1e2c']);
  stars(ctx, R, 200, [0, 0, SW, 60], { bright: 6 });
  moon(ctx, o.moonX ?? CX + 230, 24, 14, { halo: 7 });
  if (o.hills) mountains(ctx, R, 70, 16, [60, 66, 96], { bottom: 76 });
  rect(ctx, 0, 70, SW, 30, lin(ctx, 0, 70, 0, 100, [[0, '#c8d2e8'], [1, '#8a96b8']]));
  if (mirror) { const st = []; for (let i = 0; i < 120; i++) st.push([between(R, 0, SW), between(R, 72, 98), between(R, 0.4, 0.9)]); dots(ctx, st, rgba([255, 255, 255], 0.6)); reflection(ctx, R, o.moonX ?? CX + 230, 71, 98, [255, 255, 240], 30, 0.4); }
  else { const cr = P2(); for (let i = 0; i < 90; i++) { const x = between(R, 0, SW), y = between(R, 72, 98); cr.moveTo(x, y); cr.lineTo(x + between(R, 6, 20), y + between(R, -1, 1)); cr.lineTo(x + between(R, 4, 14), y + between(R, 1, 3)); } strokePath(ctx, cr, rgba([90, 100, 140], 0.35), 0.8); }
  if (o.tents) for (const x of [440, 500, 560, 800, 860, 920]) { const t = P2(); t.ellipse(x, 84, 14, 12, 0, Math.PI, TAU); t.rect(x - 14, 84, 28, 8); fillPath(ctx, t, rgba([120, 40, 40])); glow(ctx, x, 86, 20, [255, 170, 80], 0.45, true); rect(ctx, x - 3, 85, 6, 7, rgba([255, 210, 130])); }
  if (o.walkers) { const p = P2(); for (const x of [600, 640, 760]) personPath(p, x, 92, 24); fillPath(ctx, p, dark); }
  if (o.extra) o.extra(ctx, R);
  anchored(ctx, 'L', () => { glow(ctx, 60, 200, 180, [200, 210, 255], 0.2, true); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 200, 180, [200, 210, 255], 0.2, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#6a7494'], [1, '#141824']]));
  finish(ctx, { split: 0.15, vignette: 0.45 });
};

// A palace outlined in light bulbs (Mysore Dasara), or a monument under the moon.
TEMPLATES.palaceLights = (ctx, R, o) => {
  skyPreset(ctx, 'deepNight');
  ground(ctx, ['#2a2020', '#120c0c', '#060404']);
  stars(ctx, R, 60, [0, 0, SW, 30], { alpha: 0.6 });
  // the palace: wings, central tower with a dome, every edge lit
  const p = P2(), edges = [];
  const box = (x, y, w, h) => { p.rect(x, y, w, h); edges.push([x, y, x + w, y], [x, y, x, y + h], [x + w, y, x + w, y + h]); };
  box(CX - 420, 54, 280, 40); box(CX + 140, 54, 280, 40); box(CX - 140, 36, 280, 58);
  for (const x of [CX - 420, CX - 140, CX + 140, CX + 420]) { box(x - 12, 40, 24, 54); p.moveTo(x - 12, 40); p.quadraticCurveTo(x, 22, x + 12, 40); p.closePath(); }
  box(CX - 26, 6, 52, 30); p.moveTo(CX - 30, 6); p.quadraticCurveTo(CX, -26, CX + 30, 6); p.closePath();
  fillPath(ctx, p, rgba([40, 30, 34]));
  const bulbs = [];
  for (const [x0, y0, x1, y1] of edges) { const n = Math.max(2, Math.round(Math.hypot(x1 - x0, y1 - y0) / 4)); for (let k = 0; k <= n; k++) bulbs.push([lerp(x0, x1, k / n), lerp(y0, y1, k / n), 0.9]); }
  for (let y = 60; y < 94; y += 8) for (let x = CX - 410; x < CX + 420; x += 12) if (Math.abs(x - CX) > 150 || y > 44) bulbs.push([x, y, 0.7]);
  for (let t = 0; t <= 1; t += 0.03) { const a = Math.PI + t * Math.PI; bulbs.push([CX + Math.cos(a) * 30, 6 + Math.sin(a) * 32 * 0.95, 0.9]); }
  glow(ctx, CX, 60, 520, [255, 190, 90], 0.35, true);
  dots(ctx, bulbs, rgba([255, 220, 140]));
  for (const [x, y] of bulbs.filter((_, i) => i % 6 === 0)) glow(ctx, x, y, 5, [255, 200, 110], 0.3, true);
  if (o.elephants) for (const [x, f] of [[480, false], [880, true]]) { rimIcon(ctx, 'elephant', x, 96, 52, '#0a0606', [255, 200, 120], { flip: f }); const c = P2(); c.rect(x - 14, 96 - 40, 28, 14); fillPath(ctx, c, rgba([200, 30, 40], 0.9)); }
  crowd(ctx, R, -10, SW + 10, 96, 13, '#0a0606', { hands: 0.2 });
  anchored(ctx, 'L', () => { glow(ctx, 50, 160, 180, [255, 190, 90], 0.35, true); canopy(ctx, R, 30, 120, 200, 200, [20, 24, 16], [6, 8, 6]); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 50, 160, 180, [255, 190, 90], 0.35, true); canopy(ctx, R, SW - 30, 120, 200, 200, [20, 24, 16], [6, 8, 6]); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#2a2018'], [1, '#060404']]));
  glow(ctx, CX, F, 500, [255, 180, 80], 0.18, true);
  finish(ctx, { split: 0.2, vignette: 0.45 });
};

// One monument under a big moon, in ruins and gardens. o.kind: 'minaret'|'stones'|'pyramids'|'columns'|'castle'|'tower'
TEMPLATES.monumentMoon = (ctx, R, o) => {
  const dark = o.dark || '#0c0a10';
  skyPreset(ctx, o.sky || 'night');
  ground(ctx, ['#2a2a36', '#101018', '#040408']);
  stars(ctx, R, 140, [0, 0, SW, 70], { bright: 4 });
  moon(ctx, o.moonX ?? CX + 180, o.moonY ?? 30, 18, { halo: 7 });
  if (o.land === 'dunes') ridge(ctx, R, 88, 14, rgba([60, 50, 50]), { bottom: 100 }); else forestLine(ctx, R, 90, 12, rgba([18, 20, 22]));
  const k = o.kind || 'minaret';
  if (k === 'minaret') { minaretTower(ctx, CX - 170, 92, 96, rgba([90, 60, 56])); const r = P2(); for (let x = 760; x < 1000; x += 30) { r.moveTo(x, 92); r.lineTo(x, 66); r.quadraticCurveTo(x + 13, 52, x + 26, 66); r.lineTo(x + 26, 92); r.lineTo(x + 22, 92); r.lineTo(x + 22, 68); r.quadraticCurveTo(x + 13, 58, x + 4, 68); r.lineTo(x + 4, 92); r.closePath(); } fillPath(ctx, r, rgba([60, 44, 44])); }
  if (k === 'stones') { stoneCircle(ctx, CX - 1.5, 93, 300, rgba([160, 170, 200], 0.6)); stoneCircle(ctx, CX, 94, 300, rgba([50, 52, 64])); }
  if (k === 'pyramids') { pyramid(ctx, CX - 220, 92, 200, rgba([110, 90, 70]), rgba([60, 50, 44])); pyramid(ctx, CX + 200, 92, 170, rgba([110, 90, 70]), rgba([60, 50, 44])); pyramid(ctx, CX + 360, 92, 90, rgba([110, 90, 70]), rgba([60, 50, 44])); }
  if (k === 'columns') columns(ctx, CX - 330, CX - 90, 92, 70, 8, rgba([170, 160, 150]), { roof: true, broken: [] });
  if (k === 'castle') castleOnRock(ctx, R, CX - 200, 94, 70, rgba([20, 18, 26]), { cones: true, lit: [255, 200, 120] });
  if (k === 'tower') o.tower(ctx, R);
  if (o.bats) birds(ctx, R, 700, 10, 1000, 50, 12, rgba([10, 8, 12]), 3);
  if (o.extra) o.extra(ctx, R);
  anchored(ctx, 'L', () => { canopy(ctx, R, 30, 120, 200, 200, [20, 24, 24], [6, 8, 8]); });
  anchored(ctx, 'R', () => { canopy(ctx, R, SW - 30, 120, 200, 200, [20, 24, 24], [6, 8, 8]); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#1c1c26'], [1, '#040408']]));
  finish(ctx, { split: 0.15, vignette: 0.45 });
};
