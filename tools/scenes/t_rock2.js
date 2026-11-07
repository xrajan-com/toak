// Rock, part 2: open-air festivals and stadium shows, configured per kingdom.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

// What the stage screen shows.
function stageScreen(ctx, R, kind, x0, y0, w, h, c1, c2) {
  rect(ctx, x0, y0, w, h, lin(ctx, 0, y0, 0, y0 + h, [[0, rgba(shade(c1, -0.7))], [0.7, rgba(shade(c1, -0.2))], [1, rgba(c2)]]));
  ctx.save(); const cl = P2(); cl.rect(x0, y0, w, h); ctx.clip(cl);
  const cx = x0 + w / 2, cy = y0 + h * 0.75;
  if (kind === 'sun') { glow(ctx, cx, cy, h, c2, 0.6, true); circle(ctx, cx, cy, h * 0.42, lin(ctx, 0, cy - h * 0.42, 0, cy + h * 0.42, [[0, rgba(shade(c2, 0.5))], [1, rgba(c1)]])); for (let y = cy - h * 0.3; y < y0 + h; y += 7) rect(ctx, cx - h * 0.5, y, h, 2.4 + (y - cy) * 0.05, rgba(shade(c1, -0.7), 0.9)); }
  else if (kind === 'rings') { additive(ctx, () => { for (let r = 8; r < w; r += 14) { const p = P2(); p.ellipse(cx, cy - h * 0.2, r, r * 0.55, 0, 0, TAU); strokePath(ctx, p, rgba(r % 28 ? c1 : c2, 0.45), 3); } }); }
  else if (kind === 'eq') { const p = P2(); for (let x = x0 + 4; x < x0 + w - 4; x += 8) { const bh = h * (0.15 + 0.75 * Math.abs(Math.sin(x * 0.05) * Math.sin(x * 0.013 + 1))); p.rect(x, y0 + h - bh, 5, bh); } fillPath(ctx, p, lin(ctx, 0, y0, 0, y0 + h, [[0, rgba(c2)], [1, rgba(c1)]])); }
  else if (kind === 'flag') { const cs = o_flagCols; const bw = h / cs.length; cs.forEach((c, i) => rect(ctx, x0, y0 + i * bw, w, bw + 0.5, rgba(c, 0.85))); }
  else if (kind === 'eye') { glow(ctx, cx, y0 + h / 2, h, c2, 0.5, true); const e = P2(); e.moveTo(cx - h * 0.9, y0 + h / 2); e.quadraticCurveTo(cx, y0 - h * 0.1, cx + h * 0.9, y0 + h / 2); e.quadraticCurveTo(cx, y0 + h * 1.1, cx - h * 0.9, y0 + h / 2); fillPath(ctx, e, rgba(shade(c2, 0.4), 0.8)); circle(ctx, cx, y0 + h / 2, h * 0.24, rgba(shade(c1, -0.6))); }
  const grid = P2(); for (let y = y0; y < y0 + h; y += 3) { grid.moveTo(x0, y); grid.lineTo(x0 + w, y); } strokePath(ctx, grid, rgba([0, 0, 0], 0.22), 1, 'butt');
  ctx.restore();
}
var o_flagCols = [[255, 255, 255]];

// Open-air festival. o: { sky, c1, c2, screen, backdrop: 'palace'|'city'|'hills'|'beach'|'ruins'|'pines'|'desert'|'fortress'|'eiffel'|'baobab',
//   flags: [colours], crowd: 'phones'|'horns'|'sticks'|'flags', rain, fire, wheel, palms, extra(ctx,R) }
TEMPLATES.festival = (ctx, R, o) => {
  const c1 = o.c1 || [255, 60, 150], c2 = o.c2 || [255, 160, 60], beamC = o.beam || [0, 200, 220], dark = '#07060c';
  skyPreset(ctx, o.sky || 'warmNight');
  ground(ctx, o.ground || ['#4a2a3a', '#1a1018', '#08060a']);
  stars(ctx, R, o.rain ? 0 : 100, [0, 0, SW, 60], { bright: 3 });
  const bd = o.backdrop || 'hills';
  if (bd === 'palace' || bd === 'fortress') { ridge(ctx, R, 84, 18, rgba([26, 16, 34]), { freqs: [0.004, 0.012], bottom: 100 }); const w = indianFortCrest(ctx, R, bd === 'palace' ? 'rajput' : 'sikh', 120, 420, 70, 50, rgba(o.backdropC || [110, 50, 90]), [255, 140, 30]); dots(ctx, w.map(([x, y]) => [x, y, 1]), rgba([255, 190, 220], 0.9)); glow(ctx, 270, 60, 120, c1, 0.2, true); }
  if (o.aurora) aurora(ctx, R, 14, [[60, 255, 160], [80, 200, 255], [200, 80, 255]], { bands: 4 });
  if (bd === 'city') skyline(ctx, R, 84, rgba([18, 16, 30]), { h: 34, lit: 0.3 });
  if (bd === 'arena') { const a = P2(); a.moveTo(-20, 92); a.lineTo(-20, 40); a.quadraticCurveTo(CX, 20, SW + 20, 40); a.lineTo(SW + 20, 92); a.closePath(); const holes = []; for (const [y, h] of [[44, 14], [64, 14]]) for (let x = 0; x < SW; x += 26) holes.push([x, y, h]); ctx.fillStyle = rgba(o.backdropC || [120, 90, 80]); ctx.fill(a); const ho = P2(); for (const [x, y, h] of holes) { ho.moveTo(x + 4, y + h); ho.lineTo(x + 4, y + 5); ho.quadraticCurveTo(x + 12, y - 2, x + 20, y + 5); ho.lineTo(x + 20, y + h); ho.closePath(); } fillPath(ctx, ho, rgba([20, 12, 16])); glow(ctx, CX, 60, 600, [255, 150, 80], 0.15, true); }
  if (bd === 'windmills') { for (const [x, h] of [[180, 60], [300, 48], [1040, 56], [1180, 44]]) windmill(ctx, x, 86, h, rgba([20, 18, 28]), x * 0.01); }
  if (bd === 'hills') mountains(ctx, R, 84, 26, [20, 18, 32], { freqs: [0.004, 0.011] });
  if (bd === 'pines') { mountains(ctx, R, 82, 30, [24, 30, 40]); forestLine(ctx, R, 88, 20, rgba([10, 16, 18]), { pines: true }); }
  if (bd === 'beach') { water(ctx, R, 70, 92, [20, 40, 70], { n: 40 }); moon(ctx, 1000, 24, 9, { halo: 6 }); reflection(ctx, R, 1000, 71, 90, [220, 230, 255], 26, 0.35); }
  if (bd === 'desert') { ridge(ctx, R, 86, 12, rgba([40, 24, 34]), { freqs: [0.004, 0.01], bottom: 100 }); }
  if (bd === 'ruins') { ridge(ctx, R, 86, 14, rgba([24, 18, 30]), { bottom: 100 }); const r = P2(); r.rect(160, 44, 220, 34); for (let x = 170; x < 370; x += 24) { r.moveTo(x, 78); r.lineTo(x, 58); r.quadraticCurveTo(x + 8, 48, x + 16, 58); r.lineTo(x + 16, 78); } ctx.fillStyle = rgba(o.backdropC || [90, 60, 80]); ctx.fill(r, 'evenodd'); glow(ctx, 270, 60, 120, [255, 150, 80], 0.25, true); }
  if (bd === 'eiffel') { skyline(ctx, R, 84, rgba([20, 18, 30]), { h: 16, lit: 0.3 }); eiffel(ctx, 1060, 86, 80, rgba([24, 20, 30]), { lights: [255, 200, 120] }); }
  if (bd === 'baobab') { for (const x of [180, 330, 1040, 1190]) { const t = P2(); t.moveTo(x - 9, 88); t.quadraticCurveTo(x - 7, 60, x - 4, 46); t.lineTo(x + 4, 46); t.quadraticCurveTo(x + 7, 60, x + 9, 88); t.closePath(); for (let k = -3; k <= 3; k++) { t.moveTo(x, 48); t.lineTo(x + k * 8, 36 - Math.abs(k) * 1.5); t.lineTo(x + k * 8 + 1.5, 37 - Math.abs(k) * 1.5); t.lineTo(x + 1.5, 49); } fillPath(ctx, t, rgba([20, 14, 20])); } }
  // the stage
  const sx0 = CX - 230, sx1 = CX + 230, sTop = 6;
  o_flagCols = o.flagCols || [[255, 255, 255]];
  stageScreen(ctx, R, o.screen || 'sun', sx0 + 14, sTop + 14, sx1 - sx0 - 28, 80, c1, c2);
  for (let i = 0; i < 9; i++) { const x = lerp(sx0 + 30, sx1 - 30, i / 8); beam(ctx, x, sTop + 12, -Math.PI / 2 + (i - 4) * 0.16, 260, 0.1, i % 2 ? c1 : beamC, 0.55); }
  if (o.lasers !== false) additive(ctx, () => { for (let i = 0; i < 7; i++) { const a = -Math.PI / 2 + (i - 3) * 0.22; line(ctx, CX, sTop + 10, CX + Math.cos(a) * 600, sTop + 10 + Math.sin(a) * 600, rgba(o.laser || [80, 255, 120], 0.5), 0.8); } });
  truss(ctx, sx0, sTop, sx1, sTop, 12, '#1a1820'); truss(ctx, sx0, sTop, sx0 + 12, 100, 12, '#1a1820'); truss(ctx, sx1 - 12, sTop, sx1, 100, 12, '#1a1820');
  for (let i = 0; i < 12; i++) { const x = lerp(sx0 + 20, sx1 - 20, i / 11); glow(ctx, x, sTop + 14, 10, i % 3 ? c2 : c1, 0.7, true); circle(ctx, x, sTop + 14, 2.2, rgba([255, 240, 220])); }
  if (o.fire) for (const x of [sx0 + 40, sx1 - 40]) { glow(ctx, x, 60, 50, [255, 140, 40], 0.6, true); const f = P2(); f.moveTo(x - 8, 92); f.quadraticCurveTo(x - 12, 60, x, 34); f.quadraticCurveTo(x + 12, 60, x + 8, 92); f.closePath(); additive(ctx, () => fillPath(ctx, f, lin(ctx, 0, 34, 0, 92, [[0, rgba([255, 240, 160], 0.2)], [1, rgba([255, 120, 30], 0.8)]]))); }
  if (o.wheel) { const wx = o.wheel, wy = 46, wr = 38; const wp = P2(); wp.ellipse(wx, wy, wr, wr, 0, 0, TAU); for (let k = 0; k < 12; k++) { const a = k * TAU / 12; wp.moveTo(wx, wy); wp.lineTo(wx + Math.cos(a) * wr, wy + Math.sin(a) * wr); } strokePath(ctx, wp, rgba([20, 18, 26]), 1.4); const lt = []; for (let k = 0; k < 36; k++) { const a = k * TAU / 36; lt.push([wx + Math.cos(a) * wr, wy + Math.sin(a) * wr, 1.2]); } dots(ctx, lt, rgba([255, 220, 140], 0.9)); line(ctx, wx - 20, 92, wx, wy, '#14121a', 2); line(ctx, wx + 20, 92, wx, wy, '#14121a', 2); }
  if (o.palms) for (const x of [140, 260, 1090, 1220]) palm(ctx, R, x, 88, between(R, 50, 66), rgba([10, 8, 14]));
  for (const [x, i] of [[120, 0], [220, 1], [430, 2], [920, 0], [1080, 1], [1200, 2]]) { const cs = o.flags || [c1, c2, beamC]; line(ctx, x, 40, x, 92, dark, 1.4); const f = P2(); f.moveTo(x, 40); f.quadraticCurveTo(x + 12, 40, x + 10, 70); f.lineTo(x, 66); f.closePath(); fillPath(ctx, f, rgba(cs[i % cs.length], 0.85)); }
  if (o.extra) o.extra(ctx, R);
  // the crowd
  const lights = [];
  crowd(ctx, R, -10, SW + 10, 86, 15, dark, { hands: o.crowd === 'horns' ? 0.45 : 0.3, lights });
  const lc = o.crowd === 'sticks' ? (o.stickC || c1) : [230, 240, 255];
  if (o.crowd !== 'horns') { dots(ctx, lights.map(([x, y]) => [x, y, 1.1]), rgba(lc, 0.95)); for (const [x, y] of lights.slice(0, 20)) glow(ctx, x, y, 6, lc, 0.3, true); }
  if (o.rain) { const rn = P2(); for (let i = 0; i < 300; i++) { const x = between(R, 0, SW), y = between(R, 0, SH); rn.moveTo(x, y); rn.lineTo(x - 2, y + 9); } strokePath(ctx, rn, rgba([200, 210, 230], 0.25), 0.7); }
  anchored(ctx, 'L', () => { glow(ctx, 40, 180, 200, c1, 0.25, true); speakerStack(ctx, 100, 50, 90, 8, { side: 1 }); withBlur(ctx, 18, () => oval(ctx, 60, 330, 120, 60, rgba(c1, 0.12))); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 40, 180, 200, beamC, 0.25, true); speakerStack(ctx, SW - 100, 50, 90, 8, { side: -1 }); withBlur(ctx, 18, () => oval(ctx, SW - 60, 330, 120, 60, rgba(beamC, 0.12))); });
  glow(ctx, CX, F + 10, 500, c1, 0.22, true);
  const cab = P2(); cab.moveTo(0, F + 40); cab.quadraticCurveTo(300, F + 60, 600, F + 38); cab.quadraticCurveTo(900, F + 20, SW, F + 50); strokePath(ctx, cab, rgba([0, 0, 0], 0.5), 3);
  finish(ctx, { split: 0.3, vignette: 0.45 });
};

// Stadium show: tiers of seats, a wide stage with a roof of lights.
// o: { c1, c2, screen, crowd, pyro, fireworks, confetti }
TEMPLATES.stadiumRock = (ctx, R, o) => {
  const c1 = o.c1 || [255, 40, 60], c2 = o.c2 || [255, 200, 80], beamC = o.beam || [120, 160, 255], dark = '#060508';
  rect(ctx, 0, 0, SW, SH, '#05050a');
  // stadium bowl: tiers with tiny lights
  for (let row = 0; row < 8; row++) { const y = 70 - row * 9; rect(ctx, -20, y - 9, SW + 40, 9, rgba(mix([30, 26, 40], [10, 10, 16], row / 8))); const l = []; for (let x = -10; x < SW + 10; x += between(R, 4, 9)) if (R() < 0.5) l.push([x, y - 5 + between(R, -2, 2), 0.8]); dots(ctx, l, rgba(R() < 0.5 ? [255, 255, 255] : c2, 0.55)); }
  // the roof of lights and the screens
  const sx0 = CX - 300, sx1 = CX + 300;
  o_flagCols = o.flagCols || [[255, 255, 255]];
  stageScreen(ctx, R, o.screen || 'eye', CX - 150, 16, 300, 70, c1, c2);
  for (const x of [sx0 + 30, sx1 - 110]) stageScreen(ctx, R, 'eq', x, 24, 80, 50, c1, c2);
  for (let i = 0; i < 12; i++) { const x = lerp(sx0, sx1, i / 11); beam(ctx, x, 10, -Math.PI / 2 + (i - 5.5) * 0.12, 300, 0.07, i % 2 ? c1 : beamC, 0.5); }
  truss(ctx, sx0 - 10, 4, sx1 + 10, 4, 12, '#16141c');
  for (let i = 0; i < 16; i++) { const x = lerp(sx0, sx1, i / 15); glow(ctx, x, 16, 9, i % 2 ? c1 : c2, 0.7, true); circle(ctx, x, 16, 2, rgba([255, 245, 230])); }
  if (o.pyro) for (const x of [sx0 + 20, sx1 - 20, CX - 180, CX + 180]) { glow(ctx, x, 70, 50, [255, 140, 40], 0.55, true); const f = P2(); f.moveTo(x - 7, 92); f.quadraticCurveTo(x - 11, 64, x, 40); f.quadraticCurveTo(x + 11, 64, x + 7, 92); f.closePath(); additive(ctx, () => fillPath(ctx, f, lin(ctx, 0, 40, 0, 92, [[0, rgba([255, 240, 160], 0.2)], [1, rgba([255, 120, 30], 0.85)]]))); }
  if (o.fireworks) { firework(ctx, R, 300, 20, 40, c2); firework(ctx, R, 1040, 16, 44, c1); }
  if (o.confetti) { const cf = [[], [], []]; for (let i = 0; i < 260; i++) cf[i % 3].push([between(R, 0, SW), between(R, 0, 120), between(R, 0.8, 1.6)]); [c1, c2, [255, 255, 255]].forEach((c, i) => dots(ctx, cf[i], rgba(c, 0.85))); }
  const lights = [];
  crowd(ctx, R, -10, SW + 10, 86, 15, dark, { hands: o.crowd === 'horns' ? 0.5 : 0.35, lights });
  const lc = o.crowd === 'sticks' ? (o.stickC || c1) : [230, 240, 255];
  if (o.crowd !== 'horns') { dots(ctx, lights.map(([x, y]) => [x, y, 1.2]), rgba(lc, 0.95)); for (const [x, y] of lights.slice(0, 24)) glow(ctx, x, y, 6, lc, 0.35, true); }
  else { const hn = P2(); for (const [x, y] of lights) { hn.moveTo(x - 1.6, y + 2); hn.lineTo(x - 1.2, y - 3); hn.moveTo(x + 1.6, y + 2); hn.lineTo(x + 1.2, y - 3); } strokePath(ctx, hn, dark, 1); }
  anchored(ctx, 'L', () => { glow(ctx, 60, 160, 200, c1, 0.25, true); speakerStack(ctx, 90, 30, 100, 9, { side: 1 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 160, 200, beamC, 0.25, true); speakerStack(ctx, SW - 90, 30, 100, 9, { side: -1 }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#121018'], [1, '#040306']]));
  glow(ctx, 220, F + 10, 260, c1, 0.2, true); glow(ctx, SW - 220, F + 10, 260, beamC, 0.2, true);
  finish(ctx, { split: 0.2, vignette: 0.5 });
};
