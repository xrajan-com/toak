// Shared parts for the kingdom scenes. Every function draws with the canvas
// API on `ctx` (the recorder in practice), in design units:
//   height 576, reference width 1344, rail top B = 91, rail bottom F = 457.
// What shows around the table: the strip above the rail (y < B; the two HUD
// pills cover the outer thirds of its top 36 units, the dealer covers
// CX +-35 from y 61), the four corners outside the table's round ends, and
// the strip under the rail (the action bar covers CX +-256 from y 495).
const SW = 1344, SH = 576, B = 91, F = 457, CX = 672;
const TAU = Math.PI * 2;
const P2 = () => new Path2D();

function rng(seed) { let s = seed >>> 0; return () => ((s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 4294967296); }
function hashStr(s) { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
const hx = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
const col = (c) => (typeof c === 'string' ? hx(c) : c);
const rgba = (c, a = 1) => { c = col(c); return `rgba(${c[0] | 0},${c[1] | 0},${c[2] | 0},${Math.max(0, Math.min(1, a)).toFixed(3)})`; };
const mix = (a, b, t) => { a = col(a); b = col(b); return [0, 1, 2].map((i) => Math.round(a[i] + (b[i] - a[i]) * t)); };
const shade = (c, t) => (t < 0 ? mix(c, [0, 0, 0], -t) : mix(c, [255, 255, 255], t));
const lerp = (a, b, t) => a + (b - a) * t;
const pick = (R, arr) => arr[Math.floor(R() * arr.length)];
const between = (R, a, b) => a + R() * (b - a);

function lin(ctx, x0, y0, x1, y1, stops) { const g = ctx.createLinearGradient(x0, y0, x1, y1); for (const [o, c] of stops) g.addColorStop(o, c); return g; }
function rad(ctx, x, y, r, stops) { const g = ctx.createRadialGradient(x, y, 0, x, y, r); for (const [o, c] of stops) g.addColorStop(o, c); return g; }
function vstops(cols) { return cols.map((c, i) => [i / (cols.length - 1), typeof c === 'string' && c[0] === 'r' ? c : rgba(c)]); }

function rect(ctx, x, y, w, h, style) { ctx.fillStyle = style; ctx.fillRect(x, y, w, h); }
function fillPath(ctx, p, style) { ctx.fillStyle = style; ctx.fill(p); }
function strokePath(ctx, p, style, w, cap = 'round') { ctx.strokeStyle = style; ctx.lineWidth = w; ctx.lineCap = cap; ctx.lineJoin = 'round'; ctx.stroke(p); ctx.lineCap = 'butt'; ctx.lineJoin = 'miter'; }
function line(ctx, x0, y0, x1, y1, style, w, cap = 'round') { const p = P2(); p.moveTo(x0, y0); p.lineTo(x1, y1); strokePath(ctx, p, style, w, cap); }
function circle(ctx, x, y, r, style) { ctx.fillStyle = style; ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill(); }
function oval(ctx, x, y, rx, ry, style) { ctx.fillStyle = style; ctx.beginPath(); ctx.ellipse(x, y, rx, ry, 0, 0, TAU); ctx.fill(); }
function withBlur(ctx, px, fn) { ctx.save(); ctx.filter = `blur(${px}px)`; fn(); ctx.restore(); }
function additive(ctx, fn) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; fn(); ctx.restore(); }
function anchored(ctx, a, fn) { ctx.anchorTo(a); fn(); ctx.anchorTo('C'); }

// soft round light
function glow(ctx, x, y, r, c, a = 0.6, add = false) {
  const f = () => { ctx.fillStyle = rad(ctx, x, y, r, [[0, rgba(c, a)], [0.35, rgba(c, a * 0.4)], [1, rgba(c, 0)]]); ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill(); };
  if (add) additive(ctx, f); else f();
}
// many dots of one colour in one op
function dots(ctx, list, style) { if (!list.length) return; const p = P2(); for (const [x, y, r] of list) { if (p.addCircle) p.addCircle(x, y, r); else { p.moveTo(x + r, y); p.arc(x, y, r, 0, TAU); } } fillPath(ctx, p, style); }

// ---------- sky ----------
function sky(ctx, cols, y0 = 0, y1 = SH) { rect(ctx, 0, y0, SW, y1 - y0, lin(ctx, 0, y0, 0, y1, vstops(cols))); }
function stars(ctx, R, n, box = [0, 0, SW, B], o = {}) {
  const [x0, y0, x1, y1] = box; const buckets = [[], [], []];
  for (let i = 0; i < n; i++) { const b = Math.floor(R() * 3); buckets[b].push([between(R, x0, x1), y0 + Math.pow(R(), o.bias || 1) * (y1 - y0), (o.size || 0.9) * (0.45 + R() * 0.55) * (b === 2 ? 1.25 : 1)]); }
  const c = o.color || [225, 240, 255];
  buckets.forEach((l, i) => dots(ctx, l, rgba(c, [0.35, 0.6, 0.95][i] * (o.alpha || 1))));
  for (let i = 0; i < (o.bright ?? Math.round(n / 25)); i++) { const x = between(R, x0, x1), y = between(R, y0, y1); glow(ctx, x, y, 6, c, 0.5, true); circle(ctx, x, y, 1.1, rgba([255, 255, 255], 0.95)); }
}
function moon(ctx, x, y, r, o = {}) {
  const c = o.color || [235, 245, 255];
  glow(ctx, x, y, r * (o.halo || 5), o.haloColor || c, o.haloA ?? 0.35, true);
  circle(ctx, x, y, r, rgba(c, 1));
  if (o.crescent) circle(ctx, x + r * 0.42, y - r * 0.18, r * 0.9, o.crescent);
  else { dots(ctx, [[x - r * 0.3, y - r * 0.2, r * 0.22], [x + r * 0.25, y + r * 0.3, r * 0.15], [x + r * 0.1, y - r * 0.4, r * 0.1]], rgba(shade(c, -0.12), 0.6)); }
}
function sunDisc(ctx, x, y, r, c1, c2, horizonY) {
  glow(ctx, x, y, r * 6, c1, 0.45, true);
  glow(ctx, x, y, r * 2.2, c2, 0.6, true);
  ctx.save(); if (horizonY != null) { const p = P2(); p.rect(x - r * 2, y - r * 2, r * 4, horizonY - (y - r * 2)); ctx.clip(p); }
  ctx.fillStyle = lin(ctx, 0, y - r, 0, y + r, [[0, rgba(shade(c2, 0.5))], [1, rgba(c1)]]); ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
  ctx.restore();
}
function milkyWay(ctx, R, x0, y0, x1, y1, width, o = {}) {
  const n = 26, c1 = o.c1 || [190, 170, 255], c2 = o.c2 || [255, 200, 170];
  additive(ctx, () => {
    for (let i = 0; i <= n; i++) {
      const t = i / n, x = lerp(x0, x1, t) + (R() - 0.5) * width * 0.4, y = lerp(y0, y1, t) + (R() - 0.5) * width * 0.4;
      const w = width * (0.6 + R() * 0.7) * (0.6 + Math.sin(t * Math.PI) * 0.6);
      withBlur(ctx, width * 0.35, () => oval(ctx, x, y, w, w * 0.55, rgba(mix(c1, c2, R()), 0.10 + R() * 0.06)));
    }
  });
  const pts = [];
  for (let i = 0; i < 420; i++) { const t = R(), off = (R() + R() + R() - 1.5) * width * 0.8; const nx = -(y1 - y0), ny = x1 - x0, l = Math.hypot(nx, ny); pts.push([lerp(x0, x1, t) + (nx / l) * off, lerp(y0, y1, t) + (ny / l) * off, 0.35 + R() * 0.55]); }
  dots(ctx, pts, rgba([255, 255, 255], 0.55));
  // dust lanes
  withBlur(ctx, width * 0.12, () => { const p = P2(); p.moveTo(x0, y0); for (let i = 1; i <= 8; i++) { const t = i / 8; p.lineTo(lerp(x0, x1, t) + (R() - 0.5) * width * 0.25, lerp(y0, y1, t) + (R() - 0.5) * width * 0.25); } strokePath(ctx, p, rgba(o.dust || [8, 6, 22], 0.55), width * 0.18); });
}

// ---------- land ----------
// A ridge line: smooth noise between y0 (low) and y0 - amp (high).
function ridgeFn(R, amp, freqs = [0.004, 0.011, 0.027]) {
  const ph = freqs.map(() => R() * TAU), wt = freqs.map((_, i) => 1 / (i + 1));
  const tot = wt.reduce((a, b) => a + b, 0);
  return (x) => { let v = 0; freqs.forEach((f, i) => { v += wt[i] * (0.5 + 0.5 * Math.sin(x * f + ph[i])); }); return (v / tot) * amp; };
}
function ridge(ctx, R, y0, amp, style, o = {}) {
  const f = o.fn || ridgeFn(R, amp, o.freqs), x0 = o.x0 ?? -20, x1 = o.x1 ?? SW + 20, step = o.step || 6;
  const p = P2(); p.moveTo(x0, o.bottom ?? SH);
  for (let x = x0; x <= x1; x += step) p.lineTo(x, y0 - f(x) * (o.env ? o.env(x) : 1));
  p.lineTo(x1, o.bottom ?? SH); p.closePath(); fillPath(ctx, p, style); return f;
}
function horizonHaze(ctx, y, h, c, a = 0.5) { rect(ctx, 0, y - h, SW, h * 2, lin(ctx, 0, y - h, 0, y + h, [[0, rgba(c, 0)], [0.5, rgba(c, a)], [1, rgba(c, 0)]])); }

// ---------- finishing ----------
// Brand split: warm light from the left (red side), cool from the right
// (blue side); then a vignette and a dim so the table stays the subject.
function finish(ctx, o = {}) {
  const split = o.split ?? 0.5;
  if (split > 0) {
    anchored(ctx, 'L', () => glow(ctx, 0, SH * 0.55, 520, [255, 70, 20], 0.20 * split, true));
    anchored(ctx, 'R', () => glow(ctx, SW, SH * 0.35, 520, [0, 181, 200], 0.18 * split, true));
  }
  if (o.dim) rect(ctx, 0, 0, SW, SH, rgba([0, 0, 0], o.dim));
  ctx.fillStyle = rad(ctx, CX, SH * 0.5, SW * 0.62, [[0, 'rgba(0,0,0,0)'], [0.55, 'rgba(0,0,0,0)'], [1, rgba([0, 0, 0], o.vignette ?? 0.5)]]);
  ctx.fillRect(0, 0, SW, SH);
  // the rail sits on a soft contact shadow
  rect(ctx, 0, B - 10, SW, 12, lin(ctx, 0, B - 10, 0, B + 2, [[0, 'rgba(0,0,0,0)'], [1, rgba([0, 0, 0], o.railShadow ?? 0.35)]]));
}

// ---------- figures ----------
// A standing person seen from behind/front, feet at (x, y), height h.
function personPath(p, x, y, h, o = {}) {
  const s = h / 100, armUp = o.armUp || 0; // 0 none, 1 one arm, 2 both
  p.moveTo(x + 7 * s, y - 88 * s); p.arc(x, y - 88 * s, 7 * s, 0, TAU);
  p.moveTo(x - 11 * s, y - 76 * s); p.quadraticCurveTo(x, y - 80 * s, x + 11 * s, y - 76 * s);
  p.lineTo(x + 9 * s, y - 45 * s); p.lineTo(x + 7 * s, y); p.lineTo(x + 1.5 * s, y); p.lineTo(x, y - 40 * s);
  p.lineTo(x - 1.5 * s, y); p.lineTo(x - 7 * s, y); p.lineTo(x - 9 * s, y - 45 * s); p.closePath();
  const arm = (side, up) => {
    const sx = x + side * 10 * s, sy = y - 74 * s;
    if (up) { p.moveTo(sx, sy); p.lineTo(sx + side * (4 + up * 3) * s, sy - 30 * s); p.lineTo(sx + side * (8 + up * 3) * s, sy - 29 * s); p.lineTo(sx + side * 4 * s, sy + 6 * s); p.closePath(); }
    else { p.moveTo(sx, sy); p.lineTo(sx + side * 5 * s, sy + 30 * s); p.lineTo(sx + side * 1 * s, sy + 31 * s); p.lineTo(sx - side * 2 * s, sy + 6 * s); p.closePath(); }
  };
  arm(-1, armUp >= 2 ? 1 : 0); arm(1, armUp >= 1 ? 1.2 : 0);
}
// Rows of heads and shoulders with some raised hands: a crowd facing a stage.
function crowd(ctx, R, x0, x1, y, size, style, o = {}) {
  const p = P2(), heads = [];
  for (let x = x0; x < x1; x += size * (0.5 + R() * 0.35)) {
    const yy = y + (R() - 0.5) * size * 0.25, hs = size * (0.85 + R() * 0.3);
    heads.push([x, yy - hs * 0.62, hs * 0.2]);
    p.moveTo(x - hs * 0.36, yy + size); p.quadraticCurveTo(x - hs * 0.38, yy - hs * 0.32, x, yy - hs * 0.36); p.quadraticCurveTo(x + hs * 0.38, yy - hs * 0.32, x + hs * 0.36, yy + size); p.closePath();
    if (R() < (o.hands ?? 0.2)) {
      const side = R() < 0.5 ? -1 : 1, hx2 = x + side * hs * (0.25 + R() * 0.25), top = yy - hs * (1.15 + R() * 0.45);
      p.moveTo(x + side * hs * 0.22, yy - hs * 0.2); p.lineTo(hx2 - hs * 0.05, top); p.lineTo(hx2 + hs * 0.08, top); p.lineTo(x + side * hs * 0.34, yy - hs * 0.1); p.closePath();
      heads.push([hx2 + hs * 0.015, top - hs * 0.03, hs * 0.075]);
      if (o.lights && R() < 0.5) o.lights.push([hx2, top - hs * 0.06]);
    }
  }
  fillPath(ctx, p, style); dots(ctx, heads, style);
}

// ---------- props ----------
function pennant(ctx, x, y, w, h, c, o = {}) {
  const p = P2(); p.moveTo(x, y); p.lineTo(x + w, y + h * 0.5 + (o.wave || 0)); p.lineTo(x, y + h); p.closePath(); fillPath(ctx, p, rgba(c, o.a ?? 1));
}
function stringLights(ctx, x0, y0, x1, y1, sag, n, light, r, o = {}) {
  const cx = (x0 + x1) / 2, cy = Math.max(y0, y1) + sag;
  const wire = P2(); wire.moveTo(x0, y0); wire.quadraticCurveTo(cx, cy, x1, y1); strokePath(ctx, wire, rgba([10, 10, 10], 0.85), Math.max(0.8, r * 0.3));
  const bulbs = [];
  for (let i = 1; i < n; i++) { const t = i / n, x = (1 - t) * (1 - t) * x0 + 2 * (1 - t) * t * cx + t * t * x1, y = (1 - t) * (1 - t) * y0 + 2 * (1 - t) * t * cy + t * t * y1; bulbs.push([x, y + r, r]); if (!o.noGlow) glow(ctx, x, y + r, r * 6, light, 0.45, true); }
  dots(ctx, bulbs, rgba(mix(light, [255, 255, 255], 0.55)));
}
// Light beam from (x, y) toward angle a (radians, 0 = right, -PI/2 = up).
function beam(ctx, x, y, a, len, spread, c, alpha = 0.35, o = {}) {
  const ex = x + Math.cos(a) * len, ey = y + Math.sin(a) * len, nx = -Math.sin(a), ny = Math.cos(a), w = len * Math.tan(spread / 2);
  const p = P2(); p.moveTo(x + nx * (o.base || 1), y + ny * (o.base || 1)); p.lineTo(ex + nx * w, ey + ny * w); p.lineTo(ex - nx * w, ey - ny * w); p.lineTo(x - nx * (o.base || 1), y - ny * (o.base || 1)); p.closePath();
  additive(ctx, () => withBlur(ctx, o.blur ?? 2, () => fillPath(ctx, p, lin(ctx, x, y, ex, ey, [[0, rgba(c, alpha)], [0.6, rgba(c, alpha * 0.3)], [1, rgba(c, 0)]]))));
}
function icon(ctx, name, x, y, size, style, o = {}) { ctx.fillStyle = style; ctx.icon(name, x, y, size, o); }
// icon placed by its bottom-centre (icons sit in a 512 box)
function iconAt(ctx, name, cx, base, size, style, o = {}) { icon(ctx, name, cx - size / 2, base - size * (o.bottom ?? 1), size, style, o); }

// ---------- architecture ----------
// Indian fort skyline: walls with rounded merlons, round bastions and
// domed chhatris. Returns lit window positions.
function rajputFort(ctx, R, x0, x1, base, top, style, o = {}) {
  const p = P2(), wins = [];
  const mW = o.merlon || 5;
  p.moveTo(x0, base);
  const segs = [];
  let x = x0;
  while (x < x1) { const w = between(R, 50, 110); segs.push([x, Math.min(x1, x + w), top + between(R, 0, (base - top) * 0.35)]); x += w; }
  for (const [a, b, t] of segs) {
    // wall body with rounded merlons
    p.lineTo(a, t);
    for (let mx = a; mx < b - mW; mx += mW * 1.8) { p.lineTo(mx, t); p.lineTo(mx, t - mW * 0.8); p.arc(mx + mW / 2, t - mW * 0.8, mW / 2, Math.PI, 0); p.lineTo(mx + mW, t); }
    p.lineTo(b, t);
    if (R() < 0.6) for (let k = 0; k < 2 + R() * 3; k++) wins.push([between(R, a + 6, b - 6), between(R, t + 6, base - 6)]);
  }
  p.lineTo(x1, base); p.closePath();
  fillPath(ctx, p, style);
  // bastions and chhatris
  const n = o.towers || 6;
  for (let i = 0; i < n; i++) {
    const tx = lerp(x0, x1, (i + 0.5) / n) + (R() - 0.5) * 30, tw = between(R, 16, 26), tt = top - between(R, 4, 18);
    const q = P2(); q.rect(tx - tw / 2, tt, tw, base - tt); fillPath(ctx, q, style);
    chhatri(ctx, tx, tt, tw * 0.9, style);
    if (R() < 0.7) wins.push([tx, tt + 10]);
  }
  return wins;
}
function chhatri(ctx, x, base, w, style) {
  const p = P2(), h = w * 0.55;
  p.rect(x - w / 2, base - 2, w, 2);
  for (const k of [-0.4, 0, 0.4]) p.rect(x + k * w - 0.8, base - h * 0.55, 1.6, h * 0.55);
  p.rect(x - w * 0.55, base - h * 0.62, w * 1.1, h * 0.1);
  p.moveTo(x - w * 0.42, base - h * 0.6); p.quadraticCurveTo(x - w * 0.42, base - h * 1.25, x, base - h * 1.35); p.quadraticCurveTo(x + w * 0.42, base - h * 1.25, x + w * 0.42, base - h * 0.6); p.closePath();
  p.rect(x - 0.6, base - h * 1.6, 1.2, h * 0.28);
  fillPath(ctx, p, style);
}
// Scalloped (cusped) Mughal arch path, opening between x0..x1 from y top to base.
function cuspedArch(p, x0, x1, top, base, rise = 0.55) {
  const w = x1 - x0, cx = (x0 + x1) / 2, spring = top + w * rise;
  p.moveTo(x0, base); p.lineTo(x0, spring);
  const lobes = 5;
  let px = x0, py = spring;
  for (let i = 1; i <= lobes; i++) {
    const t = i / lobes, ang = Math.PI - t * Math.PI;
    const ex = cx + Math.cos(ang) * w / 2, ey = spring - Math.sin(ang) * (spring - top) * (i === Math.ceil(lobes / 2) ? 1.08 : 1);
    const mx = (px + ex) / 2, my = (py + ey) / 2, nx = cx - mx, ny = (spring + top) / 2 - my, l = Math.hypot(nx, ny);
    p.quadraticCurveTo(mx - (nx / l) * w * 0.06, my - (ny / l) * w * 0.06, ex, ey);
    px = ex; py = ey;
  }
  p.lineTo(x1, base); p.closePath();
}
// Japanese castle keep (tenshu) centred at x, base y, width w.
function tenshu(ctx, x, base, w, o = {}) {
  const wall = o.wall || '#e9e4da', roof = o.roof || '#1c2228', stone = o.stone || '#3b3a3c', lit = o.lit || [255, 190, 110];
  // stone base with concave sides
  const sb = P2(), sh = w * 0.22;
  sb.moveTo(x - w * 0.62, base); sb.quadraticCurveTo(x - w * 0.5, base - sh * 0.3, x - w * 0.46, base - sh); sb.lineTo(x + w * 0.46, base - sh); sb.quadraticCurveTo(x + w * 0.5, base - sh * 0.3, x + w * 0.62, base); sb.closePath();
  fillPath(ctx, sb, lin(ctx, 0, base - sh, 0, base, [[0, rgba(shade(stone, 0.15))], [1, rgba(shade(stone, -0.4))]]));
  let y = base - sh, tw = w * 0.9;
  const tiers = o.tiers || 5, lights = [];
  for (let i = 0; i < tiers; i++) {
    const th = w * (i === 0 ? 0.16 : 0.12);
    const wl = P2(); wl.rect(x - tw / 2, y - th, tw, th); fillPath(ctx, wl, lin(ctx, x - tw / 2, 0, x + tw / 2, 0, [[0, wall], [1, rgba(shade(wall, -0.35))]]));
    // windows
    for (let k = -2; k <= 2; k++) if (tw > w * 0.4 || Math.abs(k) < 2) lights.push([x + k * tw * 0.18, y - th * 0.5]);
    // roof with upturned eaves
    const ry = y - th, ew = tw * 0.62, rh = w * 0.07;
    const r = P2(); r.moveTo(x - ew - w * 0.04, ry + rh * 0.1); r.quadraticCurveTo(x - ew * 0.6, ry + rh * 0.55, x - tw * 0.38, ry - rh * 0.4); r.lineTo(x + tw * 0.38, ry - rh * 0.4); r.quadraticCurveTo(x + ew * 0.6, ry + rh * 0.55, x + ew + w * 0.04, ry + rh * 0.1); r.lineTo(x + ew * 0.86, ry + rh * 0.42); r.lineTo(x - ew * 0.86, ry + rh * 0.42); r.closePath();
    fillPath(ctx, r, roof);
    // chidori gable on alternate tiers
    if (i % 2 === 1 && i < tiers - 1) { const g = P2(); g.moveTo(x - tw * 0.2, ry - rh * 0.3); g.quadraticCurveTo(x, ry - rh * 2.2, x + tw * 0.2, ry - rh * 0.3); g.closePath(); fillPath(ctx, g, roof); const gw = P2(); gw.moveTo(x - tw * 0.12, ry - rh * 0.35); gw.quadraticCurveTo(x, ry - rh * 1.6, x + tw * 0.12, ry - rh * 0.35); gw.closePath(); fillPath(ctx, gw, wall); }
    y = ry - rh * 0.4; tw *= 0.8;
  }
  // top roof with ridge fish
  const tr = P2(), rw = tw * 0.9, rh = w * 0.1;
  tr.moveTo(x - rw - w * 0.05, y + rh * 0.15); tr.quadraticCurveTo(x - rw * 0.4, y - rh * 0.1, x - rw * 0.3, y - rh); tr.lineTo(x + rw * 0.3, y - rh); tr.quadraticCurveTo(x + rw * 0.4, y - rh * 0.1, x + rw + w * 0.05, y + rh * 0.15); tr.closePath();
  fillPath(ctx, tr, roof);
  for (const s of [-1, 1]) { const f = P2(); f.moveTo(x + s * rw * 0.3, y - rh); f.quadraticCurveTo(x + s * rw * 0.42, y - rh * 1.8, x + s * rw * 0.3, y - rh * 1.9); f.lineTo(x + s * rw * 0.26, y - rh); f.closePath(); fillPath(ctx, f, o.gold || '#c9a24e'); }
  return lights;
}
function torii(ctx, x, base, h, c = '#d8361b', dark = '#1a0d0a') {
  const w = h * 1.05, p = P2();
  p.rect(x - w * 0.36, base - h * 0.86, h * 0.07, h * 0.86); p.rect(x + w * 0.36 - h * 0.07, base - h * 0.86, h * 0.07, h * 0.86);
  p.rect(x - w * 0.5, base - h * 0.74, w, h * 0.06);
  fillPath(ctx, p, c);
  const k = P2(); k.moveTo(x - w * 0.6, base - h * 0.98); k.quadraticCurveTo(x, base - h * 0.84, x + w * 0.6, base - h * 0.98); k.lineTo(x + w * 0.56, base - h * 0.88); k.quadraticCurveTo(x, base - h * 0.78, x - w * 0.56, base - h * 0.88); k.closePath();
  fillPath(ctx, k, dark);
  const k2 = P2(); k2.moveTo(x - w * 0.52, base - h * 0.87); k2.quadraticCurveTo(x, base - h * 0.77, x + w * 0.52, base - h * 0.87); k2.lineTo(x + w * 0.5, base - h * 0.82); k2.quadraticCurveTo(x, base - h * 0.72, x - w * 0.5, base - h * 0.82); k2.closePath();
  fillPath(ctx, k2, c);
}

// ---------- plants ----------
function palm(ctx, R, x, base, h, style, o = {}) {
  const lean = (o.lean ?? (R() - 0.5) * 0.5) * h, top = [x + lean, base - h];
  const trunk = P2(); trunk.moveTo(x - h * 0.03, base); trunk.quadraticCurveTo(x + lean * 0.2, base - h * 0.5, top[0] - h * 0.012, top[1]); trunk.lineTo(top[0] + h * 0.012, top[1]); trunk.quadraticCurveTo(x + lean * 0.2 + h * 0.03, base - h * 0.5, x + h * 0.03, base); trunk.closePath();
  fillPath(ctx, trunk, style);
  const n = o.fronds || 9;
  for (let i = 0; i < n; i++) {
    const a = -Math.PI + (i / (n - 1)) * Math.PI + (R() - 0.5) * 0.25, len = h * between(R, 0.32, 0.46);
    ctx.save(); ctx.translate(top[0], top[1]); ctx.rotate(a);
    const f = P2(); f.moveTo(0, 0); f.quadraticCurveTo(len * 0.5, -len * 0.22, len, len * 0.25); f.quadraticCurveTo(len * 0.5, len * 0.02, 0, 0); fillPath(ctx, f, style);
    const lf = P2(); for (let t = 0.15; t < 0.95; t += 0.07) { const px = len * t, py = -len * 0.18 * Math.sin(t * Math.PI) + len * 0.25 * t * t; lf.moveTo(px, py); lf.lineTo(px + len * 0.06, py + len * 0.16); }
    strokePath(ctx, lf, style, Math.max(1, h * 0.012));
    ctx.restore();
  }
}
// A flowering branch growing from (x, y) toward angle a.
function blossomBranch(ctx, R, x, y, a, len, wood, blooms, o = {}) {
  const flowers = [[], []];
  const grow = (x0, y0, ang, l, w, depth) => {
    const x1 = x0 + Math.cos(ang) * l, y1 = y0 + Math.sin(ang) * l;
    const p = P2(); p.moveTo(x0, y0); p.quadraticCurveTo((x0 + x1) / 2 + (R() - 0.5) * l * 0.2, (y0 + y1) / 2 + (R() - 0.5) * l * 0.2, x1, y1);
    strokePath(ctx, p, wood, w);
    if (depth > 0) { const k = 2 + (R() < 0.4 ? 1 : 0); for (let i = 0; i < k; i++) grow(lerp(x0, x1, 0.55 + R() * 0.45), lerp(y0, y1, 0.55 + R() * 0.45), ang + (R() - 0.5) * 1.3, l * between(R, 0.45, 0.7), w * 0.6, depth - 1); }
    if (depth <= 1) for (let i = 0; i < 9; i++) { const t = R(); flowers[R() < 0.7 ? 0 : 1].push([lerp(x0, x1, t) + (R() - 0.5) * l * 0.35, lerp(y0, y1, t) + (R() - 0.5) * l * 0.35, between(R, 1.2, 2.8) * (o.bloomSize || 1)]); }
  };
  grow(x, y, a, len, o.width || len * 0.06, o.depth ?? 3);
  if (o.glow) for (const f of flowers[0].slice(0, 12)) glow(ctx, f[0], f[1], 8, blooms[0], 0.12, true);
  dots(ctx, flowers[0], rgba(blooms[0])); dots(ctx, flowers[1], rgba(blooms[1]));
}
function pineTree(ctx, x, base, h, style) { iconAt(ctx, 'pine-tree', x, base, h, style); }

// ---------- lanterns & fireworks ----------
function chochin(ctx, x, top, len, r, c = [230, 60, 40], o = {}) {
  line(ctx, x, top, x, top + len, rgba([10, 8, 8], 0.9), 1);
  const y = top + len + r * 1.25;
  glow(ctx, x, y, r * 4, c, 0.45, true);
  ctx.fillStyle = rad(ctx, x - r * 0.2, y - r * 0.2, r * 1.6, [[0, rgba(mix(c, [255, 230, 160], 0.55))], [0.6, rgba(c)], [1, rgba(shade(c, -0.45))]]);
  ctx.beginPath(); ctx.ellipse(x, y, r, r * 1.25, 0, 0, TAU); ctx.fill();
  const ribs = P2(); for (let k = -3; k <= 3; k++) { const yy = y + k * r * 0.33; const hw = r * Math.sqrt(Math.max(0, 1 - Math.pow(k * 0.33 / 1.25, 2))); ribs.moveTo(x - hw, yy); ribs.lineTo(x + hw, yy); }
  strokePath(ctx, ribs, rgba(shade(c, -0.5), 0.45), Math.max(0.5, r * 0.06), 'butt');
  rect(ctx, x - r * 0.55, y - r * 1.32, r * 1.1, r * 0.22, '#141010'); rect(ctx, x - r * 0.55, y + r * 1.1, r * 1.1, r * 0.22, '#141010');
  if (o.mark) { const m = P2(); m.moveTo(x - r * 0.3, y - r * 0.4); m.lineTo(x + r * 0.3, y + r * 0.4); m.moveTo(x + r * 0.3, y - r * 0.4); m.lineTo(x - r * 0.3, y + r * 0.4); strokePath(ctx, m, rgba([30, 10, 8], 0.75), r * 0.16); }
}
function brassLantern(ctx, x, top, len, s, light = [255, 180, 90]) {
  line(ctx, x, top, x, top + len, rgba([20, 14, 8], 0.9), 1);
  const y = top + len;
  glow(ctx, x, y + s * 1.2, s * 5, light, 0.5, true);
  const body = P2();
  body.moveTo(x, y); body.lineTo(x + s * 0.25, y + s * 0.35); body.quadraticCurveTo(x + s * 0.9, y + s * 0.6, x + s * 0.7, y + s * 1.4); body.lineTo(x + s * 0.5, y + s * 2.1); body.lineTo(x - s * 0.5, y + s * 2.1); body.lineTo(x - s * 0.7, y + s * 1.4); body.quadraticCurveTo(x - s * 0.9, y + s * 0.6, x - s * 0.25, y + s * 0.35); body.closePath();
  fillPath(ctx, body, lin(ctx, x - s, 0, x + s, 0, [[0, '#5a3a14'], [0.45, '#c8923c'], [1, '#4a2e10']]));
  const holes = [];
  for (let r2 = 0; r2 < 4; r2++) for (let k = -2; k <= 2; k++) { const yy = y + s * (0.7 + r2 * 0.38), xx = x + k * s * 0.22 + (r2 % 2) * s * 0.11; if (Math.abs(xx - x) < s * (0.62 - Math.abs(r2 - 1.5) * 0.06)) holes.push([xx, yy, s * 0.07]); }
  dots(ctx, holes, rgba([255, 230, 170], 0.95));
  rect(ctx, x - s * 0.55, y + s * 2.1, s * 1.1, s * 0.15, '#3a2508');
}
function firework(ctx, R, x, y, r, c, o = {}) {
  additive(ctx, () => {
    glow(ctx, x, y, r * 1.4, c, 0.18);
    const n = o.rays || 42, sparks = [];
    const p = P2();
    for (let i = 0; i < n; i++) {
      const a = (i / n) * TAU + R() * 0.08, l = r * between(R, 0.75, 1.05);
      p.moveTo(x + Math.cos(a) * l * 0.25, y + Math.sin(a) * l * 0.25 + l * 0.02);
      p.quadraticCurveTo(x + Math.cos(a) * l * 0.7, y + Math.sin(a) * l * 0.7, x + Math.cos(a) * l, y + Math.sin(a) * l + l * 0.08);
      sparks.push([x + Math.cos(a) * l, y + Math.sin(a) * l + l * 0.08, r * 0.022]);
    }
    strokePath(ctx, p, rgba(c, 0.55), r * 0.012);
    dots(ctx, sparks, rgba(mix(c, [255, 255, 255], 0.6), 0.95));
  });
}
function kite(ctx, x, y, s, c1, c2, rot = 0, o = {}) {
  ctx.save(); ctx.translate(x, y); ctx.rotate(rot);
  const p = P2(); p.moveTo(0, -s); p.lineTo(s * 0.8, 0); p.lineTo(0, s * 0.95); p.lineTo(-s * 0.8, 0); p.closePath(); fillPath(ctx, p, rgba(c1));
  const h = P2(); h.moveTo(0, -s); h.lineTo(s * 0.8, 0); h.lineTo(0, s * 0.95); h.closePath(); fillPath(ctx, h, rgba(c2));
  if (o.band) { const b = P2(); b.moveTo(-s * 0.8, 0); b.lineTo(s * 0.8, 0); strokePath(ctx, b, rgba(o.band, 0.9), s * 0.08); }
  const t = P2(); t.moveTo(0, s * 0.95); t.lineTo(s * 0.25, s * 1.35); t.lineTo(-s * 0.25, s * 1.35); t.closePath(); fillPath(ctx, t, rgba(c2));
  ctx.restore();
}

// Layout of the strip above the rail (C-anchored scene x, 16:9 worst case):
// hero zones either side of the dealer take tall shapes; the flanks sit
// under the HUD pills, so keep them below y 36.
const HERO_L = [452, 628], HERO_R = [716, 940], DEALER = [637, 707], HORIZON = 86;

// An icon with a thin light edge on the side facing the light.
function rimIcon(ctx, name, cx, base, size, dark, rim, o = {}) {
  const dx = o.dx ?? -1.6, dy = o.dy ?? -0.8;
  iconAt(ctx, name, cx + dx * size / 60, base + dy * size / 60, size, rgba(rim, o.rimA ?? 0.85), o);
  iconAt(ctx, name, cx, base, size, dark, o);
}
// A soft canopy of overlapping blobs (sakura, foliage); lighter on top.
function canopy(ctx, R, cx, cy, w, h, top, bottom, o = {}) {
  const n = o.n || Math.round(w * h / 60), shade1 = [], shade2 = [], shade3 = [];
  for (let i = 0; i < n; i++) {
    const a = R() * TAU, r = Math.sqrt(R()), x = cx + Math.cos(a) * r * w / 2, y = cy + Math.sin(a) * r * h / 2, s = between(R, 0.06, 0.16) * Math.min(w, h * 2);
    const t = (y - (cy - h / 2)) / h;
    (t < 0.35 ? shade1 : t < 0.7 ? shade2 : shade3).push([x, y, s]);
  }
  dots(ctx, shade3, rgba(bottom)); dots(ctx, shade2, rgba(mix(top, bottom, 0.5))); dots(ctx, shade1, rgba(top));
  if (o.sparkle) dots(ctx, shade1.slice(0, 30).map(([x, y]) => [x + between(R, -3, 3), y + between(R, -3, 3), 0.8]), rgba(o.sparkle, 0.9));
}
// Ground plane from the horizon down: a lit haze that darkens toward the floor.
function ground(ctx, cols, y0 = HORIZON) {
  // cols: [at the horizon, 40 below it, the floor]; the lit band stays thin
  const [a, b, c] = cols.map((x) => (typeof x === 'string' && x[0] === 'r' ? x : rgba(x)));
  rect(ctx, 0, y0, SW, SH - y0, lin(ctx, 0, y0, 0, SH, [[0, a], [40 / (SH - y0), b], [0.45, c], [1, c]]));
}

const KIT = { HERO_L, HERO_R, DEALER, HORIZON, rimIcon, canopy, ground, SW, SH, B, F, CX, TAU, rng, hashStr, rgba, mix, shade, lerp, pick, between, lin, rad, vstops, rect, fillPath, strokePath, line, circle, oval, withBlur, additive, anchored, glow, dots, sky, stars, moon, sunDisc, milkyWay, ridgeFn, ridge, horizonHaze, finish, personPath, crowd, pennant, stringLights, beam, icon, iconAt, rajputFort, chhatri, cuspedArch, tenshu, torii, palm, blossomBranch, pineTree, chochin, brassLantern, firework, kite, P2, col };
if (typeof module !== 'undefined') module.exports = KIT; else Object.assign(globalThis, KIT);
