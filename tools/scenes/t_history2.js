// War & history, part 2: Indian forts by style, sea forts, Himalayan forts.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

// A fort crest in one of the Indian styles. Returns lit window spots.
function indianFortCrest(ctx, R, style, x0, x1, base, top, fill, accent) {
  const p = P2(), wins = [], tops = [];
  p.moveTo(x0, base);
  let x = x0;
  while (x < x1) {
    const w = between(R, 50, 120), t = top + between(R, 0, (base - top) * 0.4);
    p.lineTo(x, t);
    if (style === 'maratha') { p.lineTo(Math.min(x1, x + w), t); }
    else { const mW = 4; for (let mx = x; mx < Math.min(x1, x + w) - mW; mx += mW * 1.8) { p.lineTo(mx, t); p.lineTo(mx, t - mW * 0.8); if (style === 'sikh') p.lineTo(mx + mW, t - mW * 0.8); else p.arc(mx + mW / 2, t - mW * 0.8, mW / 2, Math.PI, 0); p.lineTo(mx + mW, t); } p.lineTo(Math.min(x1, x + w), t); }
    tops.push([x, Math.min(x1, x + w), t]);
    if (R() < 0.6) for (let k = 0; k < 2 + R() * 3; k++) wins.push([between(R, x + 6, x + w - 6), between(R, t + 5, base - 4)]);
    x += w;
  }
  p.lineTo(x1, base); p.closePath(); fillPath(ctx, p, fill);
  const n = 10;
  for (let i = 0; i < n; i++) {
    const tx = lerp(x0, x1, (i + 0.5) / n) + between(R, -20, 20), tw = between(R, 14, 24), tt = top - between(R, 4, 16);
    const q = P2();
    if (style === 'maratha' || style === 'deccan') { q.moveTo(tx - tw / 2, base); q.lineTo(tx - tw / 2, tt + tw * 0.3); q.quadraticCurveTo(tx, tt - tw * 0.1, tx + tw / 2, tt + tw * 0.3); q.lineTo(tx + tw / 2, base); q.closePath(); }
    else q.rect(tx - tw / 2, tt, tw, base - tt);
    fillPath(ctx, q, fill);
    if (style === 'rajput' || style === 'mughal') chhatri(ctx, tx, tt, tw * 0.9, fill);
    if (style === 'mughal' && i % 3 === 1) { const d = P2(); d.moveTo(tx - tw * 0.4, tt - tw * 0.45); d.quadraticCurveTo(tx - tw * 0.45, tt - tw * 1.1, tx, tt - tw * 1.25); d.quadraticCurveTo(tx + tw * 0.45, tt - tw * 1.1, tx + tw * 0.4, tt - tw * 0.45); d.closePath(); fillPath(ctx, d, rgba([236, 228, 214], 0.9)); }
    if (style === 'deccan' && i % 3 === 0) { const m = P2(); m.rect(tx - 2.2, tt - 26, 4.4, 26); m.moveTo(tx - 3.4, tt - 26); m.quadraticCurveTo(tx, tt - 34, tx + 3.4, tt - 26); m.closePath(); m.rect(tx - 3.4, tt - 14, 6.8, 1.6); fillPath(ctx, m, fill); }
    if (style === 'maratha' || style === 'sikh') { line(ctx, tx, tt - 2, tx, tt - 22, '#140806', 1.1); const f = P2(); f.moveTo(tx, tt - 22); f.lineTo(tx + 14, tt - 19); f.lineTo(tx + 9, tt - 16.5); f.lineTo(tx + 14, tt - 14); f.lineTo(tx, tt - 12); f.closePath(); fillPath(ctx, f, rgba(i % 2 && style === 'sikh' ? [30, 50, 140] : accent)); }
    if (R() < 0.7) wins.push([tx, tt + 10]);
  }
  return wins;
}

// War at an Indian fort. o.style: rajput | mughal | deccan | maratha | sikh.
TEMPLATES.indianWar = (ctx, R, o) => {
  const style = o.style || 'rajput', accent = o.banner || [255, 145, 30], red = o.red || [200, 36, 44], dark = '#120709';
  const stone = o.stone || { rajput: [96, 40, 52], mughal: [150, 52, 40], deccan: [88, 78, 84], maratha: [60, 52, 50], sikh: [120, 70, 50] }[style];
  skyPreset(ctx, o.sky || 'dusk');
  ground(ctx, o.ground || ['#e48a44', '#6a2a1c', '#1c0b09']);
  glow(ctx, CX - 330, 84, 360, [255, 120, 40], 0.5, true);
  stars(ctx, R, 50, [CX + 140, 0, SW, 40], { bright: 3, alpha: 0.75 });
  if (style === 'maratha') { // flat-topped Sahyadri plateaus
    mesas(ctx, R, 82, rgba(shade(stone, -0.35))); clouds(ctx, R, 46, 10, [255, 200, 180], { a: 0.25 });
  } else if (style === 'deccan') { // granite boulder hills
    const b = []; for (let i = 0; i < 70; i++) b.push([between(R, -20, SW + 20), between(R, 64, 92), between(R, 6, 16)]); dots(ctx, b, rgba(shade(stone, -0.45)));
  } else ridge(ctx, R, 78, 16, rgba(shade(stone, -0.4)), { freqs: [0.008, 0.021], bottom: 100 });
  const crestTop = style === 'maratha' ? 40 : 34, crestBase = style === 'maratha' ? 62 : 66;
  const wins = indianFortCrest(ctx, R, style, -20, SW + 20, crestBase, crestTop, lin(ctx, 0, 20, 0, 80, [[0, rgba(shade(stone, 0.05))], [1, rgba(shade(stone, -0.3))]]), accent);
  dots(ctx, wins.map(([x, y]) => [x, y, 1.2]), rgba([255, 196, 100], 0.9));
  for (const [x, y] of wins.slice(0, 14)) glow(ctx, x, y, 8, [255, 150, 60], 0.22, true);
  const layout = o.layout || 'gate';
  if (layout === 'gate') {
    // the gate behind the dealer
    const gw = 140, gTop = 12, gx = CX;
    const gate = P2(); gate.rect(gx - gw / 2, gTop + 16, gw, 90);
    for (let mx = gx - gw / 2; mx < gx + gw / 2 - 4; mx += 9) { gate.rect(mx, gTop + 11, 5, 5); gate.moveTo(mx + 5, gTop + 11); gate.arc(mx + 2.5, gTop + 11, 2.5, 0, Math.PI, true); }
    fillPath(ctx, gate, lin(ctx, gx - gw / 2, 0, gx + gw / 2, 0, [[0, rgba(shade(stone, 0.12))], [0.5, rgba(shade(stone, -0.12))], [1, rgba(shade(stone, -0.4))]]));
    for (const s of [-1, 1]) {
      const bx = gx + s * (gw / 2 + 13), bp = P2();
      if (style === 'maratha' || style === 'deccan') { bp.moveTo(bx - 17, gTop + 104); bp.lineTo(bx - 17, gTop + 12); bp.quadraticCurveTo(bx, gTop - 4, bx + 17, gTop + 12); bp.lineTo(bx + 17, gTop + 104); bp.closePath(); }
      else bp.rect(bx - 16, gTop + 4, 32, 100);
      fillPath(ctx, bp, lin(ctx, bx - 16, 0, bx + 16, 0, [[0, rgba(shade(stone, 0.08))], [1, rgba(shade(stone, -0.45))]]));
      if (style === 'rajput' || style === 'mughal') chhatri(ctx, bx, gTop + 4, 28, rgba(shade(stone, -0.2)));
      if (style === 'mughal') { const d = P2(); d.moveTo(bx - 11, gTop - 8); d.quadraticCurveTo(bx - 12, gTop - 24, bx, gTop - 28); d.quadraticCurveTo(bx + 12, gTop - 24, bx + 11, gTop - 8); d.closePath(); fillPath(ctx, d, rgba([240, 232, 218])); }
      for (const yy of [gTop + 26, gTop + 50]) { glow(ctx, bx, yy, 10, [255, 160, 70], 0.35, true); rect(ctx, bx - 2, yy - 4, 4, 8, rgba([255, 205, 130], 0.95)); }
      line(ctx, bx, gTop - 30, bx, gTop - 6, dark, 1.4); pennant(ctx, bx, gTop - 30, s * 22, 10, accent, { wave: 2 });
    }
    const arch = P2();
    if (style === 'maratha' || style === 'sikh') { arch.moveTo(gx - 34, 110); arch.lineTo(gx - 34, gTop + 50); arch.quadraticCurveTo(gx - 34, gTop + 26, gx, gTop + 22); arch.quadraticCurveTo(gx + 34, gTop + 26, gx + 34, gTop + 50); arch.lineTo(gx + 34, 110); arch.closePath(); }
    else cuspedArch(arch, gx - 36, gx + 36, gTop + 26, 110, style === 'mughal' || style === 'deccan' ? 0.45 : 0.55);
    fillPath(ctx, arch, '#0a0405');
    ctx.save(); ctx.clip(arch); glow(ctx, gx, 98, 90, [255, 130, 50], 0.65); ctx.restore();
    strokePath(ctx, arch, rgba([255, 205, 150], 0.3), 2);
    for (const s of [-1, 1]) {
      const x = gx + s * 52, y = gTop + 22, bw = 14, bh = 38;
      const bp = P2(); bp.moveTo(x - bw / 2, y); bp.lineTo(x + bw / 2, y); bp.lineTo(x + bw / 2, y + bh); bp.lineTo(x, y + bh - 7); bp.lineTo(x - bw / 2, y + bh); bp.closePath();
      const bc = s < 0 ? accent : (o.banner2 || accent);
      fillPath(ctx, bp, lin(ctx, x - bw / 2, 0, x + bw / 2, 0, [[0, rgba(bc, 0.65)], [0.5, rgba(bc, 1)], [1, rgba(bc, 0.55)]]));
      if (o.stripes) { const st = P2(); for (let k = 0; k < 4; k++) { st.moveTo(x - bw / 2, y + 6 + k * 8); st.quadraticCurveTo(x, y + 9 + k * 8, x + bw / 2, y + 5 + k * 8); } strokePath(ctx, st, rgba(o.stripes, 0.9), 2.2); }
      else circle(ctx, x, y + bh * 0.4, 3.2, rgba([255, 232, 170], 0.95));
    }
    if (o.rockets) { // Mysore's iron rockets streaking over the walls
      for (let i = 0; i < 9; i++) { const x0 = between(R, 380, 980), y0 = between(R, 4, 40), l = between(R, 50, 110), a = between(R, -0.45, -0.2); additive(ctx, () => { const p = P2(); p.moveTo(x0, y0); p.quadraticCurveTo(x0 - l * 0.5, y0 + l * a * 0.2, x0 - l, y0 - l * a); strokePath(ctx, p, lin(ctx, x0, y0, x0 - l, y0 - l * a, [[0, rgba([255, 230, 160], 0.9)], [0.3, rgba([255, 120, 40], 0.5)], [1, rgba([120, 120, 140], 0)]]), 1.6); }); glow(ctx, x0, y0, 8, [255, 200, 120], 0.7, true); }
    }
  } else if (layout === 'granite') { // a fortified granite hill behind the dealer (Golconda)
    const hill = P2(); hill.moveTo(CX - 300, 96); hill.quadraticCurveTo(CX - 150, 60, CX - 60, 18); hill.quadraticCurveTo(CX, 4, CX + 60, 18); hill.quadraticCurveTo(CX + 150, 60, CX + 300, 96); hill.closePath();
    fillPath(ctx, hill, lin(ctx, 0, 4, 0, 96, [[0, rgba(shade(stone, 0.05))], [1, rgba(shade(stone, -0.5))]]));
    const bl = []; for (let i = 0; i < 40; i++) { const x = between(R, CX - 260, CX + 260), top = 96 - (96 - 10) * Math.max(0, 1 - Math.abs(x - CX) / 280) * 0.95; bl.push([x, between(R, top + 6, 96), between(R, 3, 8)]); } dots(ctx, bl, rgba(shade(stone, -0.25)));
    const walls = P2(); for (const [y, hw] of [[30, 70], [50, 140], [70, 210]]) { walls.rect(CX - hw, y, hw * 2, 4); for (let x = CX - hw; x < CX + hw; x += 7) walls.rect(x, y - 3, 4, 3); }
    fillPath(ctx, walls, rgba(shade(stone, -0.15)));
    const top = P2(); top.rect(CX - 26, 0, 52, 16); for (let k = 0; k < 4; k++) { top.moveTo(CX - 22 + k * 13, 16); top.lineTo(CX - 22 + k * 13, 8); top.quadraticCurveTo(CX - 17.5 + k * 13, 2, CX - 13 + k * 13, 8); top.lineTo(CX - 13 + k * 13, 16); }
    ctx.fillStyle = rgba(shade(stone, -0.1)); ctx.fill(top, 'evenodd');
    const torches = []; for (let i = 0; i < 26; i++) { const t = i / 25, x = CX - 230 + t * 460, y = 92 - Math.sin(t * Math.PI) * 60 + Math.sin(t * 9) * 6; torches.push([x, y]); }
    for (const [x, y] of torches) { glow(ctx, x, y, 9, [255, 150, 60], 0.45, true); circle(ctx, x, y, 1.3, rgba([255, 220, 150])); }
    for (const s2 of [-1, 1]) { line(ctx, CX + s2 * 20, -10, CX + s2 * 20, 6, dark, 1.3); pennant(ctx, CX + s2 * 20, -10, s2 * 18, 9, accent, { wave: 2 }); }
  } else if (layout === 'river') { // the army crossing a great river below the fort (Attock on the Indus)
    rect(ctx, -20, 74, SW + 40, 26, lin(ctx, 0, 74, 0, 100, [[0, '#6a8aa0'], [1, '#2a3a4a']]));
    const rp = P2(); for (let i = 0; i < 80; i++) { const x = between(R, -20, SW), y = between(R, 76, 98); rp.moveTo(x, y); rp.lineTo(x + between(R, 8, 26), y); } strokePath(ctx, rp, rgba([255, 220, 180], 0.3), 0.8);
    reflection(ctx, R, CX - 330, 75, 98, [255, 180, 100], 60, 0.4);
    const g2 = P2(); g2.rect(CX - 60, 26, 120, 48); for (let x = CX - 60; x < CX + 60; x += 9) g2.rect(x, 21, 5, 5); fillPath(ctx, g2, lin(ctx, 0, 21, 0, 74, [[0, rgba(shade(stone, 0.1))], [1, rgba(shade(stone, -0.4))]]));
    for (const s2 of [-1, 1]) { const bx = CX + s2 * 74, bp = P2(); bp.moveTo(bx - 15, 74); bp.lineTo(bx - 15, 24); bp.quadraticCurveTo(bx, 12, bx + 15, 24); bp.lineTo(bx + 15, 74); bp.closePath(); fillPath(ctx, bp, rgba(shade(stone, -0.15))); line(ctx, bx, 14, bx, -6, dark, 1.3); pennant(ctx, bx, -6, s2 * 18, 9, s2 < 0 ? accent : (o.banner2 || accent)); }
    rect(ctx, CX - 18, 46, 36, 28, '#0a0405'); glow(ctx, CX, 66, 40, [255, 140, 60], 0.5, true);
  } else if (layout === 'cliff') { // a fort on a sheer basalt cliff (Raigad)
    const cl = P2(); cl.moveTo(CX - 330, 100); cl.lineTo(CX - 290, 40); cl.lineTo(CX - 250, 24); cl.lineTo(CX + 250, 22); cl.lineTo(CX + 300, 42); cl.lineTo(CX + 340, 100); cl.closePath();
    fillPath(ctx, cl, lin(ctx, 0, 22, 0, 100, [[0, rgba(shade(stone, 0.1))], [0.25, rgba(shade(stone, -0.25))], [1, rgba(shade(stone, -0.6))]]));
    const strata = P2(); for (let y = 34; y < 100; y += 9) { strata.moveTo(CX - 300 + (y - 34) * 0.4, y); strata.lineTo(CX + 300 - (y - 34) * 0.3, y + 1); } strokePath(ctx, strata, rgba([0, 0, 0], 0.25), 1.2, 'butt');
    const fw = P2(); fw.rect(CX - 250, 14, 500, 10); for (let x = CX - 250; x < CX + 250; x += 8) fw.rect(x, 11, 5, 3);
    for (const bx of [CX - 230, CX - 120, CX + 110, CX + 225]) { fw.moveTo(bx - 14, 24); fw.lineTo(bx - 14, 6); fw.quadraticCurveTo(bx, -4, bx + 14, 6); fw.lineTo(bx + 14, 24); fw.closePath(); }
    fillPath(ctx, fw, rgba(shade(stone, -0.05)));
    line(ctx, CX - 120, 0, CX - 120, -30, dark, 1.5); const bf = P2(); bf.moveTo(CX - 120, -28); bf.lineTo(CX - 90, -22); bf.lineTo(CX - 100, -18); bf.lineTo(CX - 90, -13); bf.lineTo(CX - 120, -10); bf.closePath(); fillPath(ctx, bf, rgba(accent));
    for (const x of [CX - 180, CX - 60, CX + 40, CX + 170]) { glow(ctx, x, 18, 10, [255, 160, 70], 0.4, true); rect(ctx, x - 1.5, 16, 3, 5, rgba([255, 210, 140])); }
    withBlur(ctx, 7, () => { for (let i = 0; i < 7; i++) oval(ctx, between(R, CX - 320, CX + 320), between(R, 54, 76), between(R, 40, 90), 7, rgba([230, 210, 220], 0.35)); });
  }
  horizonHaze(ctx, 82, 12, [255, 170, 90], 0.55);
  // infantry on the flanks
  const ranks = P2();
  for (let x = 120; x < SW - 120; x += between(R, 9, 14)) { if (x > HERO_L[0] - 10 && x < HERO_R[1] + 10) continue; soldierPath(ranks, x, 93 + R() * 2, between(R, 20, 24), { turban: true, spearSide: R() < 0.5 ? -1 : 1 }); }
  fillPath(ctx, ranks, dark);
  for (const x of [190, 290, 380, 1000, 1100, 1210]) { line(ctx, x, 44, x, 92, dark, 1.4); pennant(ctx, x, 44, x < CX ? 15 : -15, 9, R() < 0.6 ? accent : red, { wave: 1.5 }); }
  // hero zones: who fights left and right of the dealer
  const elephants = o.left === 'elephants' || (o.left == null && style !== 'maratha');
  const unit = (kind, zone, faceLeft) => {
    const [z0, z1] = zone, mid = (z0 + z1) / 2;
    if (kind === 'elephants') for (const [x, s] of [[lerp(z0, z1, 0.3), 66], [lerp(z0, z1, 0.78), 60]]) {
      rimIcon(ctx, 'elephant', x, 95, s, dark, [255, 170, 90], { flip: faceLeft, dx: faceLeft ? 1.4 : -1.4 });
      const hx = x + (faceLeft ? 0.07 : -0.07) * s, hy = 95 - s * 0.74, hp = P2(); hp.moveTo(hx - s * 0.1, hy); hp.quadraticCurveTo(hx, hy - s * 0.24, hx + s * 0.1, hy); hp.closePath(); hp.rect(hx - s * 0.11, hy, s * 0.22, s * 0.05); fillPath(ctx, hp, dark);
      line(ctx, hx, hy - s * 0.2, hx, hy - s * 0.52, dark, 1.2); pennant(ctx, hx, hy - s * 0.52, faceLeft ? -13 : 13, 8, accent, { wave: 1.5 });
      const cloth = P2(); cloth.moveTo(hx - s * 0.14, hy + s * 0.07); cloth.quadraticCurveTo(hx, hy + s * 0.03, hx + s * 0.14, hy + s * 0.07); cloth.lineTo(hx + s * 0.12, hy + s * 0.22); for (let k = 0; k < 4; k++) { const x0 = hx + s * 0.12 - (k + 1) * s * 0.06; cloth.quadraticCurveTo(x0 + s * 0.03, hy + s * 0.27, x0, hy + s * 0.22); } cloth.closePath();
      fillPath(ctx, cloth, lin(ctx, 0, hy, 0, hy + s * 0.26, [[0, rgba(shade(red, -0.3), 0.9)], [1, rgba(red, 0.9)]])); strokePath(ctx, cloth, rgba([240, 190, 90], 0.7), 0.8);
    }
    if (kind === 'cavalry') for (const [x, s, a] of [[lerp(z0, z1, 0.18), 52, -0.5], [lerp(z0, z1, 0.52), 56, -0.35], [lerp(z0, z1, 0.86), 50, -0.6]]) {
      rimIcon(ctx, 'cavalry', x, 95, s, dark, [255, 170, 90], { flip: faceLeft, dx: faceLeft ? 1.4 : -1.4 });
      const d = faceLeft ? -1 : 1, lx = x + d * s * 0.05, ly = 95 - s * 0.62, ex = lx + d * Math.cos(a - Math.PI / 2) * -34 * -1, ey = ly + Math.sin(a - Math.PI / 2) * 34;
      line(ctx, lx, ly + 10, lx - d * Math.cos(a - Math.PI / 2) * 34, ey, dark, 1.4);
      pennant(ctx, lx - d * Math.cos(a - Math.PI / 2) * 30, ly + Math.sin(a - Math.PI / 2) * 30, -d * 11, 7, accent);
    }
    if (kind === 'cannons') for (const [x, s] of [[lerp(z0, z1, 0.3), 46], [lerp(z0, z1, 0.8), 40]]) {
      iconAt(ctx, 'cannon', x, 95, s, dark, { flip: faceLeft });
      const mx = x + (faceLeft ? -1 : 1) * s * 0.5;
      withBlur(ctx, 6, () => { for (let k = 0; k < 4; k++) oval(ctx, mx + (faceLeft ? -1 : 1) * k * 12, 72 - k * 5, 14 + k * 5, 8 + k * 2, rgba([200, 190, 190], 0.35 - k * 0.06)); });
      glow(ctx, mx, 78, 18, [255, 210, 130], 0.8, true);
      const g = P2(); personPath(g, x + (faceLeft ? 1 : -1) * s * 0.55, 95, 24); fillPath(ctx, g, dark);
    }
    if (kind === 'rocketeers') for (let k = 0; k < 4; k++) {
      const x = lerp(z0, z1, (k + 0.5) / 4), g = P2(); personPath(g, x, 95, 26); fillPath(ctx, g, dark);
      const d = faceLeft ? -1 : 1, a = -0.9 - k * 0.08; line(ctx, x + d * 2, 75, x + d * Math.cos(a) * 40, 75 + Math.sin(a) * 40, dark, 1.3);
      glow(ctx, x + d * Math.cos(a) * 40, 75 + Math.sin(a) * 40, 9, [255, 190, 100], 0.8, true);
    }
  };
  unit(o.left || (elephants ? 'elephants' : 'cavalry'), HERO_L, false);
  unit(o.right || 'cavalry', HERO_R, true);
  if (layout === 'river') { rect(ctx, HERO_L[0] - 20, 88, HERO_R[1] - HERO_L[0] + 40, 10, lin(ctx, 0, 88, 0, 98, [[0, 'rgba(70,100,120,0.85)'], [1, 'rgba(40,60,80,0.95)']])); const sp = []; for (let x = HERO_L[0]; x < HERO_R[1]; x += 7) if (x < DEALER[0] || x > DEALER[1]) sp.push([x, 88 + between(R, -1, 1), 1.3]); dots(ctx, sp, rgba([255, 255, 255], 0.6)); }
  anchored(ctx, 'L', () => {
    glow(ctx, 40, 150, 230, [255, 150, 60], 0.45, true);
    line(ctx, 170, -10, 170, 240, '#0b0507', 3.5);
    const fp = P2(); fp.moveTo(170, 4); fp.quadraticCurveTo(220, 24, 268, 10); fp.lineTo(256, 40); fp.quadraticCurveTo(214, 52, 170, 46); fp.closePath();
    fillPath(ctx, fp, lin(ctx, 170, 0, 268, 0, [[0, rgba(accent, 0.95)], [1, rgba(shade(accent, -0.25), 0.95)]]));
    if (elephants) rimIcon(ctx, 'elephant', 50, 330, 240, '#0b0507', [255, 170, 90], { dx: 1.2, dy: -0.6 });
    else rimIcon(ctx, 'cavalry', 70, 330, 230, '#0b0507', [255, 170, 90], { dx: 1.2, dy: -0.6 });
  });
  anchored(ctx, 'R', () => {
    glow(ctx, SW - 30, 170, 230, [255, 150, 60], 0.38, true);
    if (o.cannon) iconAt(ctx, 'cannon', SW - 90, 330, 220, '#0b0507', { flip: true });
    else rimIcon(ctx, 'cavalry', SW - 70, 320, 230, '#0b0507', [255, 170, 90], { flip: true, dx: -1.2, dy: -0.6 });
    line(ctx, SW - 190, 10, SW - 120, 250, '#0b0507', 3.5);
    pennant(ctx, SW - 190, 10, -34, 16, o.banner2 || accent, { wave: 3 });
  });
  const fl = P2(); for (let i = 0; i < 40; i++) { const x = between(R, 0, SW), y = between(R, F + 8, SH); fl.moveTo(x, y); fl.lineTo(x + between(R, 10, 40), y); } strokePath(ctx, fl, rgba([0, 0, 0], 0.25), 1.2);
  glow(ctx, 140, F + 30, 240, [255, 130, 50], 0.25, true);
  finish(ctx, { split: 0.35, vignette: 0.45 });
};

// A sea fort under fire: ships in the bay, cannons on the ramparts.
// o.ships: 'galleon' | 'junk' | 'dhow' | 'mixed'; o.time: 'dusk' | 'night' | 'dawn';
// o.palms, o.lighthouse, o.peak ('sugarloaf' | 'volcano' | 'table'), o.flags [c1, c2].
TEMPLATES.seaFort = (ctx, R, o) => {
  const night = o.time === 'night', dark = night ? '#04060c' : '#0a0c12', sea = o.sea || (night ? [12, 26, 48] : [18, 58, 82]);
  skyPreset(ctx, o.sky || (night ? 'deepNight' : o.time === 'dawn' ? 'dawn' : 'dusk'));
  const H0 = 52; // the sea horizon, high, so the ships show above the ramparts
  sky(ctx, SKIES[o.sky || (night ? 'deepNight' : o.time === 'dawn' ? 'dawn' : 'dusk')], 0, H0);
  ground(ctx, [shade(sea, 0.15), shade(sea, -0.4), shade(sea, -0.75)], H0);
  if (night) { stars(ctx, R, 90, [0, 0, SW, 46], { bright: 3 }); moon(ctx, 980, 18, 8, { halo: 6 }); }
  else sunDisc(ctx, CX - 260, 46, 18, [255, 120, 50], [255, 210, 120], H0);
  // far coast and an optional landmark peak
  ridge(ctx, R, H0, 8, rgba(shade(sea, -0.5)), { freqs: [0.01, 0.03], bottom: H0 + 4 });
  if (o.peak === 'sugarloaf') { const p = P2(); p.moveTo(990, 54); p.quadraticCurveTo(1004, 6, 1026, 4); p.quadraticCurveTo(1050, 8, 1060, 54); p.closePath(); fillPath(ctx, p, rgba(shade(sea, -0.55))); }
  if (o.peak === 'volcano') { const p = P2(); p.moveTo(900, 54); p.lineTo(990, 12); p.lineTo(1010, 12); p.lineTo(1110, 54); p.closePath(); fillPath(ctx, p, rgba(shade(sea, -0.55))); withBlur(ctx, 8, () => oval(ctx, 1004, 2, 30, 10, rgba([140, 130, 140], 0.4))); }
  if (o.peak === 'table') { const p = P2(); p.moveTo(880, 54); p.lineTo(920, 22); p.lineTo(1060, 20); p.lineTo(1100, 54); p.closePath(); fillPath(ctx, p, rgba(shade(sea, -0.55))); }
  if (o.bridge) archBridge(ctx, 880, 1140, 46, 14, rgba(shade(sea, -0.6)));
  water(ctx, R, H0, 100, sea, { n: 50 });
  if (!night) reflection(ctx, R, CX - 260, H0 + 1, 76, [255, 190, 110], 50, 0.45); else reflection(ctx, R, 980, H0 + 1, 76, [200, 220, 255], 30, 0.3);
  // ships, with smoke and muzzle flashes when it is a battle
  const kind = o.ships || 'galleon';
  const ships = [[CX - 150, 50, false], [CX + 170, 58, true], [CX + 320, 40, true], [CX - 330, 36, false]];
  ships.forEach(([x, s, flip], i) => {
    const k = kind === 'mixed' ? (i % 2 ? 'junk' : 'galleon') : kind;
    const by = 72;
    if (k === 'junk') junk(ctx, x, by, s, dark, { flip, sail: o.sail });
    else if (k === 'dhow') dhow(ctx, x, by, s, dark, { flip, sail: o.sail });
    else iconAt(ctx, 'galleon', x, by + 2, s, dark, { flip });
    if (o.battle !== false) { withBlur(ctx, 5, () => oval(ctx, x + (flip ? -1 : 1) * s * 0.6, by - 8, s * 0.5, 6, rgba([200, 190, 190], 0.35))); glow(ctx, x + (flip ? -1 : 1) * s * 0.45, by - 8, 14, [255, 200, 120], 0.8, true); }
  });
  if (o.lighthouse) lighthouse(ctx, 1150, 80, 60, dark, { stripes: o.lighthouse === 'striped' ? [200, 200, 200] : null, beamAngle: -2.9 });
  // ramparts along the shore, cannons in the embrasures
  const wall = P2(); wall.moveTo(-20, 130); wall.lineTo(-20, 84);
  for (let x = -20; x < SW + 20; x += 26) { wall.lineTo(x, 84); wall.lineTo(x, 77); wall.lineTo(x + 14, 77); wall.lineTo(x + 14, 84); }
  wall.lineTo(SW + 20, 84); wall.lineTo(SW + 20, 130); wall.closePath();
  fillPath(ctx, wall, lin(ctx, 0, 77, 0, 110, [[0, o.wall || '#4a4038'], [1, '#0a0908']]));
  for (const x of [CX - 300, CX - 200, CX + 200, CX + 300]) { iconAt(ctx, 'cannon', x, 88, 34, dark, { flip: x > CX }); if (o.battle !== false) glow(ctx, x + (x > CX ? -18 : 18), 78, 12, [255, 210, 130], 0.6, true); }
  const crew = P2(); for (const x of [CX - 330, CX - 230, CX + 230, CX + 330, CX - 420, CX + 420]) personPath(crew, x, 86, 22, { armUp: R() < 0.3 ? 1 : 0 }); fillPath(ctx, crew, dark);
  // flags on the fort
  const fc = o.flags || [[200, 30, 40], [240, 230, 210]];
  for (const [x, i] of [[CX - 250, 0], [CX + 250, 1], [CX - 520, 1], [CX + 520, 0]]) { line(ctx, x, 40, x, 80, dark, 1.4); const f = P2(); f.rect(x, 40, 22, 13); fillPath(ctx, f, rgba(fc[i % fc.length])); if (fc[2]) rect(ctx, x, 44.3, 22, 4.4, rgba(fc[2])); }
  if (o.palms) { palm(ctx, R, 140, 86, 66, dark, { lean: 0.2 }); palm(ctx, R, 1210, 86, 70, dark, { lean: -0.2 }); }
  // corners: a great cannon and the flag
  anchored(ctx, 'L', () => { glow(ctx, 60, 200, 200, night ? [255, 170, 90] : [255, 150, 80], 0.3, true); iconAt(ctx, 'cannon', 80, 310, 210, dark); if (o.palms) palm(ctx, R, 30, 330, 260, dark, { lean: 0.25 }); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 200, 200, [255, 150, 80], 0.3, true); iconAt(ctx, 'pirate-cannon', SW - 90, 310, 190, dark, { flip: true }); line(ctx, SW - 160, -10, SW - 160, 240, dark, 3); const f = P2(); f.rect(SW - 160, 0, -70, 42); fillPath(ctx, f, rgba(fc[0])); if (fc[2]) rect(ctx, SW - 230, 14, 70, 14, rgba(fc[2])); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, o.floor || '#3a332c'], [1, '#0b0908']]));
  const cb = []; for (let x = 60; x < SW; x += 140) cb.push([x, F + 40, 7], [x + 14, F + 44, 7], [x + 7, F + 33, 7]); dots(ctx, cb, rgba([20, 18, 18]));
  finish(ctx, { split: 0.35 });
};

// A Himalayan fort under a great peak (Sikkim and the eastern hills).
TEMPLATES.himalayanFort = (ctx, R, o) => {
  const dark = '#0a0c12';
  skyPreset(ctx, 'dawn');
  ground(ctx, ['#c8a8a8', '#4a4a5a', '#121420']);
  // the great peak behind the dealer, lit pink by sunrise
  const pk = P2(); pk.moveTo(300, 86); pk.lineTo(520, 40); pk.lineTo(600, 12); pk.lineTo(650, 4); pk.lineTo(700, 18); pk.lineTo(760, 10); pk.lineTo(860, 46); pk.lineTo(1050, 86); pk.closePath();
  fillPath(ctx, pk, lin(ctx, 0, 4, 0, 86, [[0, '#ffe2d0'], [0.35, '#f0b4b0'], [1, '#6a6a8a']]));
  const sh = P2(); sh.moveTo(650, 4); sh.lineTo(700, 18); sh.lineTo(760, 10); sh.lineTo(860, 46); sh.lineTo(1050, 86); sh.lineTo(760, 86); sh.closePath(); fillPath(ctx, sh, rgba([80, 80, 120], 0.35));
  mountains(ctx, R, 88, 26, [60, 70, 96], { bottom: 100, snow: [230, 230, 245], snowLine: 0.8 });
  forestLine(ctx, R, 92, 12, rgba([24, 34, 40]), { pines: true });
  // the fort ruins on the ridge (left hero zone) with archers practising
  const fort = P2(); fort.rect(470, 62, 150, 30); for (let x = 470; x < 620; x += 12) fort.rect(x, 56, 7, 6); fort.rect(500, 44, 30, 18); fort.rect(570, 48, 26, 14);
  fillPath(ctx, fort, lin(ctx, 0, 44, 0, 92, [[0, '#5a4a48'], [1, '#1c1616']]));
  const archers = P2(); for (const x of [760, 800, 840]) personPath(archers, x, 93, 26); fillPath(ctx, archers, dark);
  for (const x of [760, 800, 840]) { const b = P2(); b.moveTo(x + 6, 67); b.quadraticCurveTo(x + 14, 75, x + 6, 84); strokePath(ctx, b, dark, 1.2); line(ctx, x + 6, 75.5, x + 20, 75.5, dark, 0.8); }
  // a target on the right
  for (const [r, c] of [[9, [240, 240, 230]], [6, [200, 40, 40]], [3, [240, 200, 60]]]) circle(ctx, 920, 80, r, rgba(c));
  // prayer-flag style bunting in plain colours across the strip
  const cols = [[40, 90, 200], [240, 240, 240], [220, 40, 40], [40, 160, 80], [250, 200, 40]];
  for (const [x0, x1, y] of [[100, 440, 30], [900, 1250, 34]]) { const w = P2(); w.moveTo(x0, y); w.quadraticCurveTo((x0 + x1) / 2, y + 18, x1, y); strokePath(ctx, w, rgba([40, 30, 30], 0.7), 0.8); for (let t = 0.04, i = 0; t < 0.97; t += 0.04, i++) { const x = lerp(x0, x1, t), yy = y + 18 * 2 * t * (1 - t) * 2 * 0.5 + 0.5; rect(ctx, x - 3, yy, 6, 8, rgba(cols[i % 5], 0.9)); } }
  anchored(ctx, 'L', () => { iconAt(ctx, 'pine-tree', 60, 330, 280, '#0c1418'); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 80, 200, 180, [255, 200, 180], 0.25, true); rimIcon(ctx, 'archer', SW - 90, 330, 240, '#0a0c12', [255, 210, 190], { flip: true }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#3a3a44'], [1, '#0c0c12']]));
  finish(ctx, { split: 0.3, vignette: 0.4 });
};
