// Rock music scenes.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

function truss(ctx, x0, y0, x1, y1, t, c) {
  // a box truss seen from the front: two chords and zig-zag webbing
  const p = P2(), horiz = Math.abs(y1 - y0) < Math.abs(x1 - x0);
  if (horiz) { p.rect(x0, y0, x1 - x0, 1.6); p.rect(x0, y0 + t - 1.6, x1 - x0, 1.6); for (let x = x0, k = 0; x < x1; x += t, k++) { p.moveTo(x, y0); p.lineTo(x + t, y0 + t); p.lineTo(x + t - 1.2, y0 + t); p.lineTo(x - 1.2, y0); p.closePath(); } }
  else { p.rect(x0, y0, 1.6, y1 - y0); p.rect(x0 + t - 1.6, y0, 1.6, y1 - y0); for (let y = y0; y < y1; y += t) { p.moveTo(x0, y); p.lineTo(x0 + t, y + t); p.lineTo(x0 + t, y + t + 1.2); p.lineTo(x0, y + 1.2); p.closePath(); } }
  fillPath(ctx, p, c);
}
function speakerStack(ctx, x, top, w, n, o = {}) {
  // line-array boxes hanging in a curve
  for (let i = 0; i < n; i++) {
    const y = top + i * w * 0.34, ang = i * 0.05 * (o.side || 1);
    ctx.save(); ctx.translate(x, y); ctx.rotate(ang);
    const p = P2(); p.moveTo(-w / 2, 0); p.lineTo(w / 2, 0); p.lineTo(w * 0.45, w * 0.3); p.lineTo(-w * 0.45, w * 0.3); p.closePath();
    fillPath(ctx, p, '#0b0b0e'); rect(ctx, -w * 0.4, w * 0.06, w * 0.8, w * 0.18, rgba([40, 40, 46]));
    ctx.restore();
  }
}
function ampStack(ctx, x, base, w, h, o = {}) {
  const cab = (y, hh, cones) => {
    const p = P2(); p.rect(x - w / 2, y - hh, w, hh); fillPath(ctx, p, lin(ctx, x - w / 2, 0, x + w / 2, 0, [[0, '#121216'], [0.5, '#1e1e24'], [1, '#0c0c10']]));
    rect(ctx, x - w / 2 + w * 0.05, y - hh + w * 0.05, w * 0.9, hh - w * 0.1, '#17171c');
    const g = P2(); for (let k = 0; k < 12; k++) { g.moveTo(x - w * 0.45, y - hh + w * 0.05 + k * (hh - w * 0.1) / 12); g.lineTo(x + w * 0.45, y - hh + w * 0.05 + k * (hh - w * 0.1) / 12); } strokePath(ctx, g, rgba([60, 60, 70], 0.5), 0.6, 'butt');
    if (cones) for (const [cx2, cy2] of cones) { circle(ctx, cx2, cy2, w * 0.18, rgba([8, 8, 10], 0.9)); circle(ctx, cx2, cy2, w * 0.06, rgba([40, 40, 46])); }
    rect(ctx, x - w / 2, y - hh, w, Math.max(1, hh * 0.04), rgba([160, 160, 170], 0.4));
  };
  const hh = h / 2;
  cab(base, hh, [[x - w * 0.22, base - hh * 0.3], [x + w * 0.22, base - hh * 0.3], [x - w * 0.22, base - hh * 0.72], [x + w * 0.22, base - hh * 0.72]]);
  cab(base - hh, hh * 0.92, [[x - w * 0.22, base - hh * 1.3], [x + w * 0.22, base - hh * 1.3], [x - w * 0.22, base - hh * 1.66], [x + w * 0.22, base - hh * 1.66]]);
  const head = P2(); head.rect(x - w / 2, base - h - hh * 0.3, w, hh * 0.3); fillPath(ctx, head, '#101014');
  for (let k = 0; k < 5; k++) circle(ctx, x - w * 0.35 + k * w * 0.12, base - h - hh * 0.15, w * 0.025, rgba([200, 190, 160]));
  if (o.light) glow(ctx, x + w * 0.35, base - h - hh * 0.15, 6, o.light, 0.8, true);
}
// Guitarist / bassist silhouette, feet at (x, y).
function guitarist(ctx, x, y, h, c, o = {}) {
  const p = P2(); personPath(p, x, y, h, { armUp: o.armUp || 0 }); fillPath(ctx, p, c);
  const s = h / 100, d = o.flip ? -1 : 1;
  ctx.save(); ctx.translate(x, y - 48 * s); ctx.rotate(d * -0.5); if (o.flip) ctx.scale(-1, 1);
  const g = P2(); g.ellipse(-6 * s, 0, 14 * s, 10 * s, 0, 0, TAU); g.ellipse(6 * s, -2 * s, 10 * s, 8 * s, 0, 0, TAU); g.rect(10 * s, -3.5 * s, 46 * s, 4 * s); g.rect(54 * s, -5 * s, 10 * s, 7 * s);
  fillPath(ctx, g, c);
  ctx.restore();
}

TEMPLATES.desertFestival = (ctx, R, o) => {
  const pink = [255, 60, 150], amber = [255, 160, 60], cyan = [0, 200, 220], dark = '#07060c';
  sky(ctx, ['#04040e', '#0c0a24', '#1e1238', '#3a1a44'], 0, HORIZON);
  ground(ctx, ['#6a3a3a', '#2a1418', '#0c0608']);
  stars(ctx, R, 110, [0, 0, SW, 60], { bright: 4 });
  milkyWay(ctx, R, 80, -20, 560, 70, 28, { c1: [150, 120, 230], c2: [255, 170, 160] });
  // the palace on the hill, lit pink, on the left flank
  ridge(ctx, R, 84, 20, rgba([26, 16, 34]), { freqs: [0.004, 0.012], bottom: 100 });
  const pw = rajputFort(ctx, R, 150, 400, 70, 54, rgba([110, 50, 90]), { towers: 3, merlon: 3 });
  dots(ctx, pw.map(([x, y]) => [x, y, 1.1]), rgba([255, 170, 220], 0.9));
  glow(ctx, 270, 60, 120, [255, 80, 160], 0.25, true);
  // the stage: truss frame, LED wall, beams and lasers
  const sx0 = CX - 230, sx1 = CX + 230, sTop = 6;
  // LED wall: a desert sun rising over dunes, in scan lines
  const lx0 = sx0 + 14, lw = sx1 - sx0 - 28;
  rect(ctx, lx0, sTop + 14, lw, 80, lin(ctx, 0, sTop + 14, 0, 94, [[0, rgba([30, 8, 40])], [0.6, rgba([110, 24, 80])], [1, rgba([200, 60, 90])]]));
  ctx.save(); const lp = P2(); lp.rect(lx0, sTop + 14, lw, 80); ctx.clip(lp);
  glow(ctx, CX, 74, 90, [255, 120, 80], 0.6, true);
  circle(ctx, CX, 74, 34, lin(ctx, 0, 40, 0, 108, [[0, rgba([255, 220, 120])], [1, rgba([255, 60, 120])]]));
  for (let y = 46; y < 100; y += 7) rect(ctx, CX - 40, y, 80, 2.4 + (y - 46) * 0.05, rgba([60, 10, 50], 0.9));
  ridge(ctx, R, 96, 14, rgba([40, 6, 40]), { freqs: [0.02, 0.05], x0: lx0, x1: lx0 + lw, bottom: 100 });
  const grid = P2(); for (let y = sTop + 14; y < 94; y += 3) { grid.moveTo(lx0, y); grid.lineTo(lx0 + lw, y); } strokePath(ctx, grid, rgba([0, 0, 0], 0.22), 1, 'butt');
  ctx.restore();
  for (let i = 0; i < 9; i++) { const x = lerp(sx0 + 30, sx1 - 30, i / 8); beam(ctx, x, sTop + 12, -Math.PI / 2 + (i - 4) * 0.16, 260, 0.1, i % 2 ? pink : cyan, 0.6); }
  additive(ctx, () => { for (let i = 0; i < 7; i++) { const a = -Math.PI / 2 + (i - 3) * 0.22; line(ctx, CX, sTop + 10, CX + Math.cos(a) * 600, sTop + 10 + Math.sin(a) * 600, rgba([80, 255, 120], 0.55), 0.8); } });
  truss(ctx, sx0, sTop, sx1, sTop, 12, '#1a1820');
  truss(ctx, sx0, sTop, sx0 + 12, 100, 12, '#1a1820'); truss(ctx, sx1 - 12, sTop, sx1, 100, 12, '#1a1820');
  for (let i = 0; i < 12; i++) { const x = lerp(sx0 + 20, sx1 - 20, i / 11); glow(ctx, x, sTop + 14, 10, i % 3 ? amber : pink, 0.7, true); circle(ctx, x, sTop + 14, 2.2, rgba([255, 240, 220])); }
  // flags on poles on the flanks
  for (const [x, c] of [[120, pink], [220, amber], [430, cyan], [920, pink], [1080, amber], [1200, cyan]]) { line(ctx, x, 40, x, 92, dark, 1.4); const f = P2(); f.moveTo(x, 40); f.quadraticCurveTo(x + 12, 40, x + 10, 70); f.lineTo(x, 66); f.closePath(); fillPath(ctx, f, rgba(c, 0.85)); }
  // the crowd across the front, phones up
  const ph = [];
  crowd(ctx, R, -10, SW + 10, 86, 15, dark, { hands: 0.3, lights: ph });
  dots(ctx, ph.map(([x, y]) => [x, y, 1.1]), rgba([230, 240, 255], 0.95));
  for (const [x, y] of ph.slice(0, 20)) glow(ctx, x, y, 6, [200, 220, 255], 0.3, true);
  // corners: hanging speaker arrays and smoke
  anchored(ctx, 'L', () => { glow(ctx, 40, 180, 200, pink, 0.25, true); speakerStack(ctx, 100, 50, 90, 8, { side: 1 }); withBlur(ctx, 18, () => oval(ctx, 60, 330, 120, 60, rgba([200, 120, 200], 0.15))); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 40, 180, 200, cyan, 0.25, true); speakerStack(ctx, SW - 100, 50, 90, 8, { side: -1 }); withBlur(ctx, 18, () => oval(ctx, SW - 60, 330, 120, 60, rgba([120, 200, 220], 0.15))); });
  // sand floor with stage light spill
  glow(ctx, CX, F + 10, 500, [230, 60, 140], 0.25, true);
  const cab = P2(); cab.moveTo(0, F + 40); cab.quadraticCurveTo(300, F + 60, 600, F + 38); cab.quadraticCurveTo(900, F + 20, SW, F + 50); strokePath(ctx, cab, rgba([0, 0, 0], 0.5), 3);
  finish(ctx, { split: 0.3, vignette: 0.45 });
};

TEMPLATES.liveHouse = (ctx, R, o) => {
  const pink = o.c1 || [255, 45, 149], cyan = o.c2 || [0, 210, 230], white = [255, 240, 230], dark = '#060508';
  rect(ctx, 0, 0, SW, SH, '#08070c');
  // back wall: black with neon tubes framing the stage
  rect(ctx, CX - 250, 0, 500, 100, lin(ctx, 0, 0, 0, 100, [[0, '#0e0c14'], [1, '#1a1420']]));
  withBlur(ctx, 10, () => oval(ctx, CX, 60, 300, 50, rgba([120, 40, 120], 0.35)));
  for (const [x, c] of [[CX - 236, pink], [CX + 236, cyan]]) { const p = P2(); p.moveTo(x, 4); p.lineTo(x, 92); additive(ctx, () => withBlur(ctx, 5, () => strokePath(ctx, p, rgba(c, 0.9), 6))); strokePath(ctx, p, rgba(mix(c, [255, 255, 255], 0.7)), 1.6); }
  const top = P2(); top.moveTo(CX - 236, 4); top.lineTo(CX + 236, 4); additive(ctx, () => withBlur(ctx, 5, () => strokePath(ctx, top, rgba(pink, 0.8), 5))); strokePath(ctx, top, rgba(mix(pink, [255, 255, 255], 0.7)), 1.4);
  // beams down onto the stage
  for (let i = 0; i < 7; i++) { const x = CX - 210 + i * 70; beam(ctx, x, 6, Math.PI / 2 + (i - 3) * 0.12, 140, 0.32, i % 2 ? cyan : pink, 0.32, { blur: 3 }); }
  beam(ctx, CX, 4, Math.PI / 2, 140, 0.5, white, 0.25, { blur: 4 });
  // drum riser behind the dealer, amps either side, the band
  rect(ctx, CX - 90, 74, 180, 18, '#121016'); rect(ctx, CX - 90, 74, 180, 2, rgba([255, 255, 255], 0.15));
  iconAt(ctx, 'drum-kit', CX, 78, 92, '#0a090e');
  for (const x of [CX - 190, CX + 190]) ampStack(ctx, x, 94, 46, 66, { light: x < CX ? pink : cyan });
  guitarist(ctx, 520, 93, 64, dark, { armUp: 0 });
  guitarist(ctx, 840, 93, 64, dark, { flip: true });
  const mic = P2(); for (const x of [560, 800]) { mic.moveTo(x, 93); mic.lineTo(x, 50); mic.lineTo(x + 8, 46); } strokePath(ctx, mic, dark, 1.2);
  // haze over everything
  withBlur(ctx, 14, () => { for (let i = 0; i < 6; i++) oval(ctx, between(R, 300, 1040), between(R, 30, 80), between(R, 60, 140), 16, rgba(i % 2 ? pink : cyan, 0.07)); });
  // the crowd's front rows with lightsticks
  const ls = [];
  crowd(ctx, R, -10, SW + 10, 88, 14, dark, { hands: 0.35, lights: ls });
  dots(ctx, ls.map(([x, y], i) => [x, y, 1.3]), rgba(pink, 0.95));
  for (const [x, y] of ls.slice(0, 24)) glow(ctx, x, y, 7, R() < 0.5 ? pink : cyan, 0.4, true);
  // corners: big amp stacks
  anchored(ctx, 'L', () => { glow(ctx, 60, 160, 180, pink, 0.25, true); ampStack(ctx, 80, 360, 150, 260, { light: pink }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 160, 180, cyan, 0.25, true); ampStack(ctx, SW - 80, 360, 150, 260, { light: cyan }); });
  // stage floor: cables, wedges, neon reflections
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#141018'], [1, '#050407']]));
  glow(ctx, 200, F + 10, 260, pink, 0.22, true); glow(ctx, SW - 200, F + 10, 260, cyan, 0.22, true);
  const cb = P2(); for (let k = 0; k < 4; k++) { cb.moveTo(between(R, 0, SW), F); cb.bezierCurveTo(between(R, 0, SW), SH, between(R, 0, SW), F + 60, between(R, 0, SW), SH); } strokePath(ctx, cb, rgba([0, 0, 0], 0.7), 2.5);
  finish(ctx, { split: 0.2, vignette: 0.5 });
};
