// Sports, part 2: stadiums by sport, indoor courts, wrestling, races on land and water.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

function floodTower(ctx, x, base, h, c) {
  const p = P2(); p.moveTo(x - 4, base); p.lineTo(x - 1.5, base - h); p.lineTo(x + 1.5, base - h); p.lineTo(x + 4, base); p.closePath(); p.rect(x - 14, base - h - 12, 28, 12); fillPath(ctx, p, c);
  const l = []; for (let r = 0; r < 3; r++) for (let k = 0; k < 6; k++) l.push([x - 12 + k * 4.8, base - h - 10 + r * 4, 1.4]); dots(ctx, l, rgba([255, 255, 240]));
  glow(ctx, x, base - h - 6, 70, [255, 250, 230], 0.45, true);
  beam(ctx, x, base - h - 4, Math.atan2(80, CX - x) , Math.hypot(CX - x, 80) * 0.9, 0.3, [255, 250, 230], 0.12, { blur: 4 });
}
function stands(ctx, R, top, base, cols, o = {}) {
  const rows = Math.round((base - top) / 7);
  for (let r = 0; r < rows; r++) { const y = base - r * 7; rect(ctx, -20, y - 7, SW + 40, 7, rgba(mix([40, 36, 48], [16, 14, 20], r / rows))); }
  const buckets = cols.map(() => []);
  for (let y = top + 3; y < base; y += 4.2) for (let x = -10; x < SW + 10; x += between(R, 3.4, 5)) buckets[Math.floor(R() * cols.length)].push([x, y + between(R, -0.6, 0.6), 1.45]);
  cols.forEach((c, i) => dots(ctx, buckets[i], rgba(c, o.alpha ?? 0.75)));
}
// One player silhouette with the kit for the sport, feet at (x, base).
function player(ctx, sport, x, base, h, c, o = {}) {
  const p = P2(), s = h / 100, d = o.flip ? -1 : 1;
  personPath(p, x, base, h, { armUp: o.armUp || 0 }); fillPath(ctx, p, c);
  if (sport === 'cricket' && o.role === 'bat') { line(ctx, x + d * 10 * s, base - 50 * s, x + d * 30 * s, base - 8 * s, c, 4.5 * s); }
  if (sport === 'hockey' || sport === 'iceHockey') { const st = P2(); st.moveTo(x + d * 8 * s, base - 55 * s); st.lineTo(x + d * 22 * s, base - 4 * s); st.lineTo(x + d * 32 * s, base - 4 * s); strokePath(ctx, st, c, 2 * s); }
  if (sport === 'baseball' && o.role === 'bat') line(ctx, x - d * 6 * s, base - 74 * s, x - d * 30 * s, base - 104 * s, c, 3.2 * s);
  if (sport === 'americanFootball') { circle(ctx, x, base - 89 * s, 9 * s, c); }
}

// o.sport: cricket | football | hockey | baseball | rugby | americanFootball
// o.turf, o.cols (crowd colours), o.backdrop: 'sea' | 'hills' | 'skyline' | 'ruins', o.confetti, o.flares, o.haka
TEMPLATES.stadiumNight = (ctx, R, o) => {
  const sport = o.sport || 'football', turf = o.turf || (sport === 'hockey' ? [40, 90, 170] : [60, 130, 60]), dark = '#0a0c10';
  skyPreset(ctx, o.sky || 'night');
  ground(ctx, [shade(turf, 0.05), shade(turf, -0.45), shade(turf, -0.8)]);
  stars(ctx, R, 40, [0, 0, SW, 20], { alpha: 0.5 });
  if (o.backdrop === 'hills') mountains(ctx, R, 40, 26, [40, 46, 70], { snow: [220, 225, 240], snowLine: 0.55, bottom: 60 });
  if (o.backdrop === 'skyline') skyline(ctx, R, 40, rgba([20, 22, 36]), { h: 26, lit: 0.4, bottom: 60 });
  if (o.backdrop === 'ruins') { const r = P2(); for (const x of [180, 330, 1030, 1170]) { r.rect(x - 30, 22, 60, 30); for (let k = 0; k < 4; k++) r.rect(x - 30 + k * 18, 16, 10, 6); } fillPath(ctx, r, rgba([60, 40, 40])); }
  // the stands and their roof
  stands(ctx, R, 30, 76, o.cols || [[255, 255, 255], [40, 80, 200], [230, 60, 60]]);
  rect(ctx, -20, 22, SW + 40, 8, lin(ctx, 0, 22, 0, 30, [[0, '#2a2a34'], [1, '#121218']]));
  if (o.backdrop === 'sea') { rect(ctx, 0, 0, SW, 22, lin(ctx, 0, 0, 0, 22, [[0, '#0a1838'], [1, '#14305a']])); const sh = []; for (let i = 0; i < 30; i++) sh.push([between(R, 0, SW), between(R, 6, 20), 0.8]); dots(ctx, sh, rgba([255, 220, 160], 0.7)); }
  // ad boards under the stands
  for (let x = -20, k = 0; x < SW + 20; x += 80, k++) rect(ctx, x, 76, 78, 5, rgba(k % 2 ? (o.board || [230, 60, 60]) : [250, 250, 250], 0.85));
  // the screen behind the dealer
  rect(ctx, CX - 90, 2, 180, 18, '#0a0a10'); rect(ctx, CX - 86, 5, 70, 4, rgba(o.cols ? o.cols[1] : [40, 80, 200])); rect(ctx, CX + 16, 5, 70, 4, rgba(o.cols ? o.cols[2] : [230, 60, 60])); rect(ctx, CX - 86, 12, 172, 3, rgba([255, 255, 255], 0.5));
  for (const x of [120, 300, 1044, 1224]) floodTower(ctx, x, 30, 26, '#1a1a22');
  // the field
  const fld = P2(); for (let x = -20, k = 0; x < SW + 20; x += 40, k++) if (k % 2) fld.rect(x, 81, 40, 16); fillPath(ctx, fld, rgba(shade(turf, -0.12)));
  rect(ctx, 0, 81, SW, 16, lin(ctx, 0, 81, 0, 97, [[0, rgba(turf, 0.0)], [1, rgba([0, 0, 0], 0.2)]]));
  if (sport === 'cricket') { rect(ctx, CX - 130, 85, 260, 6, rgba([200, 180, 130], 0.9)); const st = P2(); for (const sx of [CX - 120, CX + 120]) for (let k = -1; k <= 1; k++) st.rect(sx + k * 2.4 - 0.6, 74, 1.2, 12); fillPath(ctx, st, rgba([240, 230, 210])); }
  if (sport === 'baseball') { const dm = P2(); dm.moveTo(CX - 140, 92); dm.lineTo(CX, 82); dm.lineTo(CX + 140, 92); strokePath(ctx, dm, rgba([200, 150, 100], 0.9), 3); }
  if (sport === 'americanFootball') { for (let x = 380; x < 980; x += 30) rect(ctx, x, 82, 1.4, 14, rgba([255, 255, 255], 0.6)); const gp = P2(); for (const gx of [300, 1044]) { gp.rect(gx - 0.8, 50, 1.6, 32); gp.rect(gx - 14, 50, 28, 1.6); gp.rect(gx - 14, 30, 1.6, 20); gp.rect(gx + 12.4, 30, 1.6, 20); } fillPath(ctx, gp, rgba([250, 220, 60])); }
  if (sport === 'football' || sport === 'hockey' || sport === 'rugby') { const gl = P2(); for (const gx of [330, 1014]) { if (sport === 'rugby') { gl.rect(gx - 12, 40, 1.6, 52); gl.rect(gx + 10.4, 40, 1.6, 52); gl.rect(gx - 12, 70, 24, 1.6); } else { gl.rect(gx - 18, 72, 36, 1.6); gl.rect(gx - 18, 72, 1.6, 20); gl.rect(gx + 16.4, 72, 1.6, 20); } } fillPath(ctx, gl, rgba([245, 245, 245])); if (sport !== 'rugby') { const net = P2(); for (const gx of [330, 1014]) for (let k = 0; k < 8; k++) { net.moveTo(gx - 18 + k * 5, 73); net.lineTo(gx - 18 + k * 5, 92); } strokePath(ctx, net, rgba([255, 255, 255], 0.3), 0.6); } }
  // players
  const pc = '#0a0c10';
  if (o.haka) { for (let k = 0; k < 9; k++) player(ctx, sport, 470 + k * 52 + (k > 3 ? 90 : 0), 96, 46, pc, { armUp: k % 2 ? 2 : 1 }); }
  else if (sport === 'cricket') { player(ctx, sport, CX - 150, 96, 46, pc, { role: 'bat' }); player(ctx, sport, CX + 160, 96, 44, pc, { armUp: 1, flip: true }); for (const x of [440, 520, 820, 900, 960]) player(ctx, sport, x, 95, 30, pc); circle(ctx, CX - 110, 70, 2, rgba([230, 40, 40])); }
  else { const xs = [460, 520, 580, 760, 820, 880, 930]; xs.forEach((x, i) => player(ctx, sport, x, 96, 40 + (i % 3) * 3, pc, { flip: i > 2, role: i === 1 ? 'bat' : null, armUp: i === 5 ? 1 : 0 })); if (sport === 'football') circle(ctx, 640, 93, 2.6, rgba([255, 255, 255])); if (sport === 'rugby' || sport === 'americanFootball') { const b = P2(); b.ellipse(700, 70, 4, 2.6, 0.5, 0, TAU); fillPath(ctx, b, rgba([150, 90, 50])); } }
  if (o.flares) for (const x of [80, 200, 1140, 1260]) { glow(ctx, x, 54, 40, [255, 60, 40], 0.7, true); withBlur(ctx, 10, () => oval(ctx, x + 10, 30, 40, 16, rgba([200, 160, 170], 0.25))); }
  if (o.confetti) { const cf = [[], []]; for (let i = 0; i < 240; i++) cf[i % 2].push([between(R, 0, SW), between(R, 0, 110), between(R, 0.8, 1.6)]); dots(ctx, cf[0], rgba((o.cols || [[255, 255, 255]])[1] || [255, 255, 255], 0.9)); dots(ctx, cf[1], rgba((o.cols || [[255, 255, 255]])[2] || [255, 220, 60], 0.9)); }
  // corners: flags waved by the crowd
  const fc = o.cols || [[255, 255, 255], [40, 80, 200], [230, 60, 60]];
  anchored(ctx, 'L', () => { glow(ctx, 40, 160, 200, fc[1], 0.25, true); line(ctx, 110, 60, 140, 300, dark, 2.4); const f = P2(); f.moveTo(110, 60); f.quadraticCurveTo(80, 52, 54, 64); f.quadraticCurveTo(40, 80, 30, 96); f.quadraticCurveTo(60, 88, 86, 98); f.quadraticCurveTo(100, 88, 114, 100); f.closePath(); fillPath(ctx, f, lin(ctx, 30, 0, 114, 0, [[0, rgba(shade(fc[1], -0.3))], [0.5, rgba(fc[1])], [1, rgba(shade(fc[1], -0.2))]])); crowd(ctx, R, -10, 220, 330, 40, dark, { hands: 0.4 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 40, 160, 200, fc[2], 0.25, true); line(ctx, SW - 110, 60, SW - 140, 300, dark, 2.4); const f = P2(); f.moveTo(SW - 110, 60); f.quadraticCurveTo(SW - 80, 52, SW - 54, 64); f.quadraticCurveTo(SW - 40, 80, SW - 30, 96); f.quadraticCurveTo(SW - 60, 88, SW - 86, 98); f.quadraticCurveTo(SW - 100, 88, SW - 114, 100); f.closePath(); fillPath(ctx, f, lin(ctx, SW - 114, 0, SW - 30, 0, [[0, rgba(shade(fc[2], -0.2))], [0.5, rgba(fc[2])], [1, rgba(shade(fc[2], -0.3))]])); crowd(ctx, R, SW - 220, SW + 10, 330, 40, dark, { hands: 0.4 }); });
  // the turf under the rail with mower stripes
  for (let x = -40, k = 0; x < SW + 40; x += 80, k++) { const p = P2(); p.moveTo(x, F - 10); p.lineTo(x + 80, F - 10); p.lineTo(x + 110, SH); p.lineTo(x + 30, SH); p.closePath(); fillPath(ctx, p, rgba(k % 2 ? shade(turf, -0.2) : shade(turf, -0.38))); }
  rect(ctx, 0, F - 10, SW, 3, rgba([255, 255, 255], 0.6));
  floorShade(ctx);
  finish(ctx, { split: 0.25, vignette: 0.45 });
};

// Indoor arena. o.court: badminton | kabaddi | basketball | volleyball | taekwondo | waterPolo | iceHockey
TEMPLATES.indoorCourt = (ctx, R, o) => {
  const court = o.court || 'basketball', dark = '#0a0a10';
  const floorC = o.floorC || { badminton: [40, 130, 90], kabaddi: [40, 110, 200], basketball: [200, 140, 80], volleyball: [230, 130, 60], taekwondo: [40, 90, 200], waterPolo: [40, 150, 200], iceHockey: [220, 232, 245] }[court];
  rect(ctx, 0, 0, SW, SH, '#07070c');
  stands(ctx, R, 6, 70, o.cols || [[255, 255, 255], [230, 180, 40], [60, 120, 220]]);
  // roof lights and a centre-hung scoreboard
  for (let x = 60; x < SW; x += 120) { glow(ctx, x, 2, 50, [255, 250, 235], 0.5, true); }
  const sb = P2(); sb.rect(CX - 70, 0, 140, 22); fillPath(ctx, sb, '#101018'); rect(ctx, CX - 64, 4, 128, 14, lin(ctx, CX - 64, 0, CX + 64, 0, [[0, rgba(o.cols ? o.cols[1] : [230, 180, 40], 0.8)], [1, rgba(o.cols ? o.cols[2] : [60, 120, 220], 0.8)]]));
  for (const x of [CX - 220, CX + 220]) beam(ctx, x, 0, Math.PI / 2, 100, 0.5, [255, 250, 235], 0.16, { blur: 4 });
  // the court itself, seen low across the rail
  rect(ctx, -20, 70, SW + 40, 26, lin(ctx, 0, 70, 0, 96, [[0, rgba(shade(floorC, 0.15))], [1, rgba(shade(floorC, -0.25))]]));
  rect(ctx, -20, 70, SW + 40, 1.5, rgba([255, 255, 255], 0.7));
  if (court === 'badminton' || court === 'volleyball') { const n = P2(); n.rect(CX - 300, 54, 600, 1.4); for (let x = CX - 300; x < CX + 300; x += 5) n.rect(x, 54, 0.6, court === 'badminton' ? 12 : 16); n.rect(CX - 300, 54, 2, 34); n.rect(CX + 298, 54, 2, 34); fillPath(ctx, n, rgba([240, 240, 240], 0.7)); }
  if (court === 'basketball') for (const gx of [300, 1044]) { const h = P2(); h.rect(gx - 1.5, 30, 3, 60); h.rect(gx - 16, 26, 32, 20); fillPath(ctx, h, rgba([230, 230, 235], 0.85)); const r = P2(); r.ellipse(gx, 48, 9, 2.6, 0, 0, TAU); strokePath(ctx, r, rgba([255, 120, 30]), 1.6); const net = P2(); for (let k = -8; k <= 8; k += 4) { net.moveTo(gx + k, 48); net.lineTo(gx + k * 0.6, 58); } strokePath(ctx, net, rgba([255, 255, 255], 0.6), 0.6); }
  if (court === 'waterPolo') { const w = P2(); for (let x = -20; x < SW + 20; x += 18) { w.moveTo(x, 84); w.quadraticCurveTo(x + 9, 80, x + 18, 84); } strokePath(ctx, w, rgba([255, 255, 255], 0.4), 1); for (const gx of [300, 1044]) { const g = P2(); g.rect(gx - 16, 62, 32, 1.4); g.rect(gx - 16, 62, 1.4, 16); g.rect(gx + 14.6, 62, 1.4, 16); fillPath(ctx, g, rgba([250, 250, 250])); } }
  if (court === 'iceHockey') { rect(ctx, -20, 66, SW + 40, 5, rgba([250, 250, 255], 0.9)); rect(ctx, CX - 2, 70, 4, 26, rgba([200, 30, 40], 0.7)); for (const gx of [300, 1044]) { const g = P2(); g.rect(gx - 10, 76, 20, 1.4); g.rect(gx - 10, 76, 1.4, 12); g.rect(gx + 8.6, 76, 1.4, 12); fillPath(ctx, g, rgba([220, 40, 40])); } }
  if (court === 'kabaddi' || court === 'taekwondo') { const lines = P2(); lines.rect(CX - 1, 70, 2, 26); lines.rect(-20, 82, SW + 40, 1.2); fillPath(ctx, lines, rgba([255, 255, 255], 0.7)); }
  // the players
  const pc = '#0a0a10';
  if (court === 'badminton') { player(ctx, court, 520, 94, 50, pc, { armUp: 1 }); player(ctx, court, 830, 94, 50, pc, { armUp: 1, flip: true }); line(ctx, 528, 46, 540, 30, pc, 1.2); const sh = P2(); sh.moveTo(690, 26); sh.lineTo(696, 22); sh.lineTo(696, 30); sh.closePath(); fillPath(ctx, sh, rgba([255, 255, 255])); }
  else if (court === 'kabaddi') { player(ctx, court, 600, 94, 50, pc, { armUp: 2 }); for (const x of [760, 800, 840, 880, 920]) player(ctx, court, x, 94, 46, pc, { flip: true }); }
  else if (court === 'taekwondo') { const p = P2(); personPath(p, 560, 94, 50); fillPath(ctx, p, pc); line(ctx, 562, 70, 610, 46, pc, 5); player(ctx, court, 790, 94, 50, pc, { flip: true }); }
  else if (court === 'waterPolo') { const hd = []; for (const x of [480, 540, 600, 760, 820, 880]) hd.push([x, 80, 5]); dots(ctx, hd, pc); line(ctx, 545, 78, 552, 58, pc, 2.4); circle(ctx, 556, 54, 3, rgba([250, 220, 40])); }
  else if (court === 'iceHockey') { for (const [x, f] of [[480, false], [560, false], [780, true], [860, true]]) player(ctx, 'iceHockey', x, 94, 48, pc, { flip: f }); circle(ctx, 680, 93, 1.8, pc); }
  else { [470, 540, 600, 760, 820, 890].forEach((x, i) => player(ctx, court, x, 94, 50 + (i % 2) * 4, pc, { flip: i > 2, armUp: i === 1 ? 1 : 0 })); circle(ctx, 556, 36, 4, rgba([230, 110, 40])); }
  anchored(ctx, 'L', () => { glow(ctx, 50, 160, 180, [255, 240, 220], 0.2, true); crowd(ctx, R, -10, 220, 300, 44, dark, { hands: 0.45 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 50, 160, 180, [255, 240, 220], 0.2, true); crowd(ctx, R, SW - 220, SW + 10, 300, 44, dark, { hands: 0.45 }); });
  if (court === 'basketball' || court === 'volleyball') planks(ctx, F - 10, shade(floorC, -0.1)); else rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, rgba(shade(floorC, -0.2))], [1, rgba(shade(floorC, -0.75))]]));
  finish(ctx, { split: 0.25, vignette: 0.45 });
};

// A wrestling pit of red earth (kushti), or a zurkhaneh (o.style 'zurkhaneh').
TEMPLATES.akhada = (ctx, R, o) => {
  const earth = [170, 90, 50], dark = '#140a08', zurk = o.style === 'zurkhaneh';
  if (zurk) { rect(ctx, 0, 0, SW, SH, '#1a0e0a'); const dome = P2(); dome.moveTo(CX - 400, 60); dome.quadraticCurveTo(CX, -60, CX + 400, 60); dome.lineTo(CX + 400, 0); dome.lineTo(CX - 400, 0); dome.closePath(); fillPath(ctx, dome, lin(ctx, 0, 0, 0, 60, [[0, '#2a5a6a'], [1, '#6a4a2a']])); const tile = P2(); for (let x = CX - 380; x < CX + 380; x += 24) { tile.moveTo(x, 40); tile.lineTo(x + 12, 28); tile.lineTo(x + 24, 40); tile.lineTo(x + 12, 52); tile.closePath(); } fillPath(ctx, tile, rgba([60, 140, 170], 0.5)); }
  else { skyPreset(ctx, 'golden'); ground(ctx, [shade(earth, 0.1), shade(earth, -0.4), shade(earth, -0.75)]); const tr = P2(); tr.moveTo(1000, 92); tr.quadraticCurveTo(1010, 50, 1004, 30); tr.lineTo(1016, 30); tr.quadraticCurveTo(1022, 50, 1030, 92); tr.closePath(); fillPath(ctx, tr, dark); canopy(ctx, R, 1010, 20, 260, 40, [60, 60, 30], [24, 24, 12], { n: 120 }); const roots = P2(); for (let k = 0; k < 8; k++) { const x = 960 + k * 14; roots.moveTo(x, 30); roots.lineTo(x + 2, 90); } strokePath(ctx, roots, dark, 0.8); }
  // spectators on the steps, a mace and ropes
  for (let r = 0; r < 3; r++) { rect(ctx, -20, 58 + r * 8, SW + 40, 8, rgba(mix(zurk ? [90, 60, 40] : [150, 100, 70], [40, 26, 18], r / 3))); }
  crowd(ctx, R, -10, SW + 10, 66, 13, dark, { hands: 0.25 });
  // the pit and the bout
  rect(ctx, -20, 80, SW + 40, 16, lin(ctx, 0, 80, 0, 96, [[0, rgba(shade(earth, 0.15))], [1, rgba(shade(earth, -0.3))]]));
  const pc = '#140a08';
  if (zurk) { for (let k = 0; k < 7; k++) { const x = 460 + k * 70 + (k > 2 ? 60 : 0), p = P2(); personPath(p, x, 94, 46, { armUp: 2 }); fillPath(ctx, p, pc); for (const s of [-1, 1]) { const m = P2(); m.ellipse(x + s * 9, 46, 3.5, 8, s * 0.2, 0, TAU); fillPath(ctx, m, pc); } } const drum = P2(); drum.ellipse(CX + 330, 50, 18, 18, 0, 0, TAU); fillPath(ctx, drum, rgba([200, 160, 100])); }
  else {
    const w1 = P2(); personPath(w1, 590, 94, 56); fillPath(ctx, w1, pc); const w2 = P2(); personPath(w2, 610, 94, 54); fillPath(ctx, w2, pc);
    line(ctx, 596, 58, 612, 66, pc, 4); line(ctx, 604, 58, 590, 66, pc, 4);
    const g = P2(); g.moveTo(800, 94); g.lineTo(803, 60); g.lineTo(797, 60); g.closePath(); g.ellipse(800, 52, 10, 12, 0, 0, TAU); fillPath(ctx, g, rgba([200, 150, 60])); circle(ctx, 796, 48, 3, rgba([255, 230, 160], 0.6));
    for (const x of [860, 900]) { const p = P2(); personPath(p, x, 94, 44, { armUp: 1 }); fillPath(ctx, p, pc); }
  }
  const lamps = []; for (let x = 80; x < SW; x += 130) lamps.push(x); for (const x of lamps) { glow(ctx, x, 40, 30, [255, 170, 80], 0.5, true); circle(ctx, x, 40, 2, rgba([255, 220, 150])); }
  anchored(ctx, 'L', () => { glow(ctx, 60, 200, 180, [255, 150, 70], 0.3, true); const p = P2(); personPath(p, 70, 330, 230, { armUp: 2 }); fillPath(ctx, p, pc); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 200, 180, [255, 150, 70], 0.3, true); const g = P2(); g.moveTo(SW - 100, 340); g.lineTo(SW - 94, 160); g.lineTo(SW - 106, 160); g.closePath(); g.ellipse(SW - 100, 140, 30, 36, 0, 0, TAU); fillPath(ctx, g, rgba([180, 130, 50])); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, rgba(shade(earth, -0.2))], [1, rgba(shade(earth, -0.75))]]));
  const pebbles = []; for (let i = 0; i < 160; i++) pebbles.push([between(R, 0, SW), between(R, F, SH), between(R, 0.6, 1.4)]); dots(ctx, pebbles, rgba([0, 0, 0], 0.25));
  finish(ctx, { split: 0.3, vignette: 0.45 });
};

// Racing on four legs. o.animal: 'horse' | 'camel'; o.style: 'turf' | 'desert' | 'rodeo' | 'buzkashi'
TEMPLATES.horseRace = (ctx, R, o) => {
  const style = o.style || 'turf', dark = '#120c0a';
  skyPreset(ctx, o.sky || (style === 'desert' ? 'golden' : 'dusk'));
  ground(ctx, style === 'turf' ? ['#5a8a4a', '#24381c', '#0a1008'] : ['#d8a060', '#6a4424', '#1c1008']);
  if (style === 'turf') { const gs = P2(); gs.rect(CX + 120, 30, 360, 50); fillPath(ctx, gs, lin(ctx, 0, 30, 0, 80, [[0, '#e8e0d0'], [1, '#8a8070']])); const roof = P2(); roof.moveTo(CX + 100, 34); roof.lineTo(CX + 500, 34); roof.lineTo(CX + 480, 20); roof.lineTo(CX + 120, 20); roof.closePath(); fillPath(ctx, roof, rgba([60, 90, 70])); stands(ctx, R, 40, 76, [[240, 240, 240], [230, 60, 90], [60, 120, 220]], {}); canopy(ctx, R, 300, 66, 360, 30, [60, 90, 50], [24, 40, 20]); }
  else if (style === 'desert') { ridge(ctx, R, 82, 12, rgba([170, 100, 70]), { bottom: 100 }); skyline(ctx, R, 78, rgba([150, 100, 90]), { h: 40, lit: 0, windows: false, spires: 0.3, env: (x) => (x > 800 ? 1 : 0.2) }); }
  else if (style === 'buzkashi') { mountains(ctx, R, 82, 40, [120, 110, 140], { snow: [240, 240, 250], bottom: 100 }); }
  else { mesas(ctx, R, 82, rgba([160, 80, 60])); }
  // rails and the race
  rect(ctx, -20, 84, SW + 40, 2, rgba([250, 250, 250], 0.9)); const posts = P2(); for (let x = -20; x < SW + 20; x += 24) posts.rect(x, 84, 1.2, 8); fillPath(ctx, posts, rgba([250, 250, 250], 0.9));
  horizonHaze(ctx, 88, 6, [255, 210, 160], 0.35);
  if (style === 'buzkashi') { for (const [x, f] of [[480, false], [530, true], [570, false], [610, true], [760, false], [800, true], [850, false]]) horse(ctx, x, 96, 48, dark, { flip: f, pose: 'gallop', rider: R() < 0.5 ? 'up' : true }); withBlur(ctx, 8, () => oval(ctx, 660, 86, 240, 12, rgba([200, 160, 120], 0.4))); }
  else if (o.animal === 'camel') { for (const [x, s] of [[480, 52], [560, 50], [760, 54], [850, 50]]) { rimIcon(ctx, 'camel', x, 96, s, dark, [255, 200, 130]); const j = P2(); personPath(j, x - s * 0.05, 96 - s * 0.62, s * 0.3, { armUp: 1 }); fillPath(ctx, j, dark); } }
  else if (style === 'rodeo') { horse(ctx, 560, 96, 64, dark, { pose: 'gallop', rider: 'up' }); const bl = P2(); bl.ellipse(800, 72, 34, 16, -0.3, 0, TAU); bl.ellipse(832, 60, 12, 10, 0, 0, TAU); bl.moveTo(838, 54); bl.lineTo(852, 44); bl.lineTo(842, 56); bl.closePath(); for (const lx of [-24, -12, 12, 24]) bl.rect(800 + lx - 2.4, 80, 4.8, 14); fillPath(ctx, bl, dark); const rd = P2(); personPath(rd, 798, 60, 34, { armUp: 1 }); fillPath(ctx, rd, dark); const fence = P2(); for (let x = -20; x < SW + 20; x += 30) { fence.rect(x, 74, 2, 20); } fence.rect(-20, 78, SW + 40, 2); fence.rect(-20, 86, SW + 40, 2); fillPath(ctx, fence, rgba([90, 60, 40])); }
  else { for (const [x, s] of [[460, 50], [530, 54], [600, 50], [750, 52], [820, 56], [890, 50]]) horse(ctx, x, 96, s, dark, { pose: 'gallop', rider: true }); }
  anchored(ctx, 'L', () => { glow(ctx, 50, 170, 180, [255, 190, 120], 0.3, true); const fp = P2(); fp.rect(100, -10, 10, 340); fillPath(ctx, fp, rgba([240, 240, 240])); circle(ctx, 105, 40, 26, rgba([240, 240, 240])); circle(ctx, 105, 40, 20, rgba([200, 40, 40])); crowd(ctx, R, -10, 90, 320, 40, dark, { hands: 0.5 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 50, 170, 180, [255, 190, 120], 0.3, true); crowd(ctx, R, SW - 200, SW + 10, 320, 40, dark, { hands: 0.5 }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, style === 'turf' ? '#4a6a3a' : '#a07040'], [1, '#100a06']]));
  finish(ctx, { split: 0.3, vignette: 0.45 });
};

// Long boats racing on a river. o.style: 'snake' (Kerala chundan) | 'dragon'.
TEMPLATES.boatRace = (ctx, R, o) => {
  const style = o.style || 'snake', dark = '#0a0c0a', riverC = o.river || [70, 110, 100];
  skyPreset(ctx, o.sky || 'golden');
  ground(ctx, [shade(riverC, 0.1), shade(riverC, -0.45), shade(riverC, -0.8)]);
  if (style === 'snake') { for (let x = 30; x < SW; x += between(R, 30, 70)) palm(ctx, R, x, 70, between(R, 36, 56), rgba([24, 40, 28])); forestLine(ctx, R, 70, 10, rgba([24, 40, 28])); }
  else { skyline(ctx, R, 66, rgba([40, 40, 60]), { h: 28, lit: 0.2, spires: 0.2 }); }
  // spectators on the banks under umbrellas
  for (let x = 20; x < SW; x += 34) { const c = pick(R, [[230, 60, 60], [240, 200, 40], [40, 120, 200], [30, 30, 30]]); const u = P2(); u.moveTo(x - 10, 64); u.quadraticCurveTo(x, 52, x + 10, 64); u.closePath(); fillPath(ctx, u, rgba(c)); }
  crowd(ctx, R, -10, SW + 10, 70, 9, dark, { hands: 0.3 });
  water(ctx, R, 72, 100, riverC, { n: 70 });
  // the boats: long hulls packed with rowers, a raised stern / dragon head
  const boat = (x0, x1, y, flip) => {
    const p = P2(); p.moveTo(x0, y - 2); p.lineTo(x1, y - 2); p.lineTo(x1 - 6, y + 3); p.lineTo(x0 + 6, y + 3); p.closePath();
    if (style === 'snake') { const sx = flip ? x0 : x1; p.moveTo(sx, y - 2); p.quadraticCurveTo(sx + (flip ? -10 : 10), y - 10, sx + (flip ? -6 : 6), y - 30); p.lineTo(sx + (flip ? -2 : 2), y - 30); p.quadraticCurveTo(sx + (flip ? -4 : 4), y - 10, sx - (flip ? -4 : 4), y - 2); p.closePath(); }
    fillPath(ctx, p, dark);
    if (style === 'dragon') { const hx = flip ? x0 : x1, h = P2(); h.moveTo(hx, y - 2); h.quadraticCurveTo(hx + (flip ? -10 : 10), y - 10, hx + (flip ? -18 : 18), y - 12); h.lineTo(hx + (flip ? -12 : 12), y - 4); h.closePath(); fillPath(ctx, h, rgba([200, 40, 40])); }
    const rw = P2(); for (let x = x0 + 10; x < x1 - 10; x += 6) { rw.moveTo(x + 2.2, y - 6); rw.arc(x, y - 6, 2.2, 0, TAU); rw.moveTo(x - 1.5, y - 4); rw.lineTo(x + 6, y + 6); } fillPath(ctx, rw, dark); strokePath(ctx, rw, dark, 1);
    const splash = []; for (let x = x0 + 10; x < x1 - 10; x += 6) splash.push([x + 7, y + 6, 1.2]); dots(ctx, splash, rgba([255, 255, 255], 0.6));
  };
  boat(380, 620, 84, false); boat(730, 980, 90, true); boat(160, 340, 78, false); boat(1020, 1240, 80, true);
  anchored(ctx, 'L', () => { palm(ctx, R, 40, 340, 280, '#0a120c', { lean: 0.3 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 80, 180, 160, [255, 190, 110], 0.3, true); const p = P2(); personPath(p, SW - 110, 330, 220, { armUp: 2 }); fillPath(ctx, p, '#0a0c0a'); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, rgba(shade(riverC, -0.3))], [1, rgba(shade(riverC, -0.85))]]));
  const rf = P2(); for (let i = 0; i < 60; i++) { const x = between(R, 0, SW), y = between(R, F, SH); rf.moveTo(x, y); rf.lineTo(x + between(R, 10, 40), y); } strokePath(ctx, rf, rgba([255, 220, 160], 0.15), 1);
  finish(ctx, { split: 0.3, vignette: 0.42 });
};
