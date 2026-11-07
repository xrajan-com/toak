// Scene recorder: a stand-in for CanvasRenderingContext2D that records what a
// scene draws as a small display list (JSON). The same list is drawn by
// interp.js (previews) and by lib/ui/art/scene_painter.dart (the app), so a
// scene is authored once, in ordinary canvas code, and ships as data.
//
// Format v1 (all coordinates in design units: height 576, reference width
// 1344; 'A' re-anchors x to the left edge, centre or right edge of the real
// screen):
//   paths:  ["M x y L x y Q cx cy x y C c1x c1y c2x c2y x y Z", ...]
//   paints: [{k:'f'|'s', c: argb | {lin:[x0,y0,x1,y1]} | {rad:[cx,cy,r]},
//             st:[[offset, argb], ...], w, cap, join, b: blurSigma (local
//             units), m: 'plus'|'screen'|'multiply', eo: 1}, ...]
//   ops:    ['S'] save, ['X'] restore, ['T',a,b,c,d,e,f] transform,
//           ['A','L'|'C'|'R'] anchor (only at save depth 0),
//           ['R',x,y,w,h,p] rect, ['O',cx,cy,rx,ry,p] oval,
//           ['P',pathIndex,p] path, ['I',iconName,p] icon (512-unit box),
//           ['C',pathIndex,evenOdd] clip,
//           ['D',p,[x,y,r, x,y,r, ...]] many circles filled with one paint
(function (root) {
  const TAU = Math.PI * 2;
  const rnd = (v) => { const r = Math.round(v * 10) / 10; return Object.is(r, -0) ? 0 : r; };
  const rnd3 = (v) => Math.round(v * 1000) / 1000;

  // ---------- colours ----------
  function parseColor(c) {
    if (typeof c !== 'string') throw new Error('bad colour ' + c);
    c = c.trim();
    if (c[0] === '#') {
      let h = c.slice(1);
      if (h.length === 3 || h.length === 4) h = h.split('').map((x) => x + x).join('');
      const r = parseInt(h.slice(0, 2), 16), g = parseInt(h.slice(2, 4), 16), b = parseInt(h.slice(4, 6), 16);
      const a = h.length === 8 ? parseInt(h.slice(6, 8), 16) / 255 : 1;
      return [r, g, b, a];
    }
    const m = c.match(/^rgba?\(([^)]+)\)$/);
    if (m) {
      const p = m[1].split(',').map((s) => parseFloat(s));
      return [p[0], p[1], p[2], p.length > 3 ? p[3] : 1];
    }
    const named = { white: [255, 255, 255, 1], black: [0, 0, 0, 1], transparent: [0, 0, 0, 0] };
    if (named[c]) return named[c];
    throw new Error('bad colour ' + c);
  }
  function argb(c, alphaMul) {
    const [r, g, b, a] = parseColor(c);
    const A = Math.max(0, Math.min(255, Math.round(a * alphaMul * 255)));
    const cl = (v) => Math.max(0, Math.min(255, Math.round(v)));
    return ((A << 24) >>> 0) + (cl(r) << 16) + (cl(g) << 8) + cl(b);
  }

  // ---------- paths ----------
  class RecPath {
    constructor(src) {
      this.cmds = src instanceof RecPath ? src.cmds.map((c) => c.slice()) : [];
      this.cx = src ? src.cx : 0; this.cy = src ? src.cy : 0; this.sx = src ? src.sx : 0; this.sy = src ? src.sy : 0;
      this.has = src ? src.has : false; this.ovals = src ? src.ovals.slice() : [];
      this.circles = src ? src.circles.slice() : []; this.other = src ? src.other : false;
      if (typeof src === 'string') throw new Error('Path2D(string) is not supported; build the path');
    }
    addCircle(x, y, r) { this.circles.push([x, y, r]); this.moveTo(x + r, y); this.ellipse(x, y, r, r, 0, 0, TAU, false, true); }
    moveTo(x, y) { this.cmds.push(['M', x, y]); this.cx = this.sx = x; this.cy = this.sy = y; this.has = true; }
    lineTo(x, y) { if (!this._circ) this.other = true; if (!this.has) return this.moveTo(x, y); this.cmds.push(['L', x, y]); this.cx = x; this.cy = y; }
    quadraticCurveTo(a, b, x, y) { this.other = true; if (!this.has) this.moveTo(a, b); this.cmds.push(['Q', a, b, x, y]); this.cx = x; this.cy = y; }
    bezierCurveTo(a, b, c, d, x, y) { if (!this._circ) this.other = true; if (!this.has) this.moveTo(a, b); this.cmds.push(['C', a, b, c, d, x, y]); this.cx = x; this.cy = y; }
    closePath() { if (!this.has) return; this.cmds.push(['Z']); this.cx = this.sx; this.cy = this.sy; }
    rect(x, y, w, h) { this.other = true; this.moveTo(x, y); this.lineTo(x + w, y); this.lineTo(x + w, y + h); this.lineTo(x, y + h); this.closePath(); this.moveTo(x, y); }
    roundRect(x, y, w, h, r) {
      r = Math.min(typeof r === 'number' ? r : (r && r[0]) || 0, Math.abs(w) / 2, Math.abs(h) / 2);
      this.moveTo(x + r, y); this.lineTo(x + w - r, y); this.arc(x + w - r, y + r, r, -Math.PI / 2, 0);
      this.lineTo(x + w, y + h - r); this.arc(x + w - r, y + h - r, r, 0, Math.PI / 2);
      this.lineTo(x + r, y + h); this.arc(x + r, y + h - r, r, Math.PI / 2, Math.PI);
      this.lineTo(x, y + r); this.arc(x + r, y + r, r, Math.PI, Math.PI * 1.5); this.closePath();
    }
    arc(x, y, r, a0, a1, ccw) { this.ellipse(x, y, r, r, 0, a0, a1, ccw); }
    ellipse(x, y, rx, ry, rot, a0, a1, ccw, fromCircle) {
      if (!fromCircle) this.other = true;
      let sweep;
      if (!ccw && a1 - a0 >= TAU) sweep = TAU;
      else if (ccw && a0 - a1 >= TAU) sweep = -TAU;
      else if (!ccw) { sweep = (a1 - a0) % TAU; if (sweep < 0) sweep += TAU; }
      else { sweep = (a0 - a1) % TAU; if (sweep < 0) sweep += TAU; sweep = -sweep; }
      const full = Math.abs(sweep) >= TAU - 1e-9;
      const cosR = Math.cos(rot), sinR = Math.sin(rot);
      const pt = (t) => { const ex = rx * Math.cos(t), ey = ry * Math.sin(t); return [x + ex * cosR - ey * sinR, y + ex * sinR + ey * cosR]; };
      const d = (t) => { const ex = -rx * Math.sin(t), ey = ry * Math.cos(t); return [ex * cosR - ey * sinR, ex * sinR + ey * cosR]; };
      const start = pt(a0);
      const wasEmpty = this.cmds.length === 0;
      this._circ = !!fromCircle;
      const same = this.has && Math.abs(this.cx - start[0]) < 1e-9 && Math.abs(this.cy - start[1]) < 1e-9;
      if (this.has) { if (!same) this.lineTo(start[0], start[1]); } else this.moveTo(start[0], start[1]);
      if (full && wasEmpty && rot === 0) this.ovals.push([x, y, rx, ry]);
      const n = Math.max(1, Math.ceil(Math.abs(sweep) / (Math.PI / 2) - 1e-9));
      const step = sweep / n, k = (4 / 3) * Math.tan(step / 4);
      let t = a0;
      for (let i = 0; i < n; i++) {
        const p0 = pt(t), p1 = pt(t + step), d0 = d(t), d1 = d(t + step);
        this.cmds.push(['C', p0[0] + k * d0[0], p0[1] + k * d0[1], p1[0] - k * d1[0], p1[1] - k * d1[1], p1[0], p1[1]]);
        t += step;
      }
      const end = pt(a0 + sweep); this.cx = end[0]; this.cy = end[1];
      this._circ = false;
    }
    // A path that is exactly one full axis-aligned ellipse can be drawn as an oval.
    asOval() {
      if (this.ovals.length !== 1) return null;
      const c = this.cmds;
      if (c.length < 5 || c[0][0] !== 'M') return null;
      for (let i = 1; i < c.length; i++) if (c[i][0] !== 'C' && !(c[i][0] === 'Z' && i === c.length - 1) && !(c[i][0] === 'M' && i === c.length - 1)) return null;
      return this.ovals[0];
    }
    toString() { return encodePath(this.cmds); }
  }

  // Compact path text: relative commands in tenths of a unit, minimal
  // separators. M/L/Q/C/Z only (lowercase = relative), SVG-compatible.
  function fmtTenths(t) {
    if (t === 0) return '0';
    const neg = t < 0, a = Math.abs(t), i = Math.floor(a / 10), f = a % 10;
    return (neg ? '-' : '') + (i ? String(i) : '') + (f ? '.' + f : (i ? '' : '0'));
  }
  function encodePath(cmds) {
    let out = '', cx = 0, cy = 0, sx = 0, sy = 0, last = '';
    const T = (v) => Math.round(v * 10);
    const nums = (arr) => { let s = ''; for (const n of arr) { const f = fmtTenths(n); if (s && !(f[0] === '-' || (f[0] === '.' && /\.\d*$/.test(s)))) s += ' '; s += f; } return s; };
    const list = cmds.slice(); while (list.length && list[list.length - 1][0] === 'M') list.pop();
    for (const c of list) {
      const op = c[0];
      if (op === 'Z') { out += 'z'; cx = sx; cy = sy; last = 'z'; continue; }
      const pts = []; for (let i = 1; i < c.length; i += 2) pts.push([T(c[i]), T(c[i + 1])]);
      const rel = []; for (const [x, y] of pts) rel.push(x - cx, y - cy);
      const letter = op.toLowerCase();
      const body = nums(rel);
      out += (letter === last && letter !== 'm' ? (body[0] === '-' ? '' : ' ') : letter) + body;
      last = letter;
      const [ex, ey] = pts[pts.length - 1]; cx = ex; cy = ey;
      if (op === 'M') { sx = ex; sy = ey; }
    }
    return out;
  }

  // ---------- gradients ----------
  class RecGradient {
    constructor(kind, args) { this.kind = kind; this.args = args; this.stops = []; }
    addColorStop(o, c) { this.stops.push([o, c]); }
  }

  // ---------- the recording context ----------
  class Rec {
    constructor(opts = {}) {
      this.ops = []; this.paths = []; this.pathIdx = new Map(); this.paints = []; this.paintIdx = new Map();
      this.st = { fillStyle: '#000000', strokeStyle: '#000000', lineWidth: 1, lineCap: 'butt', lineJoin: 'miter', globalAlpha: 1, filter: 'none', globalCompositeOperation: 'source-over' };
      this.stack = []; this.m = [1, 0, 0, 1, 0, 0]; this.mstack = []; this.cur = new RecPath(); this.depth = 0; this.anchor = 'C';
      this.canvas = { width: opts.width || 1344, height: opts.height || 576 };
    }
    get fillStyle() { return this.st.fillStyle; } set fillStyle(v) { this.st.fillStyle = v; }
    get strokeStyle() { return this.st.strokeStyle; } set strokeStyle(v) { this.st.strokeStyle = v; }
    get lineWidth() { return this.st.lineWidth; } set lineWidth(v) { this.st.lineWidth = v; }
    get lineCap() { return this.st.lineCap; } set lineCap(v) { this.st.lineCap = v; }
    get lineJoin() { return this.st.lineJoin; } set lineJoin(v) { this.st.lineJoin = v; }
    get globalAlpha() { return this.st.globalAlpha; } set globalAlpha(v) { this.st.globalAlpha = v; }
    get filter() { return this.st.filter; } set filter(v) { this.st.filter = v; }
    get globalCompositeOperation() { return this.st.globalCompositeOperation; } set globalCompositeOperation(v) { this.st.globalCompositeOperation = v; }
    set font(v) { } set textAlign(v) { } set textBaseline(v) { }
    fillText() { throw new Error('text is not supported in scenes'); }
    strokeText() { throw new Error('text is not supported in scenes'); }
    setLineDash() { throw new Error('dashes are not supported in scenes'); }

    anchorTo(a) { if (this.depth !== 0) throw new Error('anchor inside save'); if (a !== this.anchor) { this.ops.push(['A', a]); this.anchor = a; } }
    save() { this.stack.push({ ...this.st }); this.mstack.push(this.m.slice()); this.ops.push(['S']); this.depth++; }
    restore() { if (!this.depth) throw new Error('restore without save'); this.st = this.stack.pop(); this.m = this.mstack.pop(); this.ops.push(['X']); this.depth--; }
    transform(a, b, c, d, e, f) {
      const m = this.m; this.m = [m[0] * a + m[2] * b, m[1] * a + m[3] * b, m[0] * c + m[2] * d, m[1] * c + m[3] * d, m[0] * e + m[2] * f + m[4], m[1] * e + m[3] * f + m[5]];
      const last = this.ops[this.ops.length - 1];
      this.ops.push(['T', rnd3(a), rnd3(b), rnd3(c), rnd3(d), rnd(e), rnd(f)]);
    }
    translate(x, y) { if (x || y) this.transform(1, 0, 0, 1, x, y); }
    scale(x, y) { this.transform(x, 0, 0, y, 0, 0); }
    rotate(a) { if (a) this.transform(Math.cos(a), Math.sin(a), -Math.sin(a), Math.cos(a), 0, 0); }
    setTransform() { throw new Error('setTransform is not supported; use save/restore'); }
    resetTransform() { throw new Error('resetTransform is not supported'); }

    beginPath() { this.cur = new RecPath(); }
    moveTo(x, y) { this.cur.moveTo(x, y); } lineTo(x, y) { this.cur.lineTo(x, y); }
    quadraticCurveTo(a, b, x, y) { this.cur.quadraticCurveTo(a, b, x, y); }
    bezierCurveTo(a, b, c, d, x, y) { this.cur.bezierCurveTo(a, b, c, d, x, y); }
    closePath() { this.cur.closePath(); }
    rect(x, y, w, h) { this.cur.rect(x, y, w, h); }
    roundRect(x, y, w, h, r) { this.cur.roundRect(x, y, w, h, r); }
    arc(x, y, r, a0, a1, ccw) { this.cur.arc(x, y, r, a0, a1, ccw); }
    ellipse(x, y, rx, ry, rot, a0, a1, ccw) { this.cur.ellipse(x, y, rx, ry, rot, a0, a1, ccw); }

    _pathRef(p) {
      const s = p.toString();
      if (!s) return -1;
      if (!this.pathIdx.has(s)) { this.pathIdx.set(s, this.paths.length); this.paths.push(s); }
      return this.pathIdx.get(s);
    }
    _scaleNow() { const m = this.m; return Math.sqrt(Math.abs(m[0] * m[3] - m[1] * m[2])) || 1; }
    _paint(kind, extra = {}) {
      const st = this.st, style = kind === 'f' ? st.fillStyle : st.strokeStyle, ga = st.globalAlpha;
      const p = { k: kind };
      if (style instanceof RecGradient) {
        const g = style;
        if (g.kind === 'lin') p.c = { lin: g.args.map(rnd) };
        else {
          const [x0, y0, r0, x1, y1, r1] = g.args;
          if (Math.abs(x0 - x1) > 1e-6 || Math.abs(y0 - y1) > 1e-6) throw new Error('only concentric radial gradients');
          p.c = { rad: [rnd(x1), rnd(y1), rnd(r1)] };
          if (r0 > 0) {
            const f = r0 / r1; const st0 = g.stops.slice().sort((a, b) => a[0] - b[0]);
            p.st = [[0, argb(st0[0][1], ga)], ...st0.map(([o, c]) => [rnd3(f + o * (1 - f)), argb(c, ga)])];
          }
        }
        if (!p.st) p.st = g.stops.slice().sort((a, b) => a[0] - b[0]).map(([o, c]) => [rnd3(o), argb(c, ga)]);
      } else p.c = argb(style, ga);
      if (kind === 's') { p.w = rnd3(st.lineWidth); if (st.lineCap !== 'butt') p.cap = st.lineCap; if (st.lineJoin !== 'miter') p.join = st.lineJoin; }
      const fm = /blur\(([\d.]+)px\)/.exec(st.filter || '');
      if (fm && parseFloat(fm[1]) > 0) p.b = rnd3(parseFloat(fm[1]) / this._scaleNow());
      const gco = st.globalCompositeOperation;
      if (gco === 'lighter') p.m = 'plus'; else if (gco === 'screen') p.m = 'screen'; else if (gco === 'multiply') p.m = 'multiply';
      else if (gco !== 'source-over') throw new Error('unsupported composite ' + gco);
      Object.assign(p, extra);
      const key = JSON.stringify(p);
      if (!this.paintIdx.has(key)) { this.paintIdx.set(key, this.paints.length); this.paints.push(p); }
      return this.paintIdx.get(key);
    }
    _visible(kind) {
      const style = kind === 'f' ? this.st.fillStyle : this.st.strokeStyle;
      if (this.st.globalAlpha <= 0) return false;
      if (style instanceof RecGradient) return style.stops.some(([, c]) => parseColor(c)[3] > 0);
      return parseColor(style)[3] > 0;
    }
    _draw(kind, a, b) {
      let path = this.cur, rule = 'nonzero';
      if (a instanceof RecPath) { path = a; if (typeof b === 'string') rule = b; } else if (typeof a === 'string') rule = a;
      if (!this._visible(kind)) return;
      if (!path.other && path.circles.length) {
        const paint = this._paint(kind, rule === 'evenodd' ? { eo: 1 } : {});
        this.ops.push(['D', paint, path.circles.flatMap(([x, y, r]) => [rnd(x), rnd(y), rnd(r)])]);
        return;
      }
      const oval = path.asOval();
      const paint = this._paint(kind, rule === 'evenodd' ? { eo: 1 } : {});
      if (oval) { this.ops.push(['O', rnd(oval[0]), rnd(oval[1]), rnd(oval[2]), rnd(oval[3]), paint]); return; }
      const ref = this._pathRef(path); if (ref < 0) return;
      this.ops.push(['P', ref, paint]);
    }
    fill(a, b) { this._draw('f', a, b); }
    stroke(a) { this._draw('s', a); }
    fillRect(x, y, w, h) { if (!this._visible('f')) return; this.ops.push(['R', rnd(x), rnd(y), rnd(w), rnd(h), this._paint('f')]); }
    strokeRect(x, y, w, h) { const p = new RecPath(); p.rect(x, y, w, h); this.stroke(p); }
    clip(a, b) {
      let path = this.cur, rule = 'nonzero';
      if (a instanceof RecPath) { path = a; if (typeof b === 'string') rule = b; } else if (typeof a === 'string') rule = a;
      this.ops.push(['C', this._pathRef(path), rule === 'evenodd' ? 1 : 0]);
    }
    // Draws a library icon (512 x 512 box) with the current fill style.
    icon(name, x, y, size, opts = {}) {
      if (!this._visible('f')) return;
      this.save();
      this.translate(x, y);
      if (opts.rot) this.rotate(opts.rot);
      const s = size / 512;
      this.scale(opts.flip ? -s : s, s);
      if (opts.flip) this.translate(-512, 0);
      this.ops.push(['I', name, this._paint('f')]);
      this.restore();
    }
    createLinearGradient(x0, y0, x1, y1) { return new RecGradient('lin', [x0, y0, x1, y1]); }
    createRadialGradient(x0, y0, r0, x1, y1, r1) { return new RecGradient('rad', [x0, y0, r0, x1, y1, r1]); }

    finish(meta = {}) {
      if (this.depth !== 0) throw new Error('unbalanced save/restore');
      // drop transforms right before a restore and empty save/restore pairs
      const ops = [];
      for (const op of this.ops) {
        if (op[0] === 'X' && ops.length && ops[ops.length - 1][0] === 'S') { ops.pop(); continue; }
        ops.push(op);
      }
      // A run of opaque, non-overlapping rectangles draws the same grouped by
      // paint, one path per paint.
      const opaque = (pi) => { const p = this.paints[pi]; if (p.b || p.m) return false; if (typeof p.c === 'number') return (p.c >>> 24) === 255; return p.st.every(([, c]) => (c >>> 24) === 255); };
      const overlaps = (run) => { const s = run.map((o) => [o[1], o[2], o[1] + o[3], o[2] + o[4]]).sort((a, b) => a[0] - b[0]); for (let i = 0; i < s.length; i++) for (let j = i + 1; j < s.length && s[j][0] < s[i][2] - 1e-6; j++) if (s[j][1] < s[i][3] - 1e-6 && s[i][1] < s[j][3] - 1e-6) return true; return false; };
      const merged = [];
      for (let i = 0; i < ops.length; i++) {
        const op = ops[i];
        if (op[0] === 'R' && opaque(op[5])) {
          let j = i; while (j + 1 < ops.length && ops[j + 1][0] === 'R' && opaque(ops[j + 1][5])) j++;
          let run = ops.slice(i, j + 1);
          if (run.length > 1 && overlaps(run)) { // fall back to same-paint neighbours only
            let k = i; while (k + 1 <= j && ops[k + 1][5] === op[5]) k++; run = ops.slice(i, k + 1); j = k;
          }
          if (run.length > 1) {
            const byPaint = new Map(); for (const o of run) { if (!byPaint.has(o[5])) byPaint.set(o[5], []); byPaint.get(o[5]).push(o); }
            for (const [pi, list] of byPaint) { if (list.length === 1) { merged.push(list[0]); continue; } const p = new RecPath(); for (const [, x, y, w, h] of list) { p.moveTo(x, y); p.lineTo(x + w, y); p.lineTo(x + w, y + h); p.lineTo(x, y + h); p.closePath(); } merged.push(['P', this._pathRef(p), pi]); }
            i = j; continue;
          }
        }
        merged.push(op);
      }
      ops.length = 0; ops.push(...merged);
      return { v: 1, ...meta, paths: this.paths, paints: this.paints, ops };
    }
  }

  const api = { Rec, RecPath, RecGradient, parseColor, argb, encodePath };
  if (typeof module !== 'undefined') module.exports = api; else Object.assign(root, api);
})(this);
