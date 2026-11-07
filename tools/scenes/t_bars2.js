// Bars, part 2: beach shacks, pubs and breweries, colonial clubs.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

function thatch(ctx, R, x0, x1, y, depth, c) {
  const p = P2(); p.moveTo(x0, y); p.lineTo(x1, y); p.lineTo(x1, y + depth * 0.4);
  for (let x = x1; x > x0; x -= 6) p.lineTo(x - 3, y + depth * between(R, 0.8, 1.15));
  p.lineTo(x0, y + depth * 0.4); p.closePath(); fillPath(ctx, p, lin(ctx, 0, y, 0, y + depth, [[0, rgba(shade(c, -0.3))], [1, rgba(c)]]));
  const st = P2(); for (let x = x0; x < x1; x += 3) { st.moveTo(x, y + 2); st.lineTo(x + between(R, -2, 2), y + depth * between(R, 0.6, 1)); } strokePath(ctx, st, rgba(shade(c, -0.45), 0.6), 0.6);
}

// Beach bar. o.style: 'shack' (sea, palms, fairy lights) | 'toddy' (backwaters,
// lamps) | 'kiosk' (city beach) | 'pink' (pink sand) | 'overwater' (stilts, lagoon).
TEMPLATES.beachShack = (ctx, R, o) => {
  const style = o.style || 'shack', dark = '#0c0a0c';
  skyPreset(ctx, o.sky || (style === 'toddy' ? 'golden' : 'dusk'));
  ground(ctx, style === 'toddy' ? ['#3a5a4a', '#14241c', '#060c08'] : ['#2a6a8a', '#123048', '#060e18']);
  sunDisc(ctx, o.sunX ?? CX + 260, 74, 22, [255, 120, 60], [255, 220, 140], 80);
  if (style === 'toddy') { forestLine(ctx, R, 78, 14, rgba([30, 50, 34])); for (let x = 60; x < SW; x += between(R, 40, 90)) palm(ctx, R, x, 80, between(R, 34, 52), rgba([20, 34, 24])); water(ctx, R, 78, 100, [70, 100, 80], { n: 40 }); reflection(ctx, R, o.sunX ?? CX + 260, 79, 96, [255, 200, 120], 50, 0.4); }
  else { water(ctx, R, 72, 100, style === 'pink' ? [60, 150, 170] : [40, 110, 140], { n: 60 }); reflection(ctx, R, o.sunX ?? CX + 260, 73, 96, [255, 200, 120], 60, 0.45); if (o.boats !== false) { dhow(ctx, 420, 76, 22, rgba([20, 20, 30]), {}); sailboat(ctx, 980, 76, 20, rgba([20, 20, 30])); } }
  if (style === 'kiosk') { const sl = P2(); sl.moveTo(860, 74); sl.quadraticCurveTo(900, 22, 930, 20); sl.quadraticCurveTo(960, 26, 970, 74); sl.closePath(); fillPath(ctx, sl, rgba([20, 26, 40])); skyline(ctx, R, 74, rgba([20, 24, 36]), { h: 18, lit: 0.3, x0: 0 }); }
  if (style === 'overwater') { for (let i = 0; i < 6; i++) { const x = 140 + i * 210, y = 66; if (Math.abs(x - CX) < 100) continue; const v = P2(); v.moveTo(x - 30, y); v.lineTo(x, y - 18); v.lineTo(x + 30, y); v.closePath(); v.rect(x - 22, y, 44, 10); for (const k of [-18, -6, 6, 18]) v.rect(x + k, y + 10, 2, 8); fillPath(ctx, v, rgba([30, 24, 22])); rect(ctx, x - 8, y + 2, 16, 6, rgba([255, 200, 120], 0.8)); glow(ctx, x, y + 6, 24, [255, 180, 90], 0.35, true); } }
  // the shack: thatched roof across the strip, posts, string lights, a counter
  const roofC = style === 'kiosk' ? [210, 200, 180] : [150, 110, 60];
  thatch(ctx, R, -20, SW + 20, -4, 26, roofC);
  for (let x = 40; x < SW; x += 150) { if (Math.abs(x - CX) < 60) continue; rect(ctx, x - 3, 18, 6, 80, lin(ctx, x - 3, 0, x + 3, 0, [[0, '#3a2412'], [0.5, '#7a5228'], [1, '#2a180a']])); }
  stringLights(ctx, 0, 22, CX - 40, 22, 14, 12, [255, 200, 120], 1.6); stringLights(ctx, CX + 40, 22, SW, 22, 14, 12, [255, 200, 120], 1.6);
  if (style === 'toddy') for (const x of [460, 880]) { line(ctx, x, 20, x, 40, '#1a1008', 1); glow(ctx, x, 46, 20, [255, 170, 70], 0.6, true); const l = P2(); l.ellipse(x, 46, 4, 6, 0, 0, TAU); fillPath(ctx, l, rgba([255, 200, 120])); }
  // counter with drinks
  rect(ctx, -20, 82, SW + 40, 12, lin(ctx, 0, 82, 0, 94, [[0, '#8a6030'], [1, '#3a2410']]));
  const pal = { glass: [[220, 230, 220], [140, 90, 40], [60, 110, 70]], liquid: [[250, 180, 60], [255, 120, 90], [200, 230, 120]], label: [[250, 240, 220], [220, 60, 50]], cap: [[30, 20, 15]] };
  if (style === 'toddy') { for (const x of [470, 520, 560, 800, 850, 900]) { const pot = P2(); pot.ellipse(x, 76, 9, 8, 0, 0, TAU); pot.rect(x - 4, 66, 8, 4); fillPath(ctx, pot, lin(ctx, x - 9, 0, x + 9, 0, [[0, '#5a3a1a'], [0.5, '#a0703a'], [1, '#3a2410']])); } }
  else { bottleRow(ctx, R, 450, 610, 82, 22, pal, { kinds: ['rum', 'round', 'tall', 'gin'] }); bottleRow(ctx, R, 740, 930, 82, 22, pal, { kinds: ['rum', 'round', 'tall', 'gin'] }); }
  for (const x of [380, 960, 1050]) { const g = P2(); g.moveTo(x - 5, 70); g.lineTo(x + 5, 70); g.lineTo(x + 3.5, 82); g.lineTo(x - 3.5, 82); g.closePath(); fillPath(ctx, g, rgba([255, 160, 80], 0.85)); line(ctx, x + 2, 70, x + 6, 62, rgba([255, 80, 120]), 1); circle(ctx, x - 4, 70, 2, rgba([240, 220, 60])); }
  anchored(ctx, 'L', () => { palm(ctx, R, 40, 340, 300, dark, { lean: 0.3, fronds: 11 }); });
  anchored(ctx, 'R', () => { palm(ctx, R, SW - 50, 340, 280, dark, { lean: -0.3, fronds: 10 }); glow(ctx, SW - 120, 240, 120, [255, 170, 80], 0.3, true); });
  // sand or deck under the rail
  const floorC = style === 'pink' ? [240, 200, 200] : style === 'overwater' ? [140, 100, 60] : style === 'kiosk' ? [230, 220, 200] : [220, 190, 140];
  if (style === 'overwater') planks(ctx, F - 10, shade(floorC, -0.2));
  else { rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, rgba(shade(floorC, -0.35))], [1, rgba(shade(floorC, -0.8))]])); }
  if (style === 'kiosk') { const wv = P2(); for (let y = F + 4; y < SH; y += 16) { wv.moveTo(0, y); for (let x = 0; x <= SW; x += 40) { wv.quadraticCurveTo(x + 10, y - 7, x + 20, y); wv.quadraticCurveTo(x + 30, y + 7, x + 40, y); } } strokePath(ctx, wv, rgba([20, 20, 20], 0.55), 4); }
  finish(ctx, { split: 0.3, vignette: 0.42 });
};

// Pub / beer hall / brewery / saloon. o.style: 'irish' | 'belgian' | 'bavarian' | 'brewery' | 'outback' | 'saloon'.
TEMPLATES.pub = (ctx, R, o) => {
  const style = o.style || 'irish', wood = o.wood || { irish: [70, 36, 20], belgian: [60, 40, 24], bavarian: [150, 110, 70], brewery: [60, 50, 44], outback: [110, 80, 50], saloon: [100, 60, 30] }[style];
  rect(ctx, 0, 0, SW, SH, rgba(shade(wood, -0.6)));
  // back wall: panelling or brick or corrugated iron
  if (style === 'brewery' || style === 'outback') { for (let x = 0; x < SW; x += 7) rect(ctx, x, 0, 6, 110, lin(ctx, x, 0, x + 6, 0, [[0, rgba(shade(wood, -0.4))], [0.5, rgba(shade(wood, 0.1))], [1, rgba(shade(wood, -0.5))]])); }
  else { for (let x = 0; x < SW; x += 46) { rect(ctx, x + 3, 6, 40, 80, lin(ctx, 0, 6, 0, 86, [[0, rgba(shade(wood, -0.1))], [1, rgba(shade(wood, -0.45))]])); } }
  glow(ctx, CX, 60, 520, o.light || [255, 170, 80], 0.32, true);
  if (style === 'bavarian') { const g = P2(); for (let x = -20; x < SW + 20; x += 60) { g.moveTo(x, 4); g.quadraticCurveTo(x + 30, 22, x + 60, 4); } strokePath(ctx, g, rgba([40, 90, 40]), 4); const dia = P2(); for (let x = 0; x < SW; x += 16) for (let y = 0; y < 8; y += 8) { dia.moveTo(x, y); dia.lineTo(x + 8, y + 4); dia.lineTo(x, y + 8); dia.lineTo(x - 8, y + 4); dia.closePath(); } fillPath(ctx, dia, rgba([60, 120, 200], 0.9)); }
  if (style === 'brewery') { for (const x of [CX - 200, CX + 200]) { const k = P2(); k.ellipse(x, 52, 42, 40, 0, 0, TAU); fillPath(ctx, k, lin(ctx, x - 42, 0, x + 42, 0, [[0, '#6a3010'], [0.4, '#e08a4a'], [0.6, '#f4b07a'], [1, '#5a2808']])); rect(ctx, x - 3, -10, 6, 20, '#5a2808'); line(ctx, x + 40, 50, x + 90, 30, '#a05a28', 4); } }
  if (style === 'saloon') { for (const x of [CX - 160, CX + 160]) { const m = P2(); m.rect(x - 34, 16, 68, 46); fillPath(ctx, m, lin(ctx, x - 34, 16, x + 34, 62, [[0, '#d8c8a0'], [1, '#6a5a40']])); strokePath(ctx, m, rgba([180, 140, 60]), 3); } }
  // the mirror back-bar with bottles and the taps
  const pal = { glass: [[90, 60, 30], [40, 70, 40], [200, 190, 170], [130, 80, 40]], liquid: [[200, 120, 30], [160, 70, 20], [230, 180, 60]], label: [[240, 230, 200], [30, 20, 15], [200, 40, 40]], cap: [[30, 20, 15], [200, 160, 80]] };
  backlight(ctx, 0, SW, 60, 30, [255, 180, 90], 0.4);
  bottleRow(ctx, R, -20, SW + 20, 60, 26, pal, { kinds: style === 'irish' ? ['whisky', 'whisky', 'round', 'wine'] : ['tall', 'wine', 'gin', 'whisky'], skip: [CX - 60, CX + 60] });
  shelf(ctx, -20, SW + 20, 60, 5, shade(wood, 0.25), shade(wood, -0.15));
  // pints and steins on the counter in the hero zones
  const beer = style === 'irish' ? [[20, 12, 10], [240, 230, 210]] : [[230, 160, 40], [250, 245, 230]];
  for (const x of [470, 505, 540, 575, 760, 795, 830, 870, 905]) {
    if (style === 'bavarian') { const m = P2(); m.rect(x - 7, 66, 14, 18); fillPath(ctx, m, rgba([230, 230, 225], 0.9)); rect(ctx, x - 6, 68, 12, 14, rgba(beer[0], 0.85)); const hd = P2(); hd.arc(x + 9, 75, 4, -1.4, 1.4); strokePath(ctx, hd, rgba([230, 230, 225]), 1.6); }
    else { const g = P2(); g.moveTo(x - 6, 66); g.lineTo(x + 6, 66); g.lineTo(x + 4.5, 84); g.lineTo(x - 4.5, 84); g.closePath(); fillPath(ctx, g, rgba(beer[0], 0.9)); rect(ctx, x - 6, 66, 12, 3.5, rgba(beer[1])); }
  }
  const taps = P2(); for (let k = 0; k < 6; k++) { const x = CX - 200 + k * 16 + (k > 2 ? 320 : 0); taps.rect(x - 1.5, 62, 3, 14); taps.rect(x - 3, 58, 6, 6); } fillPath(ctx, taps, lin(ctx, 0, 58, 0, 76, [[0, '#f0d090'], [1, '#8a6a30']]));
  rect(ctx, -20, 84, SW + 40, 10, lin(ctx, 0, 84, 0, 94, [[0, rgba(shade(wood, 0.3))], [1, rgba(shade(wood, -0.3))]]));
  rect(ctx, -20, 84, SW + 40, 2, rgba([230, 190, 110], 0.6));
  // corners: casks, a dartboard or a stag's head, lamps
  anchored(ctx, 'L', () => { glow(ctx, 80, 200, 200, [255, 170, 80], 0.3, true); for (const [x, y] of [[60, 300], [150, 300], [105, 222]]) { const k = P2(); k.ellipse(x, y, 44, 40, 0, 0, TAU); fillPath(ctx, k, lin(ctx, x - 44, 0, x + 44, 0, [[0, '#3a2210'], [0.5, '#8a5a2a'], [1, '#2a180a']])); const h = P2(); h.ellipse(x, y, 44, 40, 0, 0, TAU); strokePath(ctx, h, rgba([40, 40, 40]), 3); circle(ctx, x, y, 22, rgba([0, 0, 0], 0.2)); } });
  anchored(ctx, 'R', () => {
    glow(ctx, SW - 90, 150, 160, [255, 170, 80], 0.3, true);
    if (style === 'irish') { for (const [r, c] of [[34, [20, 20, 20]], [30, [220, 210, 180]], [22, [30, 120, 60]], [14, [200, 40, 40]], [4, [30, 120, 60]]]) circle(ctx, SW - 110, 140, r, rgba(c)); }
    else if (style === 'outback' || style === 'saloon') iconAt(ctx, 'buffalo-head', SW - 110, 190, 120, '#1a100a');
    else { const l = P2(); l.moveTo(SW - 150, 110); l.lineTo(SW - 70, 110); l.lineTo(SW - 90, 150); l.lineTo(SW - 130, 150); l.closePath(); fillPath(ctx, l, rgba([200, 150, 60])); glow(ctx, SW - 110, 160, 60, [255, 190, 100], 0.5, true); }
  });
  planks(ctx, F - 10, shade(wood, -0.1));
  finish(ctx, { split: 0.25, vignette: 0.5 });
};

// Colonial club bar: ceiling fans, palms, rattan, a window on the view.
// o.view: 'hills' (tea hills) | 'harbour' | 'garden'.
TEMPLATES.colonialClub = (ctx, R, o) => {
  const wall = o.wall || [226, 214, 186], dark = '#1a1410';
  rect(ctx, 0, 0, SW, SH, rgba(shade(wall, -0.55)));
  rect(ctx, 0, 0, SW, 96, lin(ctx, 0, 0, 0, 96, [[0, rgba(shade(wall, -0.45))], [1, rgba(shade(wall, -0.15))]]));
  // tall windows on the view
  for (let i = -3; i <= 3; i++) {
    const x = CX + i * 170; if (i === 0) continue;
    const win = P2(); win.moveTo(x - 46, 84); win.lineTo(x - 46, 30); win.quadraticCurveTo(x, 4, x + 46, 30); win.lineTo(x + 46, 84); win.closePath();
    ctx.save(); ctx.clip(win);
    sky(ctx, SKIES[o.sky || 'dusk'], 0, 90);
    if (o.view === 'hills') { mountains(ctx, R, 70, 40, [190, 170, 200], { snow: [250, 240, 245], snowLine: 0.5 }); const hl = P2(); for (let y = 66; y < 90; y += 4) { hl.moveTo(x - 50, y); hl.quadraticCurveTo(x, y - 8, x + 50, y + 2); } strokePath(ctx, hl, rgba([40, 80, 50], 0.7), 2.4); }
    else if (o.view === 'harbour') { water(ctx, R, 60, 90, [40, 80, 110], { n: 10 }); junk(ctx, x + 10, 62, 18, rgba([30, 30, 40])); }
    else { canopy(ctx, R, x, 64, 110, 40, [70, 110, 60], [30, 50, 30]); }
    ctx.restore();
    strokePath(ctx, win, rgba([250, 245, 230]), 4);
    const mull = P2(); mull.moveTo(x, 12); mull.lineTo(x, 84); mull.moveTo(x - 46, 50); mull.lineTo(x + 46, 50); strokePath(ctx, mull, rgba([250, 245, 230]), 2);
  }
  // fans, the bar back behind the dealer, rattan chairs, palms
  for (const x of [CX - 260, CX + 260]) { line(ctx, x, 0, x, 14, dark, 1.5); const f = P2(); for (let k = 0; k < 4; k++) { const a = k * Math.PI / 2 + 0.4; f.ellipse(x + Math.cos(a) * 26, 16 + Math.sin(a) * 4, 26, 3.2, a * 0.1, 0, TAU); } fillPath(ctx, f, rgba([60, 40, 26])); circle(ctx, x, 16, 4, rgba([180, 140, 70])); }
  const back = P2(); back.rect(CX - 70, 20, 140, 70); fillPath(ctx, back, lin(ctx, 0, 20, 0, 90, [[0, '#5a3a1e'], [1, '#2a1a0c']]));
  const pal = { glass: [[130, 80, 30], [200, 190, 170], [60, 90, 50]], liquid: [[190, 110, 30], [230, 200, 120]], label: [[240, 230, 200], [20, 60, 40]], cap: [[30, 20, 15]] };
  bottleRow(ctx, R, CX - 66, CX + 66, 52, 22, pal, { kinds: ['whisky', 'gin', 'decanter'] }); shelf(ctx, CX - 70, CX + 70, 52, 4, [150, 100, 50], [90, 60, 30]);
  for (const x of [440, 600, 760, 930]) { const ch = P2(); ch.moveTo(x - 16, 92); ch.quadraticCurveTo(x - 20, 66, x, 62); ch.quadraticCurveTo(x + 20, 66, x + 16, 92); ch.closePath(); fillPath(ctx, ch, rgba([150, 110, 60])); const wv = P2(); for (let k = -12; k <= 12; k += 4) { wv.moveTo(x + k, 66); wv.lineTo(x + k * 1.2, 92); } strokePath(ctx, wv, rgba([90, 60, 30], 0.6), 0.8); }
  rect(ctx, -20, 88, SW + 40, 6, '#3a2412');
  anchored(ctx, 'L', () => { palm(ctx, R, 70, 340, 240, '#0e1a10', { lean: 0.1, fronds: 12 }); const pot = P2(); pot.moveTo(36, 340); pot.lineTo(104, 340); pot.lineTo(96, 390); pot.lineTo(44, 390); pot.closePath(); fillPath(ctx, pot, rgba([200, 190, 170])); });
  anchored(ctx, 'R', () => { palm(ctx, R, SW - 70, 340, 240, '#0e1a10', { lean: -0.1, fronds: 12 }); glow(ctx, SW - 140, 120, 90, [255, 200, 120], 0.35, true); });
  tiles(ctx, F - 10, [190, 170, 140], [60, 40, 30], 28);
  finish(ctx, { split: 0.25, vignette: 0.45 });
};
