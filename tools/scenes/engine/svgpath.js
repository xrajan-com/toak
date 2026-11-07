// Normalises an SVG path 'd' (any commands, relative or absolute, arcs,
// shorthands) to the scene path subset: absolute M, L, Q, C, Z.
function normalizeSvgPath(d, round = (v) => Math.round(v * 10) / 10) {
  const toks = d.match(/[a-zA-Z]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?/g) || [];
  let i = 0, cmd = null, x = 0, y = 0, sx = 0, sy = 0, lcx = null, lcy = null, lqx = null, lqy = null, prev = '';
  const out = [];
  const num = () => parseFloat(toks[i++]);
  const isNum = () => i < toks.length && !/^[a-zA-Z]$/.test(toks[i]);
  const R = (v) => { const r = round(v); return Object.is(r, -0) ? 0 : r; };
  const emit = (c, ...v) => out.push(c + v.map(R).join(' '));
  function arcToCubics(x1, y1, rx, ry, phi, fa, fs, x2, y2) {
    if (rx === 0 || ry === 0) { emit('L', x2, y2); return; }
    const rad = (phi * Math.PI) / 180, cos = Math.cos(rad), sin = Math.sin(rad);
    const dx = (x1 - x2) / 2, dy = (y1 - y2) / 2;
    const x1p = cos * dx + sin * dy, y1p = -sin * dx + cos * dy;
    rx = Math.abs(rx); ry = Math.abs(ry);
    const lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
    if (lam > 1) { rx *= Math.sqrt(lam); ry *= Math.sqrt(lam); }
    const sign = fa === fs ? -1 : 1;
    const num_ = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
    const coef = sign * Math.sqrt(Math.max(0, num_ / (rx * rx * y1p * y1p + ry * ry * x1p * x1p)));
    const cxp = coef * ((rx * y1p) / ry), cyp = coef * (-(ry * x1p) / rx);
    const cx = cos * cxp - sin * cyp + (x1 + x2) / 2, cy = sin * cxp + cos * cyp + (y1 + y2) / 2;
    const ang = (ux, uy, vx, vy) => { const a = Math.atan2(ux * vy - uy * vx, ux * vx + uy * vy); return a; };
    const t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
    let dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry);
    if (!fs && dt > 0) dt -= 2 * Math.PI; else if (fs && dt < 0) dt += 2 * Math.PI;
    const n = Math.max(1, Math.ceil(Math.abs(dt) / (Math.PI / 2) - 1e-9)), step = dt / n, k = (4 / 3) * Math.tan(step / 4);
    const P = (t) => [cx + rx * Math.cos(t) * cos - ry * Math.sin(t) * sin, cy + rx * Math.cos(t) * sin + ry * Math.sin(t) * cos];
    const D = (t) => [-rx * Math.sin(t) * cos - ry * Math.cos(t) * sin, -rx * Math.sin(t) * sin + ry * Math.cos(t) * cos];
    let t = t1;
    for (let s = 0; s < n; s++) {
      const p0 = P(t), p1 = P(t + step), d0 = D(t), d1 = D(t + step);
      emit('C', p0[0] + k * d0[0], p0[1] + k * d0[1], p1[0] - k * d1[0], p1[1] - k * d1[1], p1[0], p1[1]);
      t += step;
    }
  }
  while (i < toks.length) {
    if (!isNum()) { cmd = toks[i++]; }
    else if (cmd === null) throw new Error('path starts with a number');
    const rel = cmd === cmd.toLowerCase(), C = cmd.toUpperCase();
    const ox = rel ? x : 0, oy = rel ? y : 0;
    switch (C) {
      case 'M': { x = ox + num(); y = oy + num(); sx = x; sy = y; emit('M', x, y); cmd = rel ? 'l' : 'L'; lcx = lqx = null; break; }
      case 'L': { x = ox + num(); y = oy + num(); emit('L', x, y); lcx = lqx = null; break; }
      case 'H': { x = (rel ? x : 0) + num(); emit('L', x, y); lcx = lqx = null; break; }
      case 'V': { y = (rel ? y : 0) + num(); emit('L', x, y); lcx = lqx = null; break; }
      case 'C': { const a = ox + num(), b = oy + num(), c = ox + num(), d2 = oy + num(); x = ox + num(); y = oy + num(); emit('C', a, b, c, d2, x, y); lcx = c; lcy = d2; lqx = null; break; }
      case 'S': { const a = lcx === null ? x : 2 * x - lcx, b = lcx === null ? y : 2 * y - lcy; const c = ox + num(), d2 = oy + num(); x = ox + num(); y = oy + num(); emit('C', a, b, c, d2, x, y); lcx = c; lcy = d2; lqx = null; break; }
      case 'Q': { const a = ox + num(), b = oy + num(); x = ox + num(); y = oy + num(); emit('Q', a, b, x, y); lqx = a; lqy = b; lcx = null; break; }
      case 'T': { const a = lqx === null ? x : 2 * x - lqx, b = lqx === null ? y : 2 * y - lqy; x = ox + num(); y = oy + num(); emit('Q', a, b, x, y); lqx = a; lqy = b; lcx = null; break; }
      case 'A': { const rx = num(), ry = num(), phi = num(); const fa = num(), fs = num(); const nx = ox + num(), ny = oy + num(); arcToCubics(x, y, rx, ry, phi, fa, fs, nx, ny); x = nx; y = ny; lcx = lqx = null; break; }
      case 'Z': { out.push('Z'); x = sx; y = sy; lcx = lqx = null; cmd = null; break; }
      default: throw new Error('unknown command ' + cmd);
    }
    prev = C;
  }
  return out.join('');
}
if (typeof module !== 'undefined') module.exports = { normalizeSvgPath };
