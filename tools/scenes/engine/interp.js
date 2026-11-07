// Draws a recorded scene (see rec.js) on a real canvas. This is the reference
// for lib/ui/art/scene_painter.dart: keep the two in step.
(function (root) {
  const REF_W = 1344, REF_H = 576;
  const NativePath2D = root.__NativePath2D || root.Path2D;
  function css(c) { const a = (c >>> 24) & 255, r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255; return `rgba(${r},${g},${b},${(a / 255).toFixed(4)})`; }
  function anchorDx(a, effW) { return a === 'L' ? 0 : a === 'R' ? effW - REF_W : (effW - REF_W) / 2; }

  function drawScene(ctx, scene, icons, pxW, pxH) {
    const k = pxH / REF_H, effW = pxW / k;
    const paths = scene.paths.map((s) => new NativePath2D(s));
    const iconCache = {};
    const style = (p) => {
      if (typeof p.c === 'number') return css(p.c);
      let g;
      if (p.c.lin) { const [x0, y0, x1, y1] = p.c.lin; g = ctx.createLinearGradient(x0, y0, x1, y1); }
      else { const [cx, cy, r] = p.c.rad; g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r); }
      for (const [o, c] of p.st) g.addColorStop(Math.max(0, Math.min(1, o)), css(c));
      return g;
    };
    const apply = (pi) => {
      const p = scene.paints[pi];
      const sc = (() => { const m = ctx.getTransform(); return Math.sqrt(Math.abs(m.a * m.d - m.b * m.c)); })();
      ctx.filter = p.b ? `blur(${p.b * sc}px)` : 'none';
      ctx.globalCompositeOperation = p.m === 'plus' ? 'lighter' : p.m === 'screen' ? 'screen' : p.m === 'multiply' ? 'multiply' : 'source-over';
      if (p.k === 's') { ctx.strokeStyle = style(p); ctx.lineWidth = p.w; ctx.lineCap = p.cap || 'butt'; ctx.lineJoin = p.join || 'miter'; ctx.miterLimit = 10; }
      else ctx.fillStyle = style(p);
      return p;
    };
    const paintShape = (pi, path) => { const p = apply(pi); if (p.k === 's') ctx.stroke(path); else ctx.fill(path, p.eo ? 'evenodd' : 'nonzero'); };

    ctx.save();
    ctx.scale(k, k);
    ctx.save(); ctx.translate(anchorDx('C', effW), 0);
    let depth = 0;
    for (const op of scene.ops) {
      switch (op[0]) {
        case 'S': ctx.save(); depth++; break;
        case 'X': ctx.restore(); depth--; break;
        case 'T': ctx.transform(op[1], op[2], op[3], op[4], op[5], op[6]); break;
        case 'A': ctx.restore(); ctx.save(); ctx.translate(anchorDx(op[1], effW), 0); break;
        case 'R': { const p = new NativePath2D(); p.rect(op[1], op[2], op[3], op[4]); paintShape(op[5], p); break; }
        case 'O': { const p = new NativePath2D(); p.ellipse(op[1], op[2], Math.abs(op[3]), Math.abs(op[4]), 0, 0, Math.PI * 2); paintShape(op[5], p); break; }
        case 'P': paintShape(op[2], paths[op[1]]); break;
        case 'I': { const ic = iconCache[op[1]] || (iconCache[op[1]] = new NativePath2D(icons[op[1]])); paintShape(op[2], ic); break; }
        case 'D': { const p = new NativePath2D(), d = op[2]; for (let j = 0; j < d.length; j += 3) { p.moveTo(d[j] + d[j + 2], d[j + 1]); p.arc(d[j], d[j + 1], d[j + 2], 0, Math.PI * 2); } paintShape(op[1], p); break; }
        case 'C': ctx.clip(paths[op[1]], op[2] ? 'evenodd' : 'nonzero'); break;
        default: throw new Error('unknown op ' + op[0]);
      }
    }
    while (depth-- > 0) ctx.restore();
    ctx.restore();
    ctx.restore();
    ctx.filter = 'none'; ctx.globalCompositeOperation = 'source-over';
  }
  root.drawScene = drawScene; root.SCENE_REF_W = REF_W; root.SCENE_REF_H = REF_H;
})(typeof window !== 'undefined' ? window : globalThis);
