// Templates for Europe and beyond: sieges, ancient armies, longships, winter
// citadels, star forts; terraces, cellars, ice bars; races; fields, canals,
// volcanoes, aurora, trains.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

// ---------- war & history ----------
function knight(ctx, x, base, h, c, o = {}) { const p = P2(); personPath(p, x, base, h); const s = h / 100; p.moveTo(x - 8 * s, base - 82 * s); p.lineTo(x + 8 * s, base - 82 * s); p.lineTo(x + 8 * s, base - 100 * s); p.quadraticCurveTo(x, base - 104 * s, x - 8 * s, base - 100 * s); p.closePath(); p.moveTo(x - 22 * s, base - 70 * s); p.lineTo(x - 8 * s, base - 70 * s); p.lineTo(x - 9 * s, base - 46 * s); p.quadraticCurveTo(x - 15 * s, base - 36 * s, x - 21 * s, base - 46 * s); p.closePath(); fillPath(ctx, p, c); if (o.sword) line(ctx, x + 10 * s, base - 60 * s, x + 22 * s, base - 108 * s, c, 2.4 * s); if (o.cross) { const cr = P2(); cr.rect(x - 16 * s, base - 66 * s, 2.4 * s, 16 * s); cr.rect(x - 21 * s, base - 60 * s, 12 * s, 2.4 * s); fillPath(ctx, cr, rgba(o.cross)); } }
// European castle siege. o.castle: 'keep'|'conical'|'brick'|'island'; o.banner; o.engines
TEMPLATES.castleSiege = (ctx, R, o) => {
  const dark = '#0a0a10', stone = o.stone || [96, 92, 100], ban = o.banner || [200, 30, 40], ban2 = o.banner2 || [240, 220, 120];
  skyPreset(ctx, o.sky || 'dusk');
  ground(ctx, o.ground || ['#c87850', '#4a2a22', '#120c0c']);
  stars(ctx, R, 40, [CX + 150, 0, SW, 34], { bright: 2, alpha: 0.6 });
  glow(ctx, CX - 320, 80, 360, [255, 120, 50], 0.45, true);
  if (o.castle === 'island') { water(ctx, R, 72, 100, [60, 80, 110], { n: 40 }); reflection(ctx, R, CX - 320, 73, 96, [255, 180, 100], 50, 0.4); }
  else ridge(ctx, R, 80, 22, rgba(shade(stone, -0.5)), { freqs: [0.006, 0.02], bottom: 100 });
  // the castle behind the dealer: curtain wall, towers, a gatehouse
  const sc = o.castle === 'brick' || o.castle === 'island' ? [150, 60, 46] : stone;
  const fill = lin(ctx, 0, 0, 0, 80, [[0, rgba(shade(sc, 0.05))], [1, rgba(shade(sc, -0.45))]]);
  const cw = P2(), cx0 = CX - 300, cx1 = CX + 300, wt = 44;
  cw.rect(cx0, wt, cx1 - cx0, 40); for (let x = cx0; x < cx1; x += 10) cw.rect(x, wt - 5, 6, 5);
  const cone = o.castle === 'conical', towers = cone ? [[CX - 300, 40, 14], [CX - 150, 34, 16], [CX + 150, 34, 16], [CX + 300, 40, 14], [CX, 26, 22]] : [[CX - 300, 26, 16], [CX - 150, 20, 18], [CX + 150, 20, 18], [CX + 300, 26, 16], [CX, 6, 26]];
  for (const [tx, tt, tw] of towers) { cw.rect(tx - tw, tt, tw * 2, 84 - tt); if (cone) { cw.moveTo(tx - tw - 3, tt); cw.lineTo(tx, tt - tw * 1.5); cw.lineTo(tx + tw + 3, tt); cw.closePath(); } else for (let k = 0; k < 4; k++) cw.rect(tx - tw + k * tw * 0.55, tt - 5, tw * 0.3, 5); }
  fillPath(ctx, cw, fill);
  if (o.castle === 'brick') { const br = P2(); for (let y = wt + 4; y < 84; y += 5) { br.moveTo(cx0, y); br.lineTo(cx1, y); } strokePath(ctx, br, rgba([60, 20, 16], 0.4), 0.8, 'butt'); const tr = P2(); for (const [tx, tt, tw] of towers) { tr.moveTo(tx - tw, tt); tr.lineTo(tx, tt - tw * 1.6); tr.lineTo(tx + tw, tt); tr.closePath(); } fillPath(ctx, tr, rgba([60, 40, 40])); }
  const wins = []; for (const [tx, tt] of towers) for (let k = 0; k < 2; k++) wins.push([tx, tt + 12 + k * 14]); for (const [x, y] of wins) { glow(ctx, x, y, 9, [255, 170, 80], 0.35, true); rect(ctx, x - 1.6, y - 3, 3.2, 6, rgba([255, 210, 140])); }
  rect(ctx, CX - 18, 50, 36, 34, '#0a0405'); glow(ctx, CX, 78, 40, [255, 140, 60], 0.45, true);
  for (const [tx, tt, tw] of towers.slice(0, 4)) { const top = tt - (cone ? tw * 1.5 : 4); line(ctx, tx, top, tx, top - 12, dark, 1.2); pennant(ctx, tx, top - 12, 14, 7, ban); }
  if (o.castle === 'island') { rect(ctx, CX - 330, 82, 660, 6, rgba([40, 30, 30])); }
  horizonHaze(ctx, 84, 10, [255, 170, 110], 0.4);
  // the besiegers: engines left, knights right, archers and banners on the flanks
  const eng = o.engines || 'trebuchet';
  if (o.left === 'archers') { for (const [x, s] of [[470, 46], [520, 50], [570, 46], [615, 44]]) rimIcon(ctx, 'bowman', x, 96, s, dark, [255, 170, 100]); additive(ctx, () => { const ar = P2(); for (let i = 0; i < 14; i++) { const x0 = between(R, 480, 640), y0 = between(R, 10, 40); ar.moveTo(x0, y0); ar.lineTo(x0 + 14, y0 - 4); } strokePath(ctx, ar, rgba([255, 220, 160], 0.6), 0.8); }); }
  else for (const [x, s] of [[500, 66], [600, 54]]) { rimIcon(ctx, eng, x, 96, s, dark, [255, 170, 100]); }
  additive(ctx, () => { const fl = P2(); fl.moveTo(540, 30); fl.quadraticCurveTo(600, -10, 690, 20); strokePath(ctx, fl, lin(ctx, 540, 0, 690, 0, [[0, rgba([255, 200, 120], 0)], [1, rgba([255, 160, 60], 0.8)]]), 1.8); }); glow(ctx, 690, 20, 10, [255, 180, 80], 0.8, true);
  for (const [x, s] of [[760, 50], [830, 54], [900, 48]]) rimIcon(ctx, 'mounted-knight', x, 96, s, dark, [255, 170, 100], { flip: true, dx: 1.4 });
  const ranks = P2(); for (let x = 120; x < SW - 120; x += between(R, 10, 15)) { if (x > HERO_L[0] - 10 && x < HERO_R[1] + 10) continue; soldierPath(ranks, x, 94 + R() * 2, between(R, 20, 24), { spearSide: R() < 0.5 ? -1 : 1 }); }
  fillPath(ctx, ranks, dark);
  for (const x of [190, 300, 400, 1000, 1100, 1210]) { line(ctx, x, 44, x, 92, dark, 1.4); const f = P2(); f.rect(x, 44, 12, 18); fillPath(ctx, f, rgba(R() < 0.5 ? ban : ban2)); }
  anchored(ctx, 'L', () => { glow(ctx, 40, 160, 220, [255, 150, 70], 0.4, true); rimIcon(ctx, eng, 80, 340, 260, '#08080c', [255, 170, 100], { dx: 1.2 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 40, 160, 220, [255, 150, 70], 0.35, true); knight(ctx, SW - 100, 340, 240, '#08080c', { sword: true, cross: o.cross }); line(ctx, SW - 170, 0, SW - 170, 260, '#08080c', 3); const f = P2(); f.rect(SW - 170, 0, -60, 90); fillPath(ctx, f, rgba(ban)); if (o.cross) { rect(ctx, SW - 206, 10, 12, 70, rgba(o.cross)); rect(ctx, SW - 226, 34, 52, 12, rgba(o.cross)); } });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#3a2a22'], [1, '#0c0808']]));
  finish(ctx, { split: 0.35 });
};

// Legion or phalanx before a temple. o.army: 'roman' | 'greek'
TEMPLATES.ancientArmy = (ctx, R, o) => {
  const dark = '#0c0a0a', greek = o.army === 'greek', ban = o.banner || (greek ? [40, 80, 160] : [170, 20, 30]), gold = [230, 180, 60];
  skyPreset(ctx, o.sky || 'golden');
  ground(ctx, ['#d8a060', '#5a3a20', '#140c08']);
  sunDisc(ctx, CX - 260, 70, 22, [255, 120, 50], [255, 220, 140], 76);
  ridge(ctx, R, 78, 30, rgba([150, 100, 90]), { bottom: 100 });
  // the temple on the hill behind the dealer
  const hill = P2(); hill.moveTo(CX - 330, 96); hill.quadraticCurveTo(CX - 200, 46, CX, 44); hill.quadraticCurveTo(CX + 200, 46, CX + 330, 96); hill.closePath(); fillPath(ctx, hill, rgba([120, 80, 66]));
  columns(ctx, CX - 130, CX + 130, 44, 30, 10, rgba([236, 220, 196]), { roof: true });
  // the army
  for (let row = 0; row < 2; row++) { const ranks = P2(); for (let x = 120 + row * 6; x < SW - 120; x += 11) { if (x > DEALER[0] - 30 && x < DEALER[1] + 30) continue; soldierPath(ranks, x, 92 + row * 4, 22 + row * 2, { spearSide: 1 }); } fillPath(ctx, ranks, dark); const sh = P2(); for (let x = 120 + row * 6; x < SW - 120; x += 11) { if (x > DEALER[0] - 30 && x < DEALER[1] + 30) continue; if (greek) sh.ellipse(x - 2, 92 + row * 4 - 14, 5, 5, 0, 0, TAU); else sh.rect(x - 6, 92 + row * 4 - 19, 7, 11); } fillPath(ctx, sh, rgba(greek ? [180, 140, 60] : ban)); }
  for (const x of [470, 560, 800, 890]) { line(ctx, x, 30, x, 92, dark, 1.6); if (greek) { const f = P2(); f.rect(x - 8, 30, 16, 12); fillPath(ctx, f, rgba(ban)); } else { const e = P2(); e.moveTo(x - 9, 30); e.quadraticCurveTo(x, 22, x + 9, 30); e.lineTo(x, 26); e.closePath(); fillPath(ctx, e, rgba(gold)); rect(ctx, x - 7, 34, 14, 16, rgba(ban)); } }
  anchored(ctx, 'L', () => { glow(ctx, 60, 170, 200, [255, 170, 90], 0.35, true); const p = P2(); soldierPath(p, 90, 340, 240, { spearSide: 1 }); fillPath(ctx, p, '#0a0808'); const s = P2(); if (greek) s.ellipse(60, 230, 46, 46, 0, 0, TAU); else s.rect(30, 190, 60, 96); fillPath(ctx, s, rgba(greek ? [190, 150, 60] : ban)); if (!greek) { const cr = P2(); cr.ellipse(60, 238, 12, 12, 0, 0, TAU); fillPath(ctx, cr, rgba(gold)); } const hc = P2(); hc.moveTo(76, 112); hc.quadraticCurveTo(96, 86, 120, 104); hc.lineTo(110, 110); hc.closePath(); fillPath(ctx, hc, rgba(greek ? [170, 30, 30] : [170, 20, 30])); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 170, 200, [255, 170, 90], 0.3, true); columns(ctx, SW - 180, SW - 20, 340, 260, 3, rgba([200, 186, 166]), { broken: [1] }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#6a4a30'], [1, '#140c08']]));
  finish(ctx, { split: 0.3 });
};

function longship(ctx, x, base, s, c, o = {}) {
  const d = o.flip ? -1 : 1, p = P2();
  p.moveTo(x - d * s, base - s * 0.5); p.quadraticCurveTo(x - d * s * 0.9, base - s * 0.05, x - d * s * 0.5, base); p.lineTo(x + d * s * 0.5, base); p.quadraticCurveTo(x + d * s * 0.9, base - s * 0.05, x + d * s, base - s * 0.5); p.quadraticCurveTo(x + d * s * 1.08, base - s * 0.62, x + d * s * 0.98, base - s * 0.64); p.quadraticCurveTo(x + d * s * 0.82, base - s * 0.2, x, base - s * 0.16); p.quadraticCurveTo(x - d * s * 0.82, base - s * 0.2, x - d * s * 0.98, base - s * 0.62); p.closePath();
  p.rect(x - 0.8, base - s * 1.3, 1.6, s * 1.2); fillPath(ctx, p, c);
  const sail = P2(); sail.moveTo(x - s * 0.45, base - s * 1.2); sail.lineTo(x + s * 0.45, base - s * 1.2); sail.quadraticCurveTo(x + s * 0.5, base - s * 0.7, x + s * 0.4, base - s * 0.4); sail.lineTo(x - s * 0.4, base - s * 0.4); sail.quadraticCurveTo(x - s * 0.5, base - s * 0.7, x - s * 0.45, base - s * 1.2); fillPath(ctx, sail, rgba(o.sail || [180, 40, 40]));
  const st = P2(); for (let k = -2; k <= 2; k += 2) st.rect(x + k * s * 0.18 - s * 0.05, base - s * 1.2, s * 0.1, s * 0.8); fillPath(ctx, st, rgba([240, 230, 210], 0.85));
  const sh = []; for (let k = -6; k <= 6; k++) sh.push([x + k * s * 0.11, base - s * 0.22, s * 0.06]); dots(ctx, sh, rgba(o.shields || [200, 170, 80]));
}
TEMPLATES.vikings = (ctx, R, o) => {
  const dark = '#06080c';
  skyPreset(ctx, 'blueHour');
  ground(ctx, ['#3a4a5a', '#141c24', '#05080a']);
  moon(ctx, 980, 20, 8, { halo: 6 }); stars(ctx, R, 60, [0, 0, SW, 40], { bright: 2 });
  aurora(ctx, R, 22, [[60, 255, 160], [80, 200, 255]], { bands: 3 });
  // fjord walls
  const fl = P2(); fl.moveTo(-20, 92); fl.lineTo(-20, 20); fl.quadraticCurveTo(200, 26, 380, 76); fl.lineTo(380, 92); fl.closePath(); fl.moveTo(SW + 20, 92); fl.lineTo(SW + 20, 16); fl.quadraticCurveTo(1150, 30, 960, 76); fl.lineTo(960, 92); fl.closePath(); fillPath(ctx, fl, lin(ctx, 0, 20, 0, 92, [[0, '#2a3446'], [1, '#0c1018']]));
  const snow = P2(); snow.moveTo(-20, 20); snow.quadraticCurveTo(200, 26, 300, 50); snow.lineTo(280, 50); snow.quadraticCurveTo(180, 32, -20, 30); snow.closePath(); fillPath(ctx, snow, rgba([220, 230, 245], 0.7));
  water(ctx, R, 76, 100, [30, 50, 70], { n: 50 }); reflection(ctx, R, 980, 77, 98, [200, 220, 255], 30, 0.3);
  for (const [x, s, f, c] of [[500, 50, false, [180, 40, 40]], [610, 40, false, [240, 230, 200]], [790, 52, true, [30, 60, 140]], [900, 42, true, [180, 40, 40]]]) longship(ctx, x, 90, s, dark, { flip: f, sail: c });
  anchored(ctx, 'L', () => { glow(ctx, 60, 200, 160, [255, 150, 70], 0.3, true); const p = P2(); personPath(p, 90, 340, 230); p.moveTo(76, 120); p.quadraticCurveTo(50, 110, 46, 84); p.lineTo(60, 104); p.closePath(); p.moveTo(104, 120); p.quadraticCurveTo(130, 110, 134, 84); p.lineTo(120, 104); p.closePath(); fillPath(ctx, p, dark); const sh = P2(); sh.ellipse(60, 220, 44, 44, 0, 0, TAU); fillPath(ctx, sh, rgba([180, 40, 40])); circle(ctx, 60, 220, 10, rgba([200, 170, 80])); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 200, 160, [80, 200, 255], 0.25, true); longship(ctx, SW - 60, 330, 160, dark, { flip: true, sail: [240, 230, 200] }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#2a3440'], [1, '#05080a']]));
  finish(ctx, { split: 0.2 });
};

// A winter citadel with hipped towers; troops in the snow.
TEMPLATES.winterCitadel = (ctx, R, o) => {
  const dark = '#0a0a10', brick = o.brick || [150, 50, 40];
  skyPreset(ctx, 'blueHour');
  ground(ctx, ['#dfe6f2', '#6a789c', '#141a2a']);
  stars(ctx, R, 50, [0, 0, SW, 36], { alpha: 0.7 });
  const w = P2(); w.rect(CX - 360, 46, 720, 40); for (let x = CX - 360; x < CX + 360; x += 9) { w.moveTo(x, 46); w.lineTo(x, 40); w.lineTo(x + 2.5, 37); w.lineTo(x + 5, 40); w.lineTo(x + 5, 46); w.closePath(); }
  fillPath(ctx, w, lin(ctx, 0, 37, 0, 86, [[0, rgba(brick)], [1, rgba(shade(brick, -0.5))]]));
  for (const [x, h] of [[CX - 340, 60], [CX - 200, 70], [CX, 96], [CX + 200, 70], [CX + 340, 60]]) onionTowers(ctx, x, 90, h, rgba(shade(brick, -0.1)), { lit: [255, 200, 120] });
  const sn = P2(); sn.rect(CX - 360, 44, 720, 2.4); fillPath(ctx, sn, rgba([240, 244, 250], 0.9));
  horizonHaze(ctx, 86, 8, [255, 255, 255], 0.4);
  const ranks = P2(); for (let x = 120; x < SW - 120; x += between(R, 10, 15)) { if (x > DEALER[0] - 40 && x < DEALER[1] + 40) continue; soldierPath(ranks, x, 95, between(R, 22, 26), { spearSide: 1 }); } fillPath(ctx, ranks, dark);
  for (const [x, f] of [[520, false], [600, false], [770, true], [850, true]]) rimIcon(ctx, 'cavalry', x, 96, 50, dark, [200, 220, 255], { flip: f });
  const snow = []; for (let i = 0; i < 260; i++) snow.push([between(R, 0, SW), between(R, 0, SH), between(R, 0.5, 1.4)]); dots(ctx, snow, rgba([255, 255, 255], 0.7));
  anchored(ctx, 'L', () => { iconAt(ctx, 'pine-tree', 60, 340, 300, '#0a141a'); const c = []; for (let i = 0; i < 50; i++) { const y = between(R, 60, 300), ww = (y - 40) * 0.42; c.push([60 + between(R, -ww, ww), y, between(R, 2, 5)]); } dots(ctx, c, rgba([235, 240, 250], 0.9)); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 70, 200, 180, [255, 190, 110], 0.3, true); iconAt(ctx, 'cannon', SW - 100, 330, 200, dark, { flip: true }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#8a96b8'], [1, '#141a2a']]));
  finish(ctx, { split: 0.25 });
};

// A star fort seen low across its moat, under bombardment (o.night) or at dusk.
TEMPLATES.starFort = (ctx, R, o) => {
  const dark = '#08080c', night = o.night;
  skyPreset(ctx, night ? 'deepNight' : 'dusk');
  ground(ctx, ['#4a6a4a', '#1c2a1c', '#080c08']);
  if (night) stars(ctx, R, 80, [0, 0, SW, 50], { bright: 2 });
  // the bastions: low angled walls with points toward us
  const p = P2(); p.moveTo(-20, 92); for (let x = -20; x < SW + 20; x += 160) { p.lineTo(x + 40, 60); p.lineTo(x + 80, 70); p.lineTo(x + 120, 60); p.lineTo(x + 160, 92); }
  p.lineTo(SW + 20, 100); p.lineTo(-20, 100); p.closePath(); fillPath(ctx, p, lin(ctx, 0, 60, 0, 100, [[0, '#6a8a5a'], [1, '#2a3a26']]));
  rect(ctx, -20, 56, SW + 40, 6, rgba([120, 110, 100]));
  water(ctx, R, 92, 100, [40, 60, 70], { n: 20 });
  // the flag behind the dealer, and the guns
  line(ctx, CX, 54, CX, 0, dark, 2);
  const f = P2(); f.rect(CX, 2, 70, 40); fillPath(ctx, f, rgba(o.flag ? o.flag[0] : [200, 30, 40]));
  if (o.bands) { o.bands.forEach((c, i) => rect(ctx, CX, 2 + i * 40 / o.bands.length, 70, 40 / o.bands.length + 0.4, rgba(c))); }
  else if (o.flag) { if (o.flag[1]) { const st = P2(); for (let k = 1; k < 7; k += 2) st.rect(CX, 2 + k * 40 / 7, 70, 40 / 7); fillPath(ctx, st, rgba(o.flag[1])); } if (o.flag[2]) rect(ctx, CX, 2, 30, 22, rgba(o.flag[2])); }
  for (const x of [420, 530, 840, 950]) { iconAt(ctx, 'cannon', x, 64, 30, dark, { flip: x > CX }); }
  const sold = P2(); for (let x = 140; x < SW - 140; x += 26) { if (Math.abs(x - CX) < 40) continue; soldierPath(sold, x, 58, 20, { spearSide: 1 }); } fillPath(ctx, sold, dark);
  if (night) { for (let i = 0; i < 6; i++) { const x = between(R, 300, 1050), y = between(R, 6, 40); glow(ctx, x, y, 30, [255, 170, 80], 0.5, true); firework(ctx, R, x, y, 14, [255, 200, 120], { rays: 18 }); } additive(ctx, () => { for (let i = 0; i < 5; i++) { const x0 = between(R, 200, 1100), p2 = P2(); p2.moveTo(x0, 60); p2.quadraticCurveTo(x0 + 80, -20, x0 + 160, 20); strokePath(ctx, p2, rgba([255, 120, 60], 0.6), 1.2); } }); }
  else { withBlur(ctx, 6, () => { for (let i = 0; i < 6; i++) oval(ctx, between(R, 380, 1000), 50, 20, 8, rgba([220, 210, 210], 0.4)); }); }
  anchored(ctx, 'L', () => { glow(ctx, 60, 180, 180, [255, 170, 90], 0.3, true); iconAt(ctx, 'cannon', 80, 320, 200, '#08080c'); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 180, 180, [255, 170, 90], 0.3, true); const p2 = P2(); soldierPath(p2, SW - 100, 340, 240, { spearSide: -1 }); fillPath(ctx, p2, '#08080c'); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#2a3a26'], [1, '#080c08']]));
  finish(ctx, { split: 0.3 });
};

// ---------- bars ----------
// A terrace bar over the sea. o.style: 'amalfi' (lemons, tiles) | 'island' (whitewash, blue shutters)
TEMPLATES.terraceBar = (ctx, R, o) => {
  const island = o.style === 'island', dark = '#0c0a0c';
  skyPreset(ctx, o.sky || 'pinkDusk');
  ground(ctx, ['#3a6a8a', '#14304a', '#060e18']);
  sunDisc(ctx, CX + 260, 58, 20, [255, 120, 60], [255, 210, 140], 62);
  water(ctx, R, 62, 100, [40, 90, 130], { n: 50 }); reflection(ctx, R, CX + 260, 63, 92, [255, 200, 130], 50, 0.45);
  if (island) { const v = P2(); let x = -20; while (x < 420) { const w = between(R, 20, 40), h = between(R, 14, 30); v.rect(x, 64 - h, w, h + 10); x += w + 2; } fillPath(ctx, v, rgba([240, 238, 230])); const sh = []; for (let i = 0; i < 30; i++) sh.push([between(R, 0, 410), between(R, 40, 66), 1.4]); dots(ctx, sh, rgba([40, 90, 170])); windmill(ctx, 1080, 64, 50, rgba([240, 236, 226]), 0.4); }
  else { const cl = P2(); cl.moveTo(-20, 70); cl.quadraticCurveTo(200, 10, 420, 66); cl.lineTo(420, 80); cl.lineTo(-20, 80); cl.closePath(); fillPath(ctx, cl, rgba([60, 60, 70])); const hs = []; for (let i = 0; i < 40; i++) hs.push([between(R, 0, 400), between(R, 40, 74), 1.8]); dots(ctx, hs, rgba([255, 214, 160], 0.85)); }
  // pergola, string lights, plants
  const per = P2(); per.rect(-20, 0, SW + 40, 4); for (let x = 30; x < SW; x += 120) { if (Math.abs(x - CX) < 50) continue; per.rect(x - 2.5, 0, 5, 90); } fillPath(ctx, per, rgba(island ? [240, 236, 226] : [90, 60, 40]));
  stringLights(ctx, -20, 6, CX - 40, 6, 12, 12, [255, 200, 120], 1.5); stringLights(ctx, CX + 40, 6, SW + 20, 6, 12, 12, [255, 200, 120], 1.5);
  if (island) { const bg = []; for (let i = 0; i < 160; i++) bg.push([between(R, -20, SW + 20), between(R, 2, 20), between(R, 2, 4)]); dots(ctx, bg, rgba([220, 40, 140], 0.85)); }
  else { canopy(ctx, R, 140, 16, 220, 26, [70, 110, 50], [30, 50, 26]); canopy(ctx, R, 1200, 16, 220, 26, [70, 110, 50], [30, 50, 26]); const lm = []; for (let i = 0; i < 40; i++) lm.push([between(R, 40, 1300), between(R, 8, 26), 2.4]); dots(ctx, lm.filter(([x]) => x < 250 || x > 1090), rgba([250, 220, 60])); }
  // balustrade with drinks
  const bal = P2(); bal.rect(-20, 78, SW + 40, 4); for (let x = -20; x < SW + 20; x += 10) { bal.moveTo(x + 2, 82); bal.quadraticCurveTo(x - 1, 87, x + 2, 92); bal.lineTo(x + 6, 92); bal.quadraticCurveTo(x + 9, 87, x + 6, 82); bal.closePath(); } fillPath(ctx, bal, rgba(island ? [240, 238, 230] : [230, 220, 200]));
  for (const x of [460, 500, 560, 780, 830, 900]) { const g = P2(); g.moveTo(x - 5, 66); g.lineTo(x + 5, 66); g.lineTo(x, 74); g.closePath(); g.rect(x - 0.5, 74, 1, 4); fillPath(ctx, g, rgba(island ? [80, 160, 220] : [255, 140, 40], 0.85)); }
  anchored(ctx, 'L', () => { if (island) { const d = P2(); d.rect(0, 40, 100, 300); fillPath(ctx, d, rgba([240, 238, 230])); const sh = P2(); sh.rect(20, 80, 60, 120); fillPath(ctx, sh, rgba([40, 90, 170])); } else { iconAt(ctx, 'palm-tree', 60, 340, 260, dark); } });
  anchored(ctx, 'R', () => { glow(ctx, SW - 80, 200, 160, [255, 190, 110], 0.3, true); const pot = P2(); pot.moveTo(SW - 140, 340); pot.lineTo(SW - 60, 340); pot.lineTo(SW - 70, 400); pot.lineTo(SW - 130, 400); pot.closePath(); fillPath(ctx, pot, rgba([190, 100, 60])); canopy(ctx, R, SW - 100, 280, 140, 120, [70, 110, 50], [30, 50, 26]); if (!island) { const l = []; for (let i = 0; i < 18; i++) l.push([SW - 100 + between(R, -60, 60), 280 + between(R, -50, 50), 5]); dots(ctx, l, rgba([250, 220, 60])); } });
  tiles(ctx, F - 10, island ? [230, 230, 225] : [210, 120, 60], island ? [60, 110, 180] : [240, 220, 160], 26);
  finish(ctx, { split: 0.3, vignette: 0.42 });
};

// Vaulted cellar bar. o.style: 'cellar' (candles, barrels) | 'vodka' (frost, crystal) | 'bodega' (barrels, hams)
TEMPLATES.cellarBar = (ctx, R, o) => {
  const style = o.style || 'cellar', vodka = style === 'vodka', wall = vodka ? [70, 80, 100] : [110, 80, 60];
  rect(ctx, 0, 0, SW, SH, rgba(shade(wall, -0.7)));
  // brick vaults
  const vb = P2(); for (let x = -40; x < SW + 40; x += 180) { vb.moveTo(x, 100); vb.lineTo(x, 50); vb.quadraticCurveTo(x + 90, -20, x + 180, 50); vb.lineTo(x + 180, 100); vb.lineTo(x + 170, 100); vb.lineTo(x + 170, 52); vb.quadraticCurveTo(x + 90, -6, x + 10, 52); vb.lineTo(x + 10, 100); vb.closePath(); }
  fillPath(ctx, vb, lin(ctx, 0, 0, 0, 100, [[0, rgba(shade(wall, -0.2))], [1, rgba(shade(wall, -0.55))]]));
  const br = P2(); for (let y = 4; y < 100; y += 6) for (let x = (y % 12 ? 0 : 7) - 20; x < SW + 20; x += 14) br.rect(x, y, 13, 5); ctx.save(); ctx.globalAlpha = 0.12; fillPath(ctx, br, rgba(shade(wall, 0.2))); ctx.restore();
  glow(ctx, CX, 50, 520, vodka ? [180, 210, 255] : [255, 170, 80], 0.3, true);
  if (vodka) { for (const x of [CX - 300, CX + 300]) { glow(ctx, x, 18, 60, [220, 235, 255], 0.5, true); const ch = P2(); for (let k = 0; k < 14; k++) { const a = k / 14 * TAU; ch.moveTo(x + Math.cos(a) * 22, 18 + Math.sin(a) * 5); ch.lineTo(x + Math.cos(a) * 22, 30 + (k % 3) * 4); } strokePath(ctx, ch, rgba([230, 240, 255], 0.8), 0.8); } }
  else { for (const x of [CX - 300, CX - 120, CX + 120, CX + 300]) { glow(ctx, x, 60, 40, [255, 170, 70], 0.55, true); rect(ctx, x - 2, 58, 4, 12, rgba([240, 230, 210])); oval(ctx, x, 55, 1.6, 3, rgba([255, 220, 140])); } }
  if (style === 'bodega') { const ham = P2(); for (let x = 120; x < SW - 100; x += 60) { if (Math.abs(x - CX) < 80) continue; ham.moveTo(x, 0); ham.lineTo(x, 12); ham.moveTo(x - 6, 12); ham.quadraticCurveTo(x - 10, 32, x, 40); ham.quadraticCurveTo(x + 10, 32, x + 6, 12); ham.closePath(); } fillPath(ctx, ham, rgba([120, 50, 30])); }
  // barrels and bottles
  for (const [x, y, r] of [[160, 74, 18], [200, 74, 18], [180, 46, 18], [1150, 74, 18], [1190, 74, 18], [1170, 46, 18]]) { const k = P2(); k.ellipse(x, y, r, r, 0, 0, TAU); fillPath(ctx, k, lin(ctx, x - r, 0, x + r, 0, [[0, '#3a2210'], [0.5, '#8a5a2a'], [1, '#2a180a']])); const hp = P2(); hp.ellipse(x, y, r, r, 0, 0, TAU); strokePath(ctx, hp, rgba([30, 30, 30]), 1.6); }
  const pal = vodka ? { glass: [[230, 240, 250], [200, 220, 240]], liquid: [[240, 245, 255], [220, 235, 250]], label: [[200, 40, 40], [250, 250, 250], [20, 40, 90]], cap: [[200, 200, 210], [200, 40, 40]] } : { glass: [[40, 70, 40], [90, 40, 40], [130, 80, 30]], liquid: [[120, 20, 30], [190, 110, 30]], label: [[240, 230, 200], [20, 20, 20]], cap: [[30, 20, 15], [160, 30, 40]] };
  bottleRow(ctx, R, 440, 620, 84, 28, pal, { kinds: vodka ? ['tall', 'tall', 'gin'] : ['wine', 'wine', 'round'] });
  bottleRow(ctx, R, 730, 940, 84, 28, pal, { kinds: vodka ? ['tall', 'tall', 'gin'] : ['wine', 'wine', 'round'] });
  rect(ctx, -20, 84, SW + 40, 10, lin(ctx, 0, 84, 0, 94, [[0, vodka ? '#c8d0dc' : '#6a4a2a'], [1, vodka ? '#5a6474' : '#2a1a0c']]));
  if (vodka) { const fr = []; for (let i = 0; i < 200; i++) fr.push([between(R, 0, SW), between(R, 0, 100), between(R, 0.4, 1)]); dots(ctx, fr, rgba([230, 240, 255], 0.35)); }
  anchored(ctx, 'L', () => { glow(ctx, 80, 200, 200, vodka ? [180, 210, 255] : [255, 170, 80], 0.3, true); for (const [x, y] of [[60, 300], [150, 300], [105, 222]]) { const k = P2(); k.ellipse(x, y, 44, 40, 0, 0, TAU); fillPath(ctx, k, lin(ctx, x - 44, 0, x + 44, 0, [[0, '#3a2210'], [0.5, '#8a5a2a'], [1, '#2a180a']])); const h = P2(); h.ellipse(x, y, 44, 40, 0, 0, TAU); strokePath(ctx, h, rgba([40, 40, 40]), 3); } });
  anchored(ctx, 'R', () => { glow(ctx, SW - 90, 180, 160, vodka ? [180, 210, 255] : [255, 170, 80], 0.35, true); rect(ctx, SW - 100, 140, 6, 40, rgba([240, 230, 210])); oval(ctx, SW - 97, 134, 3, 6, rgba([255, 220, 140])); glow(ctx, SW - 97, 134, 40, [255, 170, 70], 0.6, true); });
  tiles(ctx, F - 10, shade(wall, -0.3), shade(wall, -0.5), 24);
  finish(ctx, { split: 0.2, vignette: 0.5 });
};

// An ice bar: walls and counter of glowing blue ice.
TEMPLATES.iceBar = (ctx, R, o) => {
  rect(ctx, 0, 0, SW, SH, '#04101c');
  const blocks = (y0, y1, h) => { for (let y = y0, r = 0; y < y1; y += h, r++) for (let x = (r % 2) * -30 - 20; x < SW + 20; x += 60) { rect(ctx, x + 1, y + 1, 58, h - 2, lin(ctx, x, y, x + 60, y + h, [[0, '#9ad8f0'], [0.5, '#4aa8d8'], [1, '#1a5a8a']])); } };
  blocks(0, 96, 24);
  glow(ctx, CX, 50, 600, [120, 220, 255], 0.35, true);
  const eng = P2(); for (const [x, y] of [[CX - 260, 40], [CX + 260, 40]]) { eng.moveTo(x - 20, y + 20); eng.lineTo(x, y - 20); eng.lineTo(x + 20, y + 20); eng.closePath(); } fillPath(ctx, eng, rgba([200, 240, 255], 0.5));
  const pal = { glass: [[200, 230, 250], [160, 210, 240]], liquid: [[230, 250, 255], [150, 220, 255]], label: [[255, 255, 255], [40, 120, 200]], cap: [[200, 230, 250]] };
  bottleRow(ctx, R, 440, 620, 82, 28, pal, { kinds: ['tall', 'gin', 'round'] }); bottleRow(ctx, R, 730, 940, 82, 28, pal, { kinds: ['tall', 'gin', 'round'] });
  rect(ctx, -20, 82, SW + 40, 12, lin(ctx, 0, 82, 0, 94, [[0, '#d8f2ff'], [1, '#5aa8d8']]));
  for (const x of [380, 960, 1040]) { const g = P2(); g.rect(x - 5, 70, 10, 12); fillPath(ctx, g, rgba([220, 245, 255], 0.75)); }
  anchored(ctx, 'L', () => { const s = P2(); s.moveTo(40, 340); s.quadraticCurveTo(20, 200, 90, 140); s.quadraticCurveTo(150, 200, 140, 340); s.closePath(); fillPath(ctx, s, lin(ctx, 20, 140, 150, 340, [[0, '#e0f6ff'], [1, '#3a8ac0']])); glow(ctx, 90, 220, 120, [150, 230, 255], 0.4, true); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 80, 160, 140, [150, 230, 255], 0.4, true); for (const [x, y] of [[SW - 100, 120], [SW - 60, 200]]) { const c = P2(); c.moveTo(x - 20, y + 30); c.lineTo(x, y - 30); c.lineTo(x + 20, y + 30); c.closePath(); fillPath(ctx, c, rgba([210, 245, 255], 0.7)); } });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#4a8ab8'], [1, '#04101c']]));
  finish(ctx, { split: 0.1, vignette: 0.45 });
};

// ---------- sport ----------
// Road race: cyclists in a bunch, crowds, mountain or boulevard. o.road: 'alps' | 'boulevard'
TEMPLATES.cyclingRoad = (ctx, R, o) => {
  const dark = '#0c0a0c', alps = o.road !== 'boulevard';
  skyPreset(ctx, alps ? 'golden' : 'dusk');
  ground(ctx, alps ? ['#6a8a4a', '#24341a', '#080c06'] : ['#7a6a5a', '#2a221c', '#0a0806']);
  if (alps) mountains(ctx, R, 70, 50, [140, 140, 170], { snow: [250, 250, 255], bottom: 90 });
  else { skyline(ctx, R, 80, rgba([40, 36, 50]), { h: 30, lit: 0.3 }); const arc = P2(); arc.rect(CX + 240, 26, 70, 54); fillPath(ctx, arc, rgba([60, 54, 66])); rect(ctx, CX + 260, 46, 30, 34, rgba([20, 18, 26])); }
  const road = P2(); road.moveTo(-20, 92); road.quadraticCurveTo(CX, 70, SW + 20, 90); road.lineTo(SW + 20, 100); road.lineTo(-20, 100); road.closePath(); fillPath(ctx, road, rgba([50, 50, 56]));
  crowd(ctx, R, -10, SW + 10, 80, 12, dark, { hands: 0.45 });
  const fl = [[240, 30, 40], [255, 255, 255], [30, 80, 200], [255, 220, 40]];
  for (let x = 40; x < SW; x += 70) { const c = pick(R, fl), f = P2(); f.rect(x, 60, 14, 9); fillPath(ctx, f, rgba(c)); line(ctx, x, 60, x - 2, 76, dark, 1); }
  for (let k = 0; k < 9; k++) { const x = 440 + k * 30 + (k > 3 ? 120 : 0), y = 94 - Math.sin(k) * 2; iconAt(ctx, 'cycling', x, y, 34, dark, { flip: false }); }
  anchored(ctx, 'L', () => { glow(ctx, 60, 200, 180, [255, 200, 120], 0.3, true); crowd(ctx, R, -10, 220, 320, 46, '#0c0a0c', { hands: 0.6 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 200, 180, [255, 200, 120], 0.3, true); crowd(ctx, R, SW - 220, SW + 10, 320, 46, '#0c0a0c', { hands: 0.6 }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#3a3a40'], [1, '#08080a']]));
  const lines = P2(); for (let x = 0; x < SW; x += 60) lines.rect(x, F + 40, 30, 3); fillPath(ctx, lines, rgba([255, 255, 255], 0.5));
  finish(ctx, { split: 0.3 });
};

// Motor racing. o.track: 'monza' (dusk, grandstands, red) | 'street' (night, skyline, wheel) | 'oval' (banking, packs)
TEMPLATES.racetrack = (ctx, R, o) => {
  const track = o.track || 'street', night = track !== 'monza', dark = '#08080c', red = [220, 20, 20];
  skyPreset(ctx, night ? 'night' : 'golden');
  ground(ctx, ['#5a5a60', '#1e1e24', '#08080a']);
  if (track === 'street') { skyline(ctx, R, 70, rgba([20, 24, 40]), { h: 50, lit: 0.45 }); const wx = 1080, wy = 30, wr = 30; const wp = P2(); wp.ellipse(wx, wy, wr, wr, 0, 0, TAU); for (let k = 0; k < 16; k++) { const a = k * TAU / 16; wp.moveTo(wx, wy); wp.lineTo(wx + Math.cos(a) * wr, wy + Math.sin(a) * wr); } strokePath(ctx, wp, rgba([200, 220, 255], 0.6), 0.8); for (const x of [200, 420, 920, 1180]) floodTower(ctx, x, 70, 20, '#16161e'); }
  if (track === 'monza') { stands(ctx, R, 40, 76, [[220, 20, 20], [250, 220, 40], [255, 255, 255]]); rect(ctx, -20, 34, SW + 40, 6, '#3a3a40'); canopy(ctx, R, CX, 30, SW, 14, [60, 90, 50], [26, 40, 20], { n: 80 }); }
  if (track === 'oval') { const bank = P2(); bank.moveTo(-20, 80); bank.quadraticCurveTo(CX, 30, SW + 20, 80); bank.lineTo(SW + 20, 90); bank.lineTo(-20, 90); bank.closePath(); fillPath(ctx, bank, rgba([60, 60, 66])); stands(ctx, R, 10, 46, [[255, 255, 255], [240, 200, 40], [40, 80, 200]]); for (const x of [300, 1040]) floodTower(ctx, x, 40, 20, '#16161e'); }
  // the track and the cars
  rect(ctx, -20, 82, SW + 40, 14, rgba([44, 44, 50]));
  for (let x = -20, k = 0; x < SW + 20; x += 24, k++) rect(ctx, x, 80, 24, 3, rgba(k % 2 ? [250, 250, 250] : red));
  const cars = track === 'oval' ? [[470, 40], [520, 40], [570, 40], [770, 40], [820, 40], [870, 40]] : [[500, 56], [600, 50], [800, 54], [900, 48]];
  for (const [x, s] of cars) { iconAt(ctx, 'race-car', x, 98, s, dark, { flip: x > CX }); if (night) { glow(ctx, x + (x > CX ? -s * 0.45 : s * 0.45), 92, 12, [255, 60, 40], 0.6, true); } }
  additive(ctx, () => { const st = P2(); for (let i = 0; i < 30; i++) { const y = between(R, 84, 96), x = between(R, 200, 1100); st.moveTo(x, y); st.lineTo(x + between(R, 30, 80), y); } strokePath(ctx, st, rgba(night ? [200, 220, 255] : [255, 230, 200], 0.25), 1); });
  anchored(ctx, 'L', () => { glow(ctx, 60, 160, 200, red, 0.3, true); const f = P2(); for (let r = 0; r < 6; r++) for (let k = 0; k < 4; k++) if ((r + k) % 2) f.rect(40 + k * 22, 60 + r * 22, 22, 22); f.rect(20, 50, 6, 300); fillPath(ctx, f, rgba([240, 240, 240])); const fb = P2(); for (let r = 0; r < 6; r++) for (let k = 0; k < 4; k++) if ((r + k) % 2 === 0) fb.rect(40 + k * 22, 60 + r * 22, 22, 22); fillPath(ctx, fb, rgba([20, 20, 20])); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 160, 200, [0, 181, 200], 0.25, true); iconAt(ctx, 'race-car', SW - 120, 340, 240, dark, { flip: true }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#3a3a40'], [1, '#08080a']]));
  for (let x = -20, k = 0; x < SW + 20; x += 40, k++) rect(ctx, x, F - 10, 40, 8, rgba(k % 2 ? [250, 250, 250] : red));
  finish(ctx, { split: 0.35 });
};

// Winter sport. o.kind: 'skiJump' | 'slalom' | 'canalSkate' | 'dogSled' | 'pondHockey'
TEMPLATES.winterSport = (ctx, R, o) => {
  const kind = o.kind || 'skiJump', dark = '#0a0c14', night = kind === 'slalom' || kind === 'pondHockey';
  skyPreset(ctx, night ? 'night' : kind === 'canalSkate' ? 'dawn' : 'blueHour');
  ground(ctx, ['#e6ecf6', '#7a88aa', '#1a2036']);
  if (night) stars(ctx, R, 100, [0, 0, SW, 50], { bright: 3 });
  if (kind !== 'canalSkate') mountains(ctx, R, 78, 44, [170, 180, 210], { snow: [250, 250, 255], bottom: 96 });
  if (kind === 'skiJump') { const j = P2(); j.moveTo(CX + 120, 4); j.lineTo(CX + 132, 4); j.quadraticCurveTo(CX + 150, 60, CX + 260, 74); j.lineTo(CX + 260, 80); j.quadraticCurveTo(CX + 140, 66, CX + 120, 8); j.closePath(); fillPath(ctx, j, rgba([60, 64, 80])); const sk = P2(); personPath(sk, CX - 160, 40, 26); fillPath(ctx, sk, dark); line(ctx, CX - 190, 34, CX - 140, 48, dark, 1.6); line(ctx, CX - 188, 38, CX - 136, 52, dark, 1.6); crowd(ctx, R, -10, SW + 10, 92, 12, dark, { hands: 0.4 }); }
  if (kind === 'slalom') { for (const x of [120, 420, 920, 1220]) floodTower(ctx, x, 60, 24, '#16161e'); const g = []; for (let k = 0; k < 10; k++) { const x = 300 + k * 80, y = 30 + k * 6; g.push([x, y]); } for (const [x, y] of g) { const f = P2(); f.rect(x, y, 6, 10); fillPath(ctx, f, rgba(g.indexOf([x, y]) % 2 ? [40, 80, 220] : [220, 40, 40])); } iconAt(ctx, 'skier', 560, 60, 40, dark); crowd(ctx, R, -10, SW + 10, 92, 12, dark, { hands: 0.4, lights: [] }); }
  if (kind === 'canalSkate') { for (const [x, h] of [[200, 40], [320, 30], [1000, 44], [1160, 34]]) windmill(ctx, x, 82, h * 1.4, rgba([30, 30, 40]), x * 0.01); const h = P2(); let x = 380; while (x < 960) { const w = between(R, 16, 26), hh = between(R, 20, 34); h.rect(x, 82 - hh, w, hh); h.moveTo(x, 82 - hh); h.lineTo(x + w / 2, 82 - hh - 10); h.lineTo(x + w, 82 - hh); h.closePath(); x += w + 1; } fillPath(ctx, h, rgba([60, 40, 40])); rect(ctx, -20, 82, SW + 40, 16, lin(ctx, 0, 82, 0, 98, [[0, '#d8e8f2'], [1, '#8aa8c0']])); for (const [x2, f] of [[460, false], [540, false], [600, true], [780, false], [850, true], [920, false]]) { const p = P2(); personPath(p, x2, 96, 30, { armUp: 0 }); fillPath(ctx, p, dark); } }
  if (kind === 'dogSled') { for (let k = 0; k < 2; k++) { const x0 = 460 + k * 330; for (let d = 0; d < 6; d++) { const dx = x0 + d * 22, p = P2(); p.ellipse(dx, 88, 8, 3.4, 0, 0, TAU); p.ellipse(dx + 8, 85, 3, 2.6, 0, 0, TAU); p.rect(dx - 6, 88, 1.6, 7); p.rect(dx + 4, 88, 1.6, 7); fillPath(ctx, p, dark); } const s = P2(); s.rect(x0 - 40, 86, 24, 6); s.rect(x0 - 42, 93, 30, 1.6); fillPath(ctx, s, dark); const m = P2(); personPath(m, x0 - 34, 86, 26); fillPath(ctx, m, dark); } }
  if (kind === 'pondHockey') { rect(ctx, -20, 82, SW + 40, 16, lin(ctx, 0, 82, 0, 98, [[0, '#c8d8e8'], [1, '#7a98b8']])); forestLine(ctx, R, 82, 18, rgba([14, 20, 26]), { pines: true }); for (const [x, f] of [[480, false], [560, false], [780, true], [870, true]]) player(ctx, 'iceHockey', x, 96, 44, dark, { flip: f }); const fire = 1040; glow(ctx, fire, 86, 60, [255, 150, 60], 0.6, true); }
  const snow = []; for (let i = 0; i < 200; i++) snow.push([between(R, 0, SW), between(R, 0, SH), between(R, 0.5, 1.3)]); dots(ctx, snow, rgba([255, 255, 255], 0.6));
  anchored(ctx, 'L', () => { iconAt(ctx, 'pine-tree', 60, 340, 300, '#0a141a'); const c = []; for (let i = 0; i < 50; i++) { const y = between(R, 60, 300), ww = (y - 40) * 0.42; c.push([60 + between(R, -ww, ww), y, between(R, 2, 5)]); } dots(ctx, c, rgba([235, 240, 250], 0.9)); });
  anchored(ctx, 'R', () => { iconAt(ctx, 'pine-tree', SW - 60, 340, 280, '#0a141a'); glow(ctx, SW - 120, 230, 100, [255, 170, 90], 0.25, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#a8b8d0'], [1, '#141a2a']]));
  finish(ctx, { split: 0.2 });
};

// ---------- wild ----------
// Fields in rows to the horizon. o.crop: 'lavender' | 'tulips' | 'sunflowers' | 'rice' | 'mustard'
TEMPLATES.fields = (ctx, R, o) => {
  const crop = o.crop || 'lavender', dark = '#140c14';
  const cols = { lavender: [[150, 100, 200], [110, 70, 170]], tulips: [[230, 40, 60], [250, 200, 40], [240, 120, 180], [250, 250, 240]], sunflowers: [[250, 200, 40], [220, 150, 20]], rice: [[120, 180, 70], [80, 140, 50]] }[crop] || [[250, 210, 50]];
  skyPreset(ctx, o.sky || 'golden');
  ground(ctx, [cols[0], shade(cols[0], -0.5), shade(cols[0], -0.8)]);
  sunDisc(ctx, CX - 280, 66, 20, [255, 120, 50], [255, 220, 140], 74);
  if (o.hills) ridge(ctx, R, 74, 16, rgba([110, 90, 120]), { bottom: 80 });
  // rows converging toward the horizon
  for (let k = -24; k <= 24; k++) { const c = cols[(k + 24) % cols.length], p = P2(), x0 = CX + k * 18, x1 = CX + k * 160; p.moveTo(x0 - 6, 74); p.lineTo(x0 + 6, 74); p.lineTo(x1 + 50, 110); p.lineTo(x1 - 50, 110); p.closePath(); fillPath(ctx, p, lin(ctx, 0, 74, 0, 100, [[0, rgba(shade(c, -0.1))], [1, rgba(c)]])); }
  const gaps = P2(); for (let k = -24; k <= 24; k++) { gaps.moveTo(CX + k * 18 + 9, 74); gaps.lineTo(CX + k * 160 + 80, 110); } strokePath(ctx, gaps, rgba([40, 30, 20], 0.5), 1.2);
  horizonHaze(ctx, 74, 6, [255, 220, 170], 0.5);
  if (o.landmark) o.landmark(ctx, R);
  if (o.windmills) for (const [x, h] of [[440, 60], [880, 54], [1000, 40]]) windmill(ctx, x, 76, h, rgba([40, 30, 36]), x * 0.02);
  if (o.farmhouse) { const h = P2(); h.rect(880, 56, 40, 20); h.moveTo(876, 56); h.lineTo(900, 42); h.lineTo(924, 56); h.closePath(); fillPath(ctx, h, rgba([90, 60, 50])); for (const x of [850, 940]) { const c = P2(); c.ellipse(x, 52, 4, 20, 0, 0, TAU); fillPath(ctx, c, rgba([30, 50, 30])); } }
  anchored(ctx, 'L', () => { const st = []; for (let i = 0; i < 120; i++) st.push([between(R, -10, 180), between(R, 100, 340), between(R, 2, 5)]); dots(ctx, st, rgba(cols[0])); });
  anchored(ctx, 'R', () => { const st = []; for (let i = 0; i < 120; i++) st.push([SW - between(R, -10, 180), between(R, 100, 340), between(R, 2, 5)]); dots(ctx, st, rgba(cols[cols.length > 1 ? 1 : 0])); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, rgba(shade(cols[0], -0.3))], [1, rgba(shade(cols[0], -0.85))]]));
  const fl = []; for (let i = 0; i < 300; i++) fl.push([between(R, 0, SW), between(R, F, SH), between(R, 1, 2.6)]); dots(ctx, fl, rgba(cols[0], 0.6));
  finish(ctx, { split: 0.3 });
};

// A canal city at night: gondolas or bikes, bridges, lit windows. o.style: 'venice' | 'amsterdam' | 'harbour'
TEMPLATES.canalCity = (ctx, R, o) => {
  const style = o.style || 'venice', dark = '#06070c';
  skyPreset(ctx, o.sky || 'blueHour');
  ground(ctx, ['#1a2238', '#0a0c18', '#04050a']);
  moon(ctx, 1000, 20, 8, { halo: 6 });
  // facades along both banks
  const fac = P2(), wins = []; let x = -20;
  const palette = style === 'harbour' ? [[230, 120, 90], [250, 200, 80], [90, 170, 200], [240, 140, 170], [130, 200, 140]] : style === 'amsterdam' ? [[70, 50, 46], [90, 60, 50], [60, 56, 60]] : [[200, 140, 110], [220, 170, 120], [180, 110, 100]];
  while (x < SW + 20) {
    const w = between(R, 26, 46), h = between(R, 34, 60), c = pick(R, palette), p = P2();
    if (style === 'amsterdam') { p.moveTo(x, 80); p.lineTo(x, 80 - h); p.lineTo(x + w * 0.25, 80 - h); p.lineTo(x + w * 0.25, 80 - h - 8); p.lineTo(x + w * 0.5, 80 - h - 14); p.lineTo(x + w * 0.75, 80 - h - 8); p.lineTo(x + w * 0.75, 80 - h); p.lineTo(x + w, 80 - h); p.lineTo(x + w, 80); p.closePath(); }
    else p.rect(x, 80 - h, w, h);
    fillPath(ctx, p, rgba(shade(c, -0.45)));
    for (let wy = 80 - h + 6; wy < 76; wy += 9) for (let wx = x + 4; wx < x + w - 6; wx += 9) if (R() < 0.5) wins.push([wx, wy]);
    x += w;
  }
  for (const [wx, wy] of wins) rect(ctx, wx, wy, 4, 5, rgba([255, 200, 120], 0.85));
  if (o.landmark) o.landmark(ctx, R);
  water(ctx, R, 80, 100, [20, 34, 60], { n: 30 });
  const refl = P2(); for (const [wx, wy] of wins) { refl.moveTo(wx, 160 - wy); refl.lineTo(wx + 4, 160 - wy); } additive(ctx, () => strokePath(ctx, refl, rgba([255, 200, 120], 0.3), 1.2));
  if (style === 'venice') { gondola(ctx, 520, 90, 30, dark); gondola(ctx, 860, 92, 26, dark); stoneArches(ctx, 600, 760, 74, 1, rgba([200, 190, 180]), { rise: 10 }); }
  else if (style === 'amsterdam') { stoneArches(ctx, 560, 780, 76, 3, rgba([60, 50, 50])); for (const bx of [420, 470, 820, 870]) { const b = P2(); b.ellipse(bx - 6, 74, 5, 5, 0, 0, TAU); b.ellipse(bx + 6, 74, 5, 5, 0, 0, TAU); strokePath(ctx, b, dark, 1.2); line(ctx, bx - 6, 74, bx + 6, 74, dark, 1); } }
  else { const br = P2(); br.rect(560, 70, 240, 4); for (let k = 0; k < 12; k++) br.rect(560 + k * 20, 74, 2, 8); fillPath(ctx, br, rgba([60, 60, 70])); for (let k = 0; k < 12; k++) glow(ctx, 560 + k * 20, 70, 6, [255, 220, 140], 0.6, true); }
  anchored(ctx, 'L', () => { line(ctx, 70, 80, 70, 340, '#0a0a10', 4); glow(ctx, 70, 76, 34, [255, 210, 140], 0.6, true); circle(ctx, 70, 76, 6, rgba([255, 240, 200])); });
  anchored(ctx, 'R', () => { if (style === 'venice') { const p = P2(); for (let k = 0; k < 3; k++) p.rect(SW - 160 + k * 50, 80, 10, 260); fillPath(ctx, p, rgba([40, 30, 40])); const st = P2(); for (let k = 0; k < 3; k++) for (let y = 90; y < 340; y += 30) st.rect(SW - 160 + k * 50, y, 10, 12); fillPath(ctx, st, rgba([220, 210, 230])); } else glow(ctx, SW - 80, 200, 140, [255, 210, 140], 0.25, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#121a30'], [1, '#03040a']]));
  const rf = P2(); for (let i = 0; i < 60; i++) { const xx = between(R, 0, SW), y = between(R, F, SH); rf.moveTo(xx, y); rf.lineTo(xx + between(R, 10, 40), y); } additive(ctx, () => strokePath(ctx, rf, rgba([255, 200, 120], 0.15), 1));
  finish(ctx, { split: 0.2 });
};

// A volcano erupting at night. o.shape: 'cone' | 'wide'; o.sea
TEMPLATES.volcano = (ctx, R, o) => {
  const dark = '#06060a';
  skyPreset(ctx, o.sky || 'deepNight');
  ground(ctx, ['#2a1a1a', '#100808', '#040202']);
  stars(ctx, R, 80, [0, 0, SW, 40], { bright: 2 });
  const cx = CX + (o.offset || 0), v = P2();
  if (o.shape === 'wide') { v.moveTo(cx - 520, 92); v.quadraticCurveTo(cx - 200, 40, cx - 60, 26); v.lineTo(cx + 60, 26); v.quadraticCurveTo(cx + 200, 40, cx + 520, 92); }
  else { v.moveTo(cx - 400, 92); v.quadraticCurveTo(cx - 120, 60, cx - 30, 14); v.lineTo(cx + 30, 14); v.quadraticCurveTo(cx + 120, 60, cx + 400, 92); }
  v.closePath(); fillPath(ctx, v, lin(ctx, 0, 14, 0, 92, [[0, '#2a1a1e'], [1, '#0c0608']]));
  const top = o.shape === 'wide' ? 26 : 14;
  glow(ctx, cx, top, 120, [255, 90, 30], 0.7, true);
  withBlur(ctx, 10, () => { for (let i = 0; i < 9; i++) oval(ctx, cx + between(R, -80, 120), top - 14 - i * 6, 40 + i * 8, 10 + i, rgba([120, 80, 80], 0.35)); });
  additive(ctx, () => { const ls = P2(); for (let i = 0; i < 26; i++) { const a = between(R, -2.6, -0.5), l = between(R, 20, 70); ls.moveTo(cx, top); ls.quadraticCurveTo(cx + Math.cos(a) * l, top + Math.sin(a) * l, cx + Math.cos(a) * l * 1.4, top + Math.sin(a) * l * 0.6 + 20); } strokePath(ctx, ls, rgba([255, 160, 60], 0.7), 1.2); });
  const lava = P2(); for (const dx of [-20, 10, 26]) { lava.moveTo(cx + dx, top); lava.quadraticCurveTo(cx + dx * 4, 50, cx + dx * 9, 90); } additive(ctx, () => strokePath(ctx, lava, rgba([255, 120, 30], 0.85), 2.4));
  if (o.sea) { water(ctx, R, 88, 100, [30, 20, 30], { n: 30 }); reflection(ctx, R, cx, 89, 99, [255, 120, 50], 60, 0.45); }
  else forestLine(ctx, R, 94, 12, rgba([10, 8, 10]));
  if (o.watchers) { const p = P2(); for (const x of [440, 480, 880, 920]) personPath(p, x, 96, 24); fillPath(ctx, p, dark); }
  anchored(ctx, 'L', () => { if (o.palms) palm(ctx, R, 40, 340, 280, dark, { lean: 0.3 }); else canopy(ctx, R, 30, 140, 200, 200, [14, 12, 14], [4, 4, 6]); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 70, 200, 180, [255, 110, 40], 0.3, true); if (o.palms) palm(ctx, R, SW - 50, 340, 260, dark, { lean: -0.3 }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#2a1410'], [1, '#040202']]));
  glow(ctx, CX, F, 400, [255, 100, 40], 0.15, true);
  finish(ctx, { split: 0.2 });
};

// Aurora over water and mountains. o.fore: 'fjord' | 'tundra' | 'lake'
TEMPLATES.auroraScene = (ctx, R, o) => {
  const dark = '#04060a';
  skyPreset(ctx, 'arctic');
  ground(ctx, ['#14283a', '#081420', '#02060a']);
  stars(ctx, R, 200, [0, 0, SW, 70], { bright: 6 });
  aurora(ctx, R, 18, o.cols || [[60, 255, 150], [80, 200, 255], [200, 80, 255]], { bands: 5 });
  mountains(ctx, R, 78, 40, [16, 24, 34], { snow: [150, 180, 200], bottom: 90 });
  if (o.fore === 'ice') { const ic = P2(); ic.moveTo(-20, 100); ic.lineTo(-20, 80); for (let x = -20; x <= SW + 20; x += 16) ic.lineTo(x, 80 - between(R, 0, 4)); ic.lineTo(SW + 20, 100); ic.closePath(); fillPath(ctx, ic, lin(ctx, 0, 76, 0, 100, [[0, '#9ab8d8'], [1, '#2a3a5a']])); const pr = P2(); for (let x = 0; x < SW; x += between(R, 40, 90)) { pr.moveTo(x, 90); pr.lineTo(x + 10, 84); pr.lineTo(x + 20, 90); } strokePath(ctx, pr, rgba([200, 220, 245], 0.5), 1); const ig = P2(); ig.arc(880, 84, 16, Math.PI, 0); ig.closePath(); fillPath(ctx, ig, rgba([180, 200, 225])); rect(ctx, 874, 78, 12, 6, rgba([255, 190, 110])); glow(ctx, 880, 82, 24, [255, 170, 90], 0.5, true); for (const [x, f] of [[500, false], [530, false], [560, false]]) iconAt(ctx, 'wolf-howl', x, 92, 18, dark, { flip: f }); }
  else { water(ctx, R, 78, 100, [10, 30, 40], { n: 40 }); additive(ctx, () => { const rf = P2(); for (let i = 0; i < 60; i++) { const x = between(R, 0, SW), y = between(R, 80, 98); rf.moveTo(x, y); rf.lineTo(x + between(R, 10, 40), y); } strokePath(ctx, rf, rgba([80, 255, 170], 0.25), 1); }); }
  if (o.cabin !== false) { const c = P2(); c.rect(860, 70, 34, 12); c.moveTo(856, 70); c.lineTo(877, 58); c.lineTo(898, 70); c.closePath(); fillPath(ctx, c, rgba([30, 20, 20])); rect(ctx, 866, 74, 6, 5, rgba([255, 200, 120])); glow(ctx, 869, 76, 20, [255, 170, 80], 0.5, true); }
  if (o.reindeer) for (const [x, f] of [[480, false], [540, true], [600, false]]) iconAt(ctx, 'deer', x, 84, 34, dark, { flip: f });
  anchored(ctx, 'L', () => { iconAt(ctx, 'pine-tree', 60, 340, 300, '#04080c'); });
  anchored(ctx, 'R', () => { iconAt(ctx, 'pine-tree', SW - 60, 340, 280, '#04080c'); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#14283a'], [1, '#02060a']]));
  finish(ctx, { split: 0.1 });
};

// A train crossing the taiga at night (or desert). o.land: 'taiga' | 'desert'
TEMPLATES.nightTrain = (ctx, R, o) => {
  const dark = '#06080c', taiga = o.land !== 'desert';
  skyPreset(ctx, taiga ? 'night' : 'warmNight');
  ground(ctx, taiga ? ['#c8d4e6', '#4a5a7a', '#0e1220'] : ['#6a4a3a', '#2a1a14', '#0a0606']);
  stars(ctx, R, 180, [0, 0, SW, 60], { bright: 5 });
  moon(ctx, 260, 24, 10, { halo: 6 });
  if (taiga) forestLine(ctx, R, 74, 26, rgba([10, 16, 22]), { pines: true }); else mesas(ctx, R, 74, rgba([40, 24, 24]));
  // the train on a long bridge/embankment
  rect(ctx, -20, 74, SW + 40, 6, rgba([20, 22, 30]));
  const t = P2(); t.rect(980, 62, 40, 12); t.rect(1010, 54, 10, 8); t.rect(1022, 66, 10, 8);
  for (let k = 0; k < 12; k++) t.rect(940 - k * 46, 63, 44, 11); fillPath(ctx, t, rgba([30, 34, 50]));
  const w = []; for (let k = 0; k < 12; k++) for (let j = 0; j < 5; j++) w.push([944 - k * 46 + j * 8, 67, 1.6]); dots(ctx, w, rgba([255, 214, 140]));
  for (const [x] of w.filter((_, i) => i % 10 === 0)) glow(ctx, x, 67, 20, [255, 190, 110], 0.25, true);
  beam(ctx, 1032, 68, 0.05, 260, 0.2, [255, 240, 200], 0.5);
  withBlur(ctx, 6, () => { for (let k = 0; k < 6; k++) oval(ctx, 1010 - k * 30, 46 - k * 3, 20 + k * 6, 6, rgba([200, 200, 210], 0.35 - k * 0.04)); });
  if (taiga) { const sn = []; for (let i = 0; i < 160; i++) sn.push([between(R, 0, SW), between(R, 0, SH), 0.8]); dots(ctx, sn, rgba([255, 255, 255], 0.5)); }
  anchored(ctx, 'L', () => { iconAt(ctx, 'pine-tree', 60, 340, 300, '#060a0e'); });
  anchored(ctx, 'R', () => { iconAt(ctx, 'pine-tree', SW - 60, 340, 280, '#060a0e'); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, taiga ? '#5a6a8a' : '#3a2a20'], [1, '#04060a']]));
  finish(ctx, { split: 0.2 });
};

// A walled city by the sea at sunset (Dubrovnik, Galle, Old San Juan...).
TEMPLATES.walledCity = (ctx, R, o) => {
  skyPreset(ctx, o.sky || 'pinkDusk');
  ground(ctx, ['#3a6a8a', '#14304a', '#060e18']);
  sunDisc(ctx, CX + 300, 66, 20, [255, 120, 60], [255, 210, 140], 72);
  water(ctx, R, 72, 100, [40, 90, 130], { n: 50 }); reflection(ctx, R, CX + 300, 73, 96, [255, 200, 130], 50, 0.45);
  const roofs = [[210, 90, 60], [190, 80, 50], [230, 110, 70]];
  const city = P2(); city.moveTo(-20, 80); city.lineTo(-20, 50); for (let x = -20; x < 760; x += 14) city.lineTo(x, 46 + Math.sin(x * 0.03) * 6); city.lineTo(760, 80); city.closePath(); fillPath(ctx, city, rgba([200, 180, 150]));
  const rf = P2(); for (let x = -20; x < 760; x += 14) { const y = 46 + Math.sin(x * 0.03) * 6; rf.moveTo(x, y); rf.lineTo(x + 7, y - 7); rf.lineTo(x + 14, y); rf.closePath(); } fillPath(ctx, rf, rgba(roofs[0]));
  const wall = P2(); wall.moveTo(-20, 86); wall.lineTo(-20, 64); for (let x = -20; x < 800; x += 10) { wall.lineTo(x, 64); wall.lineTo(x, 60); wall.lineTo(x + 6, 60); wall.lineTo(x + 6, 64); } wall.lineTo(800, 64); wall.lineTo(820, 86); wall.closePath(); fillPath(ctx, wall, lin(ctx, 0, 60, 0, 86, [[0, '#e0c8a8'], [1, '#8a7058']]));
  for (const [x, h] of [[120, 30], [420, 40], [760, 34]]) { const t = P2(); t.rect(x - 14, 64 - h, 28, h + 22); for (let k = 0; k < 4; k++) t.rect(x - 14 + k * 8, 60 - h, 5, 4); fillPath(ctx, t, rgba([210, 190, 160])); }
  const w = []; for (let i = 0; i < 60; i++) w.push([between(R, 0, 740), between(R, 48, 62), 1]); dots(ctx, w, rgba([255, 210, 140]));
  if (o.boats !== false) { sailboat(ctx, 940, 84, 26, rgba([30, 30, 40])); sailboat(ctx, 1100, 80, 20, rgba([30, 30, 40])); }
  anchored(ctx, 'L', () => { iconAt(ctx, 'palm-tree', 60, 340, 260, '#0c0a0c'); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 70, 200, 180, [255, 180, 110], 0.3, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#1c3a50'], [1, '#04080c']]));
  finish(ctx, { split: 0.3 });
};

// Dunes and pines along a shore at sunset (the Curonian Spit, the Amber Coast).
TEMPLATES.coastDunes = (ctx, R, o) => {
  skyPreset(ctx, o.sky || 'pinkDusk');
  ground(ctx, ['#d8b890', '#6a5040', '#14100c']);
  sunDisc(ctx, CX + 260, 62, 20, [255, 120, 60], [255, 210, 140], 66);
  water(ctx, R, 66, 80, [60, 90, 120], { n: 40 }); reflection(ctx, R, CX + 260, 67, 80, [255, 200, 130], 50, 0.45);
  const d = P2(); d.moveTo(-20, 100); for (let x = -20; x <= SW + 20; x += 10) d.lineTo(x, 78 - 12 * Math.exp(-Math.pow((x - 400) / 220, 2)) - 8 * Math.exp(-Math.pow((x - 1000) / 180, 2)) - Math.sin(x * 0.02) * 2); d.lineTo(SW + 20, 100); d.closePath();
  fillPath(ctx, d, lin(ctx, 0, 60, 0, 100, [[0, '#e8c898'], [1, '#8a6a48']]));
  const grass = P2(); for (let x = -10; x < SW + 10; x += 3) { const h = between(R, 4, 10); grass.moveTo(x, 84); grass.lineTo(x + between(R, -3, 3), 84 - h); } strokePath(ctx, grass, rgba([90, 100, 50], 0.8), 0.8);
  for (const x of [150, 230, 300, 1060, 1140, 1220]) { const t = P2(); t.moveTo(x, 84); t.lineTo(x + 2, 40); t.lineTo(x + 4, 84); t.closePath(); fillPath(ctx, t, rgba([40, 26, 20])); canopy(ctx, R, x + 4, 40, 50, 16, [40, 60, 40], [16, 24, 16], { n: 24 }); }
  if (o.walkers !== false) { const p = P2(); personPath(p, 620, 88, 24); personPath(p, 650, 88, 22); fillPath(ctx, p, '#1a120e'); }
  anchored(ctx, 'L', () => { iconAt(ctx, 'pine-tree', 50, 340, 300, '#0e100c'); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 180, 160, [255, 190, 120], 0.3, true); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#a88a68'], [1, '#14100c']]));
  finish(ctx, { split: 0.3 });
};
