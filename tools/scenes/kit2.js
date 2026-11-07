// More shared parts: sky presets, landforms, landmarks, boats, animals,
// water and floors. Same conventions as kit.js (design units, B = 91).

const SKIES = {
  dusk: ['#120c2a', '#3a1c4c', '#9a3a52', '#e8743a', '#f8b25a'],
  pinkDusk: ['#141634', '#3a2c5c', '#9a4e78', '#e88a8a', '#f8c49a'],
  golden: ['#2a2a4a', '#6a4a6a', '#d47a5a', '#f6b870', '#ffdc96'],
  night: ['#03061a', '#0a1236', '#18245a', '#2c3a72'],
  deepNight: ['#020410', '#060a22', '#0e1434', '#1a1a40'],
  warmNight: ['#04040e', '#0c0a24', '#24143a', '#4a2240'],
  dawn: ['#1a2448', '#4a5a8a', '#c88aa0', '#f6c8a8', '#fde6c8'],
  blueHour: ['#0a1430', '#1c2c5a', '#3c4c86', '#7a7aa8', '#c49aa0'],
  storm: ['#0c0e16', '#1c2230', '#343c4c', '#5a6070', '#8a8a90'],
  midnightSun: ['#2a3a6a', '#5a6a9a', '#c8a0a8', '#f6c890', '#ffe0a0'],
  day: ['#2c5a8c', '#4a7eb0', '#86aed0', '#c8d8e0', '#f0dcc0'],
  arctic: ['#04101e', '#0a2036', '#123a50', '#1e4a60'],
};
function skyPreset(ctx, name, y1 = HORIZON) { sky(ctx, SKIES[name] || name, 0, y1); }

// ---------- landforms ----------
function mountains(ctx, R, base, amp, c, o = {}) {
  const f = ridgeFn(R, amp, o.freqs || [0.005, 0.013, 0.031]);
  ridge(ctx, R, base, amp, typeof c === 'string' && c[0] !== '#' ? c : (Array.isArray(c) ? rgba(c) : c), { fn: f, bottom: o.bottom ?? base + 30, x0: o.x0, x1: o.x1, env: o.env });
  if (o.snow) {
    const p = P2(), x0 = o.x0 ?? -20, x1 = o.x1 ?? SW + 20;
    for (let x = x0; x <= x1; x += 6) { const top = base - f(x) * (o.env ? o.env(x) : 1); if (base - top > amp * (o.snowLine ?? 0.62)) { p.moveTo(x - 3, top + 1); p.lineTo(x + 3, top + 1); p.lineTo(x + 3, top + (base - top) * 0.22 + ((x * 7) % 5)); p.lineTo(x - 3, top + (base - top) * 0.22 + ((x * 13) % 5)); p.closePath(); } }
    fillPath(ctx, p, rgba(o.snow, 0.9));
  }
  return f;
}
function karst(ctx, R, base, n, c, o = {}) {
  const p = P2(); p.moveTo(-20, base + 30);
  let x = -20;
  while (x < SW + 20) { const w = between(R, 40, 90) * (o.scale || 1), h = between(R, 26, 70) * (o.scale || 1); p.lineTo(x, base - h * 0.2); p.bezierCurveTo(x + w * 0.05, base - h * 1.1, x + w * 0.95, base - h * 1.1, x + w, base - h * 0.15); x += w * between(R, 0.75, 1); }
  p.lineTo(SW + 20, base + 30); p.closePath(); fillPath(ctx, p, c);
}
function mesas(ctx, R, base, c) {
  const p = P2(); p.moveTo(-20, base + 30); let x = -20;
  while (x < SW + 20) { const gap = between(R, 30, 140), w = between(R, 30, 120), h = between(R, 18, 50); p.lineTo(x + gap, base); p.lineTo(x + gap + w * 0.12, base - h); p.lineTo(x + gap + w * 0.88, base - h); p.lineTo(x + gap + w, base); x += gap + w; }
  p.lineTo(SW + 20, base + 30); p.closePath(); fillPath(ctx, p, c);
}
function forestLine(ctx, R, base, h, c, o = {}) {
  const p = P2(); p.moveTo(-20, base + 20);
  for (let x = -20; x < SW + 20; x += between(R, 5, 10)) {
    const th = h * between(R, 0.6, 1.1);
    if (o.pines) { p.lineTo(x, base - th * 0.2); p.lineTo(x + 3, base - th); p.lineTo(x + 6, base - th * 0.2); }
    else { p.quadraticCurveTo(x + 4, base - th * 1.2, x + 9, base - th * 0.5); }
  }
  p.lineTo(SW + 20, base + 20); p.closePath(); fillPath(ctx, p, c);
}
function skyline(ctx, R, base, c, o = {}) {
  const p = P2(), wins = []; p.moveTo(-20, base + 20); let x = -20;
  const hmax = o.h || 40;
  while (x < SW + 20) {
    const w = between(R, 10, 30), h = between(R, 0.25, 1) * hmax * (o.env ? o.env(x) : 1);
    p.lineTo(x, base - h); if (R() < (o.spires ?? 0.1)) { p.lineTo(x + w * 0.45, base - h); p.lineTo(x + w * 0.5, base - h - hmax * 0.35); p.lineTo(x + w * 0.55, base - h); }
    p.lineTo(x + w, base - h);
    for (let wy = base - h + 3; wy < base - 2; wy += 4) for (let wx = x + 2; wx < x + w - 2; wx += 3.5) if (R() < (o.lit ?? 0.35)) wins.push([wx, wy, 0.7]);
    x += w + (R() < 0.3 ? between(R, 1, 6) : 0);
  }
  p.lineTo(SW + 20, base + 20); p.closePath(); fillPath(ctx, p, c);
  if (o.windows !== false) dots(ctx, wins, rgba(o.winColor || [255, 210, 140], o.winA ?? 0.75));
}
function water(ctx, R, y0, y1, c, o = {}) {
  rect(ctx, 0, y0, SW, y1 - y0, lin(ctx, 0, y0, 0, y1, [[0, rgba(shade(c, 0.1))], [1, rgba(shade(c, -0.55))]]));
  const p = P2(); for (let i = 0; i < (o.n || 60); i++) { const x = between(R, 0, SW), y = between(R, y0 + 1, y1); p.moveTo(x, y); p.lineTo(x + between(R, 6, 26), y); }
  strokePath(ctx, p, rgba(o.glint || [255, 255, 255], o.glintA ?? 0.18), 0.8);
}
// a column of reflected light on water under a light source at x
function reflection(ctx, R, x, y0, y1, c, w = 30, a = 0.5) { const p = P2(); for (let y = y0; y < y1; y += 2.2) { const ww = w * between(R, 0.3, 1) * (0.4 + (y - y0) / (y1 - y0)); p.moveTo(x - ww / 2, y); p.lineTo(x + ww / 2, y); } additive(ctx, () => strokePath(ctx, p, rgba(c, a), 1)); }
function clouds(ctx, R, y, n, c, o = {}) { withBlur(ctx, o.blur ?? 6, () => { for (let i = 0; i < n; i++) oval(ctx, between(R, -50, SW + 50), y + between(R, -8, 8), between(R, 40, 120), between(R, 5, 12), rgba(c, o.a ?? 0.35)); }); }
function aurora(ctx, R, y, cols, o = {}) {
  additive(ctx, () => { for (let k = 0; k < (o.bands || 4); k++) { const c = cols[k % cols.length], p = P2(), yy = y + k * 6; p.moveTo(-20, yy + 30); for (let x = -20; x <= SW + 20; x += 20) p.lineTo(x, yy + Math.sin(x * 0.006 + k) * 14 + Math.sin(x * 0.017 + k * 2) * 6); p.lineTo(SW + 20, yy + 30); p.closePath(); withBlur(ctx, 8, () => fillPath(ctx, p, lin(ctx, 0, yy - 30, 0, yy + 30, [[0, rgba(c, 0)], [0.6, rgba(c, 0.35)], [1, rgba(c, 0)]]))); }
    const rays = P2(); for (let x = 0; x < SW; x += between(R, 4, 12)) { const yy = y + Math.sin(x * 0.006) * 14; rays.moveTo(x, yy - between(R, 10, 40)); rays.lineTo(x, yy + 10); } strokePath(ctx, rays, rgba(cols[0], 0.12), 2, 'butt'); });
}
function shootingStar(ctx, x, y, len, a = 0.6) { additive(ctx, () => strokePath(ctx, (() => { const p = P2(); p.moveTo(x, y); p.lineTo(x - len, y - len * 0.35); return p; })(), lin(ctx, x, y, x - len, y - len * 0.35, [[0, rgba([255, 255, 255], a)], [1, rgba([255, 255, 255], 0)]]), 1.2)); }

// ---------- boats ----------
function dhow(ctx, x, base, s, c, o = {}) {
  const d = o.flip ? -1 : 1, p = P2();
  p.moveTo(x - d * s * 0.6, base - s * 0.12); p.quadraticCurveTo(x, base + s * 0.06, x + d * s * 0.55, base - s * 0.2); p.lineTo(x + d * s * 0.42, base - s * 0.05); p.quadraticCurveTo(x, base + s * 0.08, x - d * s * 0.5, base - s * 0.02); p.closePath();
  p.rect(x - 0.6, base - s * 0.95, 1.2, s * 0.9);
  fillPath(ctx, p, c);
  const sail = P2(); sail.moveTo(x - d * s * 0.05, base - s * 0.95); sail.quadraticCurveTo(x + d * s * 0.5, base - s * 0.55, x + d * s * 0.42, base - s * 0.14); sail.lineTo(x - d * s * 0.42, base - s * 0.18); sail.closePath();
  fillPath(ctx, sail, o.sail ? rgba(o.sail) : c);
}
function felucca(ctx, x, base, s, c, o = {}) { dhow(ctx, x, base, s, c, o); }
function junk(ctx, x, base, s, c, o = {}) {
  const d = o.flip ? -1 : 1, p = P2();
  p.moveTo(x - d * s * 0.6, base - s * 0.22); p.quadraticCurveTo(x, base + s * 0.04, x + d * s * 0.6, base - s * 0.26); p.lineTo(x + d * s * 0.45, base - s * 0.04); p.lineTo(x - d * s * 0.45, base - s * 0.04); p.closePath();
  fillPath(ctx, p, c);
  for (const [mx, h, w] of [[-0.25, 0.9, 0.34], [0.12, 1.05, 0.4]]) {
    const sx = x + d * s * mx, sp = P2(); sp.moveTo(sx, base - s * 0.2); sp.lineTo(sx, base - s * h); sp.lineTo(sx + d * s * w, base - s * (h - 0.05)); sp.lineTo(sx + d * s * w * 0.95, base - s * 0.24); sp.closePath();
    fillPath(ctx, sp, o.sail ? rgba(o.sail) : c);
    const ribs = P2(); for (let k = 1; k < 6; k++) { const yy = base - s * (0.22 + (h - 0.22) * k / 6); ribs.moveTo(sx, yy); ribs.lineTo(sx + d * s * w, yy - s * 0.02); } strokePath(ctx, ribs, rgba([0, 0, 0], 0.35), 0.6, 'butt');
  }
}
function gondola(ctx, x, base, s, c) { const p = P2(); p.moveTo(x - s, base - s * 0.25); p.quadraticCurveTo(x, base + s * 0.08, x + s, base - s * 0.32); p.lineTo(x + s * 0.92, base - s * 0.16); p.quadraticCurveTo(x, base + s * 0.12, x - s * 0.9, base - s * 0.1); p.closePath(); fillPath(ctx, p, c); const g = P2(); personPath(g, x + s * 0.6, base - s * 0.1, s * 0.75); fillPath(ctx, g, c); line(ctx, x + s * 0.68, base - s * 0.6, x + s * 0.3, base + s * 0.1, c, 1); }
function canoe(ctx, x, base, s, c, o = {}) { const p = P2(); p.moveTo(x - s, base - s * 0.12); p.quadraticCurveTo(x, base + s * 0.08, x + s, base - s * 0.14); p.lineTo(x + s * 0.9, base - s * 0.02); p.lineTo(x - s * 0.9, base - s * 0.02); p.closePath(); fillPath(ctx, p, c); for (let k = 0; k < (o.crew || 0); k++) { const q = P2(); personPath(q, x - s * 0.7 + k * s * 1.4 / Math.max(1, o.crew - 1), base - s * 0.04, s * 0.32); fillPath(ctx, q, c); } }
function sailboat(ctx, x, base, s, c, o = {}) { const p = P2(); p.moveTo(x - s * 0.5, base - s * 0.1); p.lineTo(x + s * 0.55, base - s * 0.1); p.lineTo(x + s * 0.4, base); p.lineTo(x - s * 0.4, base); p.closePath(); p.rect(x - 0.5, base - s * 1.2, 1, s * 1.1); fillPath(ctx, p, c); const sl = P2(); sl.moveTo(x + 1, base - s * 1.18); sl.lineTo(x + s * 0.5, base - s * 0.16); sl.lineTo(x + 1, base - s * 0.16); sl.closePath(); sl.moveTo(x - 1, base - s * 1.05); sl.lineTo(x - s * 0.35, base - s * 0.16); sl.lineTo(x - 1, base - s * 0.16); sl.closePath(); fillPath(ctx, sl, o.sail ? rgba(o.sail) : c); }

// ---------- landmarks ----------
function lighthouse(ctx, x, base, h, c, o = {}) {
  const p = P2(); p.moveTo(x - h * 0.09, base); p.lineTo(x - h * 0.055, base - h * 0.82); p.lineTo(x + h * 0.055, base - h * 0.82); p.lineTo(x + h * 0.09, base); p.closePath(); p.rect(x - h * 0.08, base - h * 0.86, h * 0.16, h * 0.04); p.moveTo(x - h * 0.05, base - h * 0.95); p.quadraticCurveTo(x, base - h * 1.06, x + h * 0.05, base - h * 0.95); p.closePath(); fillPath(ctx, p, c);
  if (o.stripes) { const s = P2(); for (let k = 0; k < 4; k++) { const y0 = base - h * (0.12 + k * 0.2), y1 = y0 - h * 0.1; s.moveTo(x - h * 0.085 + (base - y0) / h * 0.035 * h, y0); s.lineTo(x + h * 0.085 - (base - y0) / h * 0.035 * h, y0); s.lineTo(x + h * 0.085 - (base - y1) / h * 0.035 * h, y1); s.lineTo(x - h * 0.085 + (base - y1) / h * 0.035 * h, y1); s.closePath(); } fillPath(ctx, s, rgba(o.stripes)); }
  glow(ctx, x, base - h * 0.9, h * 0.6, [255, 230, 160], 0.6, true); rect(ctx, x - h * 0.04, base - h * 0.94, h * 0.08, h * 0.07, rgba([255, 240, 190]));
  if (o.beam !== false) beam(ctx, x, base - h * 0.9, o.beamAngle ?? -0.12, h * 6, 0.12, [255, 230, 170], 0.3);
}
function windmill(ctx, x, base, h, c, rot = 0.3) {
  const p = P2(); p.moveTo(x - h * 0.16, base); p.lineTo(x - h * 0.1, base - h * 0.62); p.lineTo(x + h * 0.1, base - h * 0.62); p.lineTo(x + h * 0.16, base); p.closePath(); p.moveTo(x - h * 0.12, base - h * 0.6); p.quadraticCurveTo(x, base - h * 0.8, x + h * 0.12, base - h * 0.6); p.closePath(); fillPath(ctx, p, c);
  ctx.save(); ctx.translate(x, base - h * 0.68); ctx.rotate(rot);
  const s = P2(); for (let k = 0; k < 4; k++) { const a = k * Math.PI / 2, cx = Math.cos(a), sy = Math.sin(a); s.moveTo(0, 0); s.lineTo(cx * h * 0.5 - sy * h * 0.02, sy * h * 0.5 + cx * h * 0.02); s.lineTo(cx * h * 0.5 + sy * h * 0.06, sy * h * 0.5 - cx * h * 0.06); s.lineTo(cx * h * 0.12 + sy * h * 0.06, sy * h * 0.12 - cx * h * 0.06); s.closePath(); }
  fillPath(ctx, s, c); ctx.restore();
}
function suspensionBridge(ctx, x0, x1, deck, towerH, c, o = {}) {
  const t1 = x0 + (x1 - x0) * 0.22, t2 = x0 + (x1 - x0) * 0.78, w = o.towerW || 6;
  const p = P2(); p.rect(x0, deck, x1 - x0, 3);
  for (const t of [t1, t2]) { p.rect(t - w / 2, deck - towerH, w * 0.35, towerH + 8); p.rect(t + w / 2 - w * 0.35, deck - towerH, w * 0.35, towerH + 8); p.rect(t - w / 2, deck - towerH * 0.6, w, 1.5); p.rect(t - w / 2, deck - towerH * 0.95, w, 2); }
  fillPath(ctx, p, c);
  const cab = P2(); cab.moveTo(x0, deck - 4); cab.quadraticCurveTo((x0 + t1) / 2, deck - towerH * 0.3, t1, deck - towerH); cab.quadraticCurveTo((t1 + t2) / 2, deck + towerH * 0.1, t2, deck - towerH); cab.quadraticCurveTo((t2 + x1) / 2, deck - towerH * 0.3, x1, deck - 4);
  strokePath(ctx, cab, c, 1.2);
  if (o.lights) { const l = []; for (let t = 0; t <= 1; t += 0.03) { const xx = t1 + (t2 - t1) * t; l.push([xx, deck - towerH + (towerH * 1.1) * 4 * t * (1 - t), 0.9]); } dots(ctx, l, rgba(o.lights, 0.9)); }
}
function archBridge(ctx, x0, x1, deck, h, c, o = {}) {
  const p = P2(); p.rect(x0, deck, x1 - x0, 3); fillPath(ctx, p, c);
  const a = P2(); a.moveTo(x0 + (x1 - x0) * 0.1, deck + 8); a.quadraticCurveTo((x0 + x1) / 2, deck - h * 2, x0 + (x1 - x0) * 0.9, deck + 8); strokePath(ctx, a, c, 4);
  const hang = P2(); for (let t = 0.15; t < 0.86; t += 0.05) { const xx = x0 + (x1 - x0) * t, u = (t - 0.1) / 0.8; hang.moveTo(xx, deck); hang.lineTo(xx, deck + 8 - (h * 2 + 8) * 2 * u * (1 - u) * 1); } strokePath(ctx, hang, c, 0.8);
  for (const px of [x0 + (x1 - x0) * 0.08, x0 + (x1 - x0) * 0.92]) rect(ctx, px - 5, deck - 14, 10, 18, c);
}
function stoneArches(ctx, x0, x1, deck, n, c, o = {}) {
  const p = P2(), w = (x1 - x0) / n; p.rect(x0, deck - 6, x1 - x0, 6);
  for (let i = 0; i < n; i++) { const ax = x0 + i * w; p.moveTo(ax, deck); p.lineTo(ax, deck + 14); p.lineTo(ax + w * 0.12, deck + 14); p.quadraticCurveTo(ax + w / 2, deck - (o.rise || 4), ax + w * 0.88, deck + 14); p.lineTo(ax + w, deck + 14); p.lineTo(ax + w, deck); }
  p.closePath(); fillPath(ctx, p, c);
}
function pyramid(ctx, x, base, w, c1, c2) { const p = P2(); p.moveTo(x - w / 2, base); p.lineTo(x, base - w * 0.62); p.lineTo(x + w / 2, base); p.closePath(); fillPath(ctx, p, c1); const s = P2(); s.moveTo(x, base - w * 0.62); s.lineTo(x + w / 2, base); s.lineTo(x + w * 0.08, base); s.closePath(); fillPath(ctx, s, c2); }
function stepPyramid(ctx, x, base, w, c, o = {}) { const p = P2(), n = o.steps || 7; for (let k = 0; k < n; k++) { const ww = w * (1 - k * 0.11), h = w * 0.07; p.rect(x - ww / 2, base - (k + 1) * h, ww, h + 0.5); } p.rect(x - w * 0.12, base - (n + 1.6) * w * 0.07, w * 0.24, w * 0.12); fillPath(ctx, p, c); const st = P2(); st.rect(x - w * 0.06, base - n * w * 0.07, w * 0.12, n * w * 0.07); fillPath(ctx, st, rgba([0, 0, 0], 0.25)); }
function columns(ctx, x0, x1, base, h, n, c, o = {}) { const p = P2(), w = (x1 - x0) / n; for (let i = 0; i < n; i++) { if (o.broken && o.broken.includes(i)) { p.rect(x0 + i * w + w * 0.3, base - h * 0.4, w * 0.4, h * 0.4); continue; } p.rect(x0 + i * w + w * 0.3, base - h, w * 0.4, h); p.rect(x0 + i * w + w * 0.2, base - h - 2, w * 0.6, 2); } if (o.roof) { p.rect(x0 - 2, base - h - 7, x1 - x0 + 4, 5); p.moveTo(x0 - 4, base - h - 7); p.lineTo((x0 + x1) / 2, base - h - 7 - (x1 - x0) * 0.12); p.lineTo(x1 + 4, base - h - 7); p.closePath(); } fillPath(ctx, p, c); }
function minaretTower(ctx, x, base, h, c) { // a tall tapered tower in tiers with balconies (Qutub-style)
  const p = P2(); p.moveTo(x - h * 0.075, base); p.lineTo(x - h * 0.03, base - h); p.lineTo(x + h * 0.03, base - h); p.lineTo(x + h * 0.075, base); p.closePath();
  for (const t of [0.3, 0.52, 0.72, 0.88]) { const w = h * (0.075 - t * 0.045) + 2.5; p.rect(x - w, base - h * t - 1.5, w * 2, 3); }
  p.moveTo(x - h * 0.03, base - h); p.quadraticCurveTo(x, base - h * 1.07, x + h * 0.03, base - h); p.closePath(); fillPath(ctx, p, c);
}
function onionTowers(ctx, x, base, h, c, o = {}) { // Kremlin-style hipped tower
  const p = P2(), w = h * 0.22; p.rect(x - w / 2, base - h * 0.6, w, h * 0.6); p.rect(x - w * 0.6, base - h * 0.62, w * 1.2, h * 0.04); p.moveTo(x - w * 0.42, base - h * 0.62); p.lineTo(x, base - h); p.lineTo(x + w * 0.42, base - h * 0.62); p.closePath(); p.rect(x - 0.5, base - h * 1.08, 1, h * 0.08); fillPath(ctx, p, c);
  if (o.lit) { glow(ctx, x, base - h * 0.4, w, o.lit, 0.3, true); rect(ctx, x - w * 0.12, base - h * 0.45, w * 0.24, h * 0.1, rgba(o.lit, 0.8)); }
}
function eiffel(ctx, x, base, h, c, o = {}) {
  const p = P2(); const w = h * 0.36;
  p.moveTo(x - w / 2, base); p.quadraticCurveTo(x - w * 0.18, base - h * 0.35, x - w * 0.06, base - h * 0.7); p.lineTo(x - 1, base - h); p.lineTo(x + 1, base - h); p.lineTo(x + w * 0.06, base - h * 0.7); p.quadraticCurveTo(x + w * 0.18, base - h * 0.35, x + w / 2, base);
  p.lineTo(x + w * 0.32, base); p.quadraticCurveTo(x, base - h * 0.2, x - w * 0.32, base); p.closePath();
  p.rect(x - w * 0.3, base - h * 0.3, w * 0.6, 2.2); p.rect(x - w * 0.14, base - h * 0.6, w * 0.28, 1.8);
  fillPath(ctx, p, c);
  if (o.lights) { const l = []; for (let t = 0; t < 1; t += 0.02) { const yy = base - h * t, ww = w / 2 * Math.pow(1 - t, 1.8); l.push([x - ww, yy, 0.8], [x + ww, yy, 0.8]); } dots(ctx, l, rgba(o.lights, 0.9)); glow(ctx, x, base - h, 10, o.lights, 0.7, true); }
}
function tvTower(ctx, x, base, h, c, o = {}) { const p = P2(); p.moveTo(x - h * 0.03, base); p.lineTo(x - h * 0.012, base - h * 0.8); p.lineTo(x + h * 0.012, base - h * 0.8); p.lineTo(x + h * 0.03, base); p.closePath(); p.ellipse(x, base - h * 0.62, h * 0.045, h * 0.03, 0, 0, TAU); p.rect(x - 0.5, base - h, 1, h * 0.22); fillPath(ctx, p, c); glow(ctx, x, base - h, 6, [255, 60, 60], 0.8, true); }
function supertall(ctx, x, base, h, c, o = {}) { // stepped skyscraper (Burj / Taipei 101 style by o.kind)
  const p = P2();
  if (o.kind === 'stacked') { const n = 8; p.rect(x - h * 0.05, base - h * 0.2, h * 0.1, h * 0.2); for (let k = 0; k < n; k++) { const y = base - h * 0.2 - k * h * 0.075; p.moveTo(x - h * 0.04, y); p.lineTo(x - h * 0.055, y - h * 0.075); p.lineTo(x + h * 0.055, y - h * 0.075); p.lineTo(x + h * 0.04, y); p.closePath(); } p.rect(x - 0.6, base - h, 1.2, h * 0.2); }
  else { const steps = [[0.07, 0.25], [0.055, 0.45], [0.042, 0.62], [0.03, 0.76], [0.018, 0.88], [0.008, 1]]; let prev = 0; for (const [hw, t] of steps) { p.rect(x - h * hw, base - h * t, h * hw * 2, h * (t - prev) + 0.5); prev = t; } }
  fillPath(ctx, p, c);
  const l = []; for (let y = base - 4; y > base - h * 0.85; y -= 3) l.push([x + h * 0.01, y, 0.6]); dots(ctx, l, rgba(o.lights || [180, 220, 255], 0.6));
  glow(ctx, x, base - h, 6, [255, 80, 80], 0.8, true);
}
function stoneCircle(ctx, x, base, w, c) { const p = P2(); for (let k = -3; k <= 3; k++) { const sx = x + k * w * 0.13, h = w * (k % 2 ? 0.2 : 0.24); p.rect(sx - w * 0.035, base - h, w * 0.07, h); if (k % 2 === 0 && k < 3) p.rect(sx - w * 0.04, base - h - w * 0.035, w * 0.17, w * 0.035); } fillPath(ctx, p, c); }
function castleOnRock(ctx, R, x, base, s, c, o = {}) {
  const p = P2(); p.moveTo(x - s * 1.2, base); p.quadraticCurveTo(x - s * 0.8, base - s * 0.5, x - s * 0.5, base - s * 0.55); p.lineTo(x + s * 0.6, base - s * 0.5); p.quadraticCurveTo(x + s, base - s * 0.3, x + s * 1.3, base); p.closePath();
  const tw = [[-0.35, 0.95, 0.16], [0.05, 1.25, 0.2], [0.42, 0.9, 0.15]];
  p.rect(x - s * 0.45, base - s * 0.8, s * 0.95, s * 0.3);
  for (const [dx, h, w] of tw) { p.rect(x + dx * s - w * s / 2, base - h * s, w * s, (h - 0.5) * s); if (o.cones) { p.moveTo(x + dx * s - w * s * 0.62, base - h * s); p.lineTo(x + dx * s, base - (h + 0.35) * s); p.lineTo(x + dx * s + w * s * 0.62, base - h * s); p.closePath(); } else for (let k = 0; k < 3; k++) p.rect(x + dx * s - w * s / 2 + k * w * s * 0.4, base - (h + 0.05) * s, w * s * 0.2, s * 0.05); }
  fillPath(ctx, p, c);
  if (o.lit) { const l = []; for (let i = 0; i < 10; i++) l.push([x + between(R, -0.4, 0.45) * s, base - between(R, 0.55, 1.1) * s, 0.9]); dots(ctx, l, rgba(o.lit, 0.9)); }
}

// ---------- animals and people (procedural silhouettes) ----------
function giraffe(ctx, x, base, h, c, o = {}) { const d = o.flip ? -1 : 1, s = h / 100, p = P2(); p.ellipse(x, base - 50 * s, 18 * s, 9 * s, -d * 0.15, 0, TAU); for (const lx of [-12, -6, 8, 14]) p.rect(x + lx * s - 1.4 * s, base - 46 * s, 2.8 * s, 46 * s); p.moveTo(x + d * 12 * s, base - 56 * s); p.lineTo(x + d * 26 * s, base - 94 * s); p.lineTo(x + d * 31 * s, base - 92 * s); p.lineTo(x + d * 18 * s, base - 50 * s); p.closePath(); p.ellipse(x + d * 31 * s, base - 95 * s, 6 * s, 3 * s, d * 0.4, 0, TAU); p.rect(x + d * 25 * s, base - 102 * s, 1.4 * s, 6 * s); fillPath(ctx, p, c); }
function rhino(ctx, x, base, h, c, o = {}) { const d = o.flip ? -1 : 1, s = h / 60, p = P2(); p.ellipse(x, base - 30 * s, 34 * s, 18 * s, 0, 0, TAU); p.ellipse(x + d * 36 * s, base - 24 * s, 14 * s, 10 * s, d * 0.3, 0, TAU); p.moveTo(x + d * 44 * s, base - 30 * s); p.lineTo(x + d * 52 * s, base - 46 * s); p.lineTo(x + d * 48 * s, base - 28 * s); p.closePath(); p.moveTo(x + d * 30 * s, base - 34 * s); p.lineTo(x + d * 28 * s, base - 44 * s); p.lineTo(x + d * 34 * s, base - 36 * s); p.closePath(); for (const lx of [-24, -12, 14, 24]) p.rect(x + lx * s - 4 * s, base - 18 * s, 8 * s, 18 * s); fillPath(ctx, p, c); }
function antelope(ctx, x, base, h, c, o = {}) { const d = o.flip ? -1 : 1, s = h / 60, p = P2(); p.ellipse(x, base - 34 * s, 18 * s, 8 * s, 0, 0, TAU); for (const lx of [-12, -8, 9, 13]) p.rect(x + lx * s - 1 * s, base - 30 * s, 2 * s, 30 * s); p.moveTo(x + d * 14 * s, base - 38 * s); p.lineTo(x + d * 20 * s, base - 52 * s); p.lineTo(x + d * 25 * s, base - 50 * s); p.lineTo(x + d * 20 * s, base - 36 * s); p.closePath(); p.ellipse(x + d * 24 * s, base - 52 * s, 5 * s, 3 * s, d * 0.3, 0, TAU); fillPath(ctx, p, c); const hn = P2(); if (o.spiral) { for (const k of [0, 3]) { hn.moveTo(x + d * (21 + k) * s, base - 54 * s); hn.quadraticCurveTo(x + d * (16 + k) * s, base - 64 * s, x + d * (20 + k) * s, base - 72 * s); } } else { hn.moveTo(x + d * 21 * s, base - 54 * s); hn.lineTo(x + d * 10 * s, base - 76 * s); } strokePath(ctx, hn, c, 1.6 * s); }
function horse(ctx, x, base, h, c, o = {}) { // galloping horse by o.pose, or standing
  const d = o.flip ? -1 : 1, s = h / 60, p = P2(), gal = o.pose === 'gallop';
  p.ellipse(x, base - 34 * s, 20 * s, 10 * s, gal ? -d * 0.08 : 0, 0, TAU);
  p.moveTo(x + d * 14 * s, base - 38 * s); p.lineTo(x + d * 24 * s, base - 54 * s); p.lineTo(x + d * 34 * s, base - 46 * s); p.lineTo(x + d * 32 * s, base - 42 * s); p.lineTo(x + d * 24 * s, base - 46 * s); p.lineTo(x + d * 20 * s, base - 32 * s); p.closePath();
  const leg = (lx, ang) => { const ax = x + lx * s, ay = base - 28 * s, ex = ax + Math.sin(ang) * 28 * s, ey = ay + Math.cos(ang) * 28 * s; p.moveTo(ax - 2 * s, ay); p.lineTo(ex - 1.5 * s, ey); p.lineTo(ex + 1.5 * s, ey); p.lineTo(ax + 2 * s, ay); p.closePath(); };
  if (gal) { leg(-14, -d * 0.9); leg(-10, -d * 0.4); leg(12, d * 0.9); leg(16, d * 0.5); } else { leg(-14, 0); leg(-9, 0.05); leg(12, 0); leg(16, -0.05); }
  p.moveTo(x - d * 19 * s, base - 38 * s); p.quadraticCurveTo(x - d * 30 * s, base - 34 * s, x - d * 30 * s, base - 22 * s); p.lineTo(x - d * 27 * s, base - 22 * s); p.quadraticCurveTo(x - d * 26 * s, base - 32 * s, x - d * 18 * s, base - 34 * s); p.closePath();
  fillPath(ctx, p, c);
  if (o.rider) { const r = P2(); personPath(r, x + d * 2 * s, base - 40 * s, 36 * s, { armUp: o.rider === 'up' ? 1 : 0 }); fillPath(ctx, r, c); }
}
function bear(ctx, x, base, h, c, o = {}) { const d = o.flip ? -1 : 1, s = h / 60, p = P2(); p.ellipse(x, base - 30 * s, 30 * s, 20 * s, 0, 0, TAU); p.ellipse(x - d * 10 * s, base - 44 * s, 16 * s, 10 * s, 0, 0, TAU); p.ellipse(x + d * 32 * s, base - 30 * s, 11 * s, 9 * s, 0, 0, TAU); p.ellipse(x + d * 41 * s, base - 27 * s, 5 * s, 4 * s, 0, 0, TAU); p.ellipse(x + d * 28 * s, base - 39 * s, 3 * s, 3 * s, 0, 0, TAU); for (const lx of [-20, -10, 12, 22]) p.rect(x + lx * s - 5 * s, base - 16 * s, 10 * s, 16 * s); fillPath(ctx, p, c); }
function moose(ctx, x, base, h, c, o = {}) { const d = o.flip ? -1 : 1, s = h / 70, p = P2(); p.ellipse(x, base - 40 * s, 24 * s, 13 * s, 0, 0, TAU); p.ellipse(x + d * 16 * s, base - 46 * s, 10 * s, 10 * s, 0, 0, TAU); for (const lx of [-16, -10, 12, 18]) p.rect(x + lx * s - 2 * s, base - 32 * s, 4 * s, 32 * s); p.moveTo(x + d * 20 * s, base - 50 * s); p.lineTo(x + d * 32 * s, base - 44 * s); p.quadraticCurveTo(x + d * 40 * s, base - 36 * s, x + d * 34 * s, base - 30 * s); p.lineTo(x + d * 24 * s, base - 38 * s); p.closePath(); p.moveTo(x + d * 22 * s, base - 52 * s); p.quadraticCurveTo(x + d * 10 * s, base - 70 * s, x + d * 4 * s, base - 62 * s); p.lineTo(x + d * 24 * s, base - 56 * s); p.quadraticCurveTo(x + d * 34 * s, base - 72 * s, x + d * 40 * s, base - 64 * s); p.closePath(); fillPath(ctx, p, c); }
function bird(ctx, x, y, s, c, flap = 0) { const p = P2(); p.moveTo(x - s, y - s * (0.4 + flap)); p.quadraticCurveTo(x - s * 0.4, y - s * 0.6, x, y); p.quadraticCurveTo(x + s * 0.4, y - s * 0.6, x + s, y - s * (0.4 + flap)); strokePath(ctx, p, c, Math.max(0.9, s * 0.18)); }
function birds(ctx, R, x0, y0, x1, y1, n, c, s = 4) { for (let i = 0; i < n; i++) bird(ctx, between(R, x0, x1), between(R, y0, y1), s * between(R, 0.7, 1.2), c, R() * 0.3); }
function soaring(ctx, x, y, s, c, o = {}) { // big bird gliding (eagle, condor) seen from below
  const d = o.flip ? -1 : 1, p = P2(); p.moveTo(x, y); p.quadraticCurveTo(x - s * 0.6, y - s * 0.15, x - s * 1.6, y + s * 0.05);
  for (let k = 0; k < 5; k++) { p.lineTo(x - s * (1.6 - k * 0.12), y + s * (0.12 + k * 0.02)); p.lineTo(x - s * (1.52 - k * 0.12), y + s * 0.06); }
  p.quadraticCurveTo(x - s * 0.6, y + s * 0.22, x - s * 0.2, y + s * 0.2); p.lineTo(x - s * 0.18, y + s * 0.55); p.lineTo(x + s * 0.18, y + s * 0.55); p.lineTo(x + s * 0.2, y + s * 0.2); p.quadraticCurveTo(x + s * 0.6, y + s * 0.22, x + s * 0.9, y + s * 0.14);
  for (let k = 0; k < 5; k++) { p.lineTo(x + s * (1.52 - k * 0.12), y + s * 0.06); p.lineTo(x + s * (1.6 - k * 0.12), y + s * (0.12 + k * 0.02)); }
  p.quadraticCurveTo(x + s * 0.6, y - s * 0.15, x, y); p.closePath(); p.ellipse(x + d * s * 0.02, y - s * 0.05, s * 0.12, s * 0.12, 0, 0, TAU);
  fillPath(ctx, p, c); if (o.whiteHead) circle(ctx, x + d * s * 0.02, y - s * 0.08, s * 0.11, rgba([240, 240, 235]));
}
function dancer(ctx, x, base, h, c, o = {}) { const p = P2(); personPath(p, x, base, h, { armUp: o.armUp ?? 2 }); const s = h / 100; p.moveTo(x - 10 * s, base - 46 * s); p.lineTo(x - 22 * s * (o.twirl || 1), base - 4 * s); p.lineTo(x + 22 * s * (o.twirl || 1), base - 4 * s); p.lineTo(x + 10 * s, base - 46 * s); p.closePath(); fillPath(ctx, p, c); }

// ---------- floors ----------
function planks(ctx, y0, c, o = {}) { rect(ctx, 0, y0, SW, SH - y0, lin(ctx, 0, y0, 0, SH, [[0, rgba(c)], [1, rgba(shade(c, -0.6))]])); const p = P2(); for (let y = y0 + 12; y < SH; y += 12) { p.moveTo(0, y); p.lineTo(SW, y); } strokePath(ctx, p, rgba([0, 0, 0], 0.3), 1, 'butt'); }
function tiles(ctx, y0, c1, c2, s = 30) { rect(ctx, 0, y0, SW, SH - y0, rgba(c1)); const p = P2(); for (let y = y0, r = 0; y < SH; y += s, r++) for (let x = (r % 2) * s; x < SW; x += s * 2) p.rect(x, y, s, s); fillPath(ctx, p, rgba(c2)); rect(ctx, 0, y0, SW, SH - y0, lin(ctx, 0, y0, 0, SH, [[0, 'rgba(0,0,0,0.15)'], [1, 'rgba(0,0,0,0.7)']])); }
function floorShade(ctx, y0 = F - 10) { rect(ctx, 0, y0, SW, SH - y0, lin(ctx, 0, y0, 0, SH, [[0, 'rgba(0,0,0,0.05)'], [1, 'rgba(0,0,0,0.6)']])); }

Object.assign(KIT, { SKIES, skyPreset, mountains, karst, mesas, forestLine, skyline, water, reflection, clouds, aurora, shootingStar, dhow, felucca, junk, gondola, canoe, sailboat, lighthouse, windmill, suspensionBridge, archBridge, stoneArches, pyramid, stepPyramid, columns, minaretTower, onionTowers, eiffel, tvTower, supertall, stoneCircle, castleOnRock, giraffe, rhino, antelope, horse, bear, moose, bird, birds, soaring, dancer, planks, tiles, floorShade });
if (typeof module !== 'undefined') module.exports = KIT; else Object.assign(globalThis, KIT);
