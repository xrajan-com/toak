// Sports scenes.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

function shamiana(ctx, x, base, w, h, c1, c2) {
  // striped festival tent, open-fronted
  const roof = P2(); roof.moveTo(x - w / 2 - 4, base - h * 0.62); roof.lineTo(x, base - h); roof.lineTo(x + w / 2 + 4, base - h * 0.62); roof.closePath();
  fillPath(ctx, roof, rgba(c1));
  const st = P2(); for (let k = -3; k <= 3; k += 2) { st.moveTo(x, base - h); st.lineTo(x + k * w / 7, base - h * 0.62); st.lineTo(x + (k + 1) * w / 7, base - h * 0.62); st.closePath(); } fillPath(ctx, st, rgba(c2));
  const val = P2(); val.moveTo(x - w / 2 - 4, base - h * 0.62); for (let k = 0; k < 8; k++) { const x0 = x - w / 2 - 4 + k * (w + 8) / 8; val.quadraticCurveTo(x0 + (w + 8) / 16, base - h * 0.48, x0 + (w + 8) / 8, base - h * 0.62); } fillPath(ctx, val, rgba(c2));
  const poles = P2(); poles.rect(x - w / 2, base - h * 0.6, 1.4, h * 0.6); poles.rect(x + w / 2 - 1.4, base - h * 0.6, 1.4, h * 0.6); fillPath(ctx, poles, '#1a120e');
  rect(ctx, x - w / 2, base - h * 0.6, w, h * 0.6, rgba([0, 0, 0], 0.35));
}

TEMPLATES.polo = (ctx, R, o) => {
  const dark = '#14100c', grass = [70, 120, 50];
  sky(ctx, ['#2a2244', '#6a4a6a', '#d47a5a', '#f6b870', '#ffdc96'], 0, HORIZON);
  ground(ctx, [shade(grass, 0.1), shade(grass, -0.45), shade(grass, -0.8)]);
  glow(ctx, CX + 300, 70, 360, [255, 190, 110], 0.4, true);
  // the palace pavilion and its trees along the far side
  canopy(ctx, R, 300, 64, 280, 26, [70, 90, 60], [30, 44, 30]);
  canopy(ctx, R, 1060, 64, 300, 26, [70, 90, 60], [30, 44, 30]);
  const pal = P2(), pw = 300, pt = 40, px = CX;
  pal.rect(px - pw / 2, pt, pw, 44);
  for (let i = -2; i <= 2; i++) { const dx = px + i * 62, dw = i === 0 ? 34 : 20; pal.moveTo(dx - dw / 2, pt); pal.quadraticCurveTo(dx - dw / 2, pt - dw * 0.9, dx, pt - dw * 1.05); pal.quadraticCurveTo(dx + dw / 2, pt - dw * 0.9, dx + dw / 2, pt); pal.closePath(); pal.rect(dx - 0.8, pt - dw * 1.05 - 6, 1.6, 6); }
  fillPath(ctx, pal, lin(ctx, 0, pt - 40, 0, pt + 44, [[0, '#f6ece0'], [1, '#c8b49e']]));
  const ar = P2(); for (let x = px - pw / 2 + 12; x < px + pw / 2 - 10; x += 22) { ar.moveTo(x, pt + 40); ar.lineTo(x, pt + 22); ar.quadraticCurveTo(x + 7, pt + 12, x + 14, pt + 22); ar.lineTo(x + 14, pt + 40); ar.closePath(); }
  fillPath(ctx, ar, rgba([120, 80, 60], 0.75));
  rect(ctx, px - pw / 2, pt - 2, pw, 3, rgba([210, 160, 100]));
  // spectators under shamianas on the flanks
  for (const [x, c1, c2] of [[200, [220, 40, 50], [250, 220, 120]], [300, [250, 220, 120], [40, 120, 90]], [1040, [220, 40, 50], [250, 220, 120]], [1140, [40, 90, 160], [250, 240, 220]], [1235, [250, 220, 120], [220, 40, 50]]]) {
    shamiana(ctx, x, 86, 72, 40, c1, c2);
    const sp = P2(); for (let k = -3; k <= 3; k++) personPath(sp, x + k * 9, 86, 16); fillPath(ctx, sp, rgba([20, 16, 14], 0.9));
  }
  // boards along the field
  rect(ctx, -20, 84, SW + 40, 3, rgba([245, 240, 230]));
  horizonHaze(ctx, 86, 5, [255, 230, 170], 0.4);
  // the match: players with mallets, the ball
  const player = (x, s, flip, swing) => {
    rimIcon(ctx, 'cavalry', x, 96, s, dark, [255, 220, 150], { flip, dx: flip ? 1.2 : -1.2 });
    const d = flip ? -1 : 1, hx2 = x + d * s * 0.05, hy = 96 - s * 0.62, a = swing;
    line(ctx, hx2, hy, hx2 + d * Math.cos(a) * s * 0.75, hy + Math.sin(a) * s * 0.75, dark, 1.1);
    const mx = hx2 + d * Math.cos(a) * s * 0.75, my = hy + Math.sin(a) * s * 0.75; line(ctx, mx - d * 3.5, my + 1, mx + d * 3.5, my - 1, dark, 2.4);
  };
  player(500, 54, false, 1.25); player(585, 50, false, 0.4);
  player(760, 52, true, 1.1); player(850, 56, true, -0.3);
  circle(ctx, 610, 94, 2.2, rgba([255, 255, 255]));
  for (const [x, flip] of [[360, false], [960, true]]) rimIcon(ctx, 'cavalry', x, 94, 36, dark, [255, 220, 150], { flip });
  // corners: goal posts with flags
  const goal = (x, c) => { const p = P2(); p.rect(x - 6, -10, 12, 360); fillPath(ctx, p, '#f4efe6'); const s = P2(); for (let y = -10; y < 350; y += 28) s.rect(x - 6, y, 12, 14); fillPath(ctx, s, rgba(c)); line(ctx, x, -10, x, 10, '#1a120e', 1.5); pennant(ctx, x, -6, 26, 14, c, { wave: 3 }); };
  anchored(ctx, 'L', () => { glow(ctx, 60, 200, 200, [255, 200, 120], 0.25, true); goal(70, [220, 40, 50]); goal(150, [220, 40, 50]); });
  anchored(ctx, 'R', () => { glow(ctx, SW - 60, 200, 200, [255, 200, 120], 0.25, true); goal(SW - 70, [40, 90, 170]); goal(SW - 150, [40, 90, 170]); });
  // mown grass under the rail
  for (let x = -40, k = 0; x < SW + 40; x += 80, k++) { const p = P2(); p.moveTo(x, F - 10); p.lineTo(x + 80, F - 10); p.lineTo(x + 110, SH); p.lineTo(x + 30, SH); p.closePath(); fillPath(ctx, p, rgba(k % 2 ? shade(grass, -0.15) : shade(grass, -0.35), 0.9)); }
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, 'rgba(0,0,0,0.1)'], [1, 'rgba(0,0,0,0.6)']]));
  finish(ctx, { split: 0.3, vignette: 0.42 });
};

// A sumo wrestler; pose 'crouch' (shikiri) or 'shiko' (leg raised). Feet at (x, y).
function rikishi(ctx, x, y, h, pose, c, o = {}) {
  const d = o.flip ? -1 : 1, s = h / 100, p = P2();
  if (pose === 'stand') {
    // front view: pear-shaped body, topknot, thick legs apart, arms out
    p.moveTo(x - 30 * s, y - 34 * s); p.bezierCurveTo(x - 34 * s, y - 62 * s, x - 22 * s, y - 80 * s, x, y - 80 * s); p.bezierCurveTo(x + 22 * s, y - 80 * s, x + 34 * s, y - 62 * s, x + 30 * s, y - 34 * s); p.quadraticCurveTo(x, y - 24 * s, x - 30 * s, y - 34 * s); p.closePath();
    p.moveTo(x + 11 * s, y - 88 * s); p.arc(x, y - 88 * s, 11 * s, 0, TAU);
    p.moveTo(x - 7 * s, y - 100 * s); p.quadraticCurveTo(x, y - 106 * s, x + 7 * s, y - 100 * s); p.lineTo(x + 3 * s, y - 96 * s); p.lineTo(x - 3 * s, y - 96 * s); p.closePath();
    p.moveTo(x - 26 * s, y - 36 * s); p.lineTo(x - 30 * s, y); p.lineTo(x - 12 * s, y); p.lineTo(x - 6 * s, y - 30 * s); p.closePath();
    p.moveTo(x + 26 * s, y - 36 * s); p.lineTo(x + 30 * s, y); p.lineTo(x + 12 * s, y); p.lineTo(x + 6 * s, y - 30 * s); p.closePath();
    for (const side of [-1, 1]) { p.moveTo(x + side * 24 * s, y - 72 * s); p.quadraticCurveTo(x + side * 40 * s, y - 60 * s, x + side * 38 * s, y - 40 * s); p.lineTo(x + side * 30 * s, y - 40 * s); p.quadraticCurveTo(x + side * 30 * s, y - 56 * s, x + side * 20 * s, y - 62 * s); p.closePath(); }
  } else if (pose === 'crouch') {
    p.ellipse(x, y - 34 * s, 30 * s, 22 * s, d * 0.35, 0, TAU);
    p.moveTo(x + d * 18 * s + 12 * s, y - 48 * s); p.arc(x + d * 18 * s, y - 48 * s, 12 * s, 0, TAU);
    p.moveTo(x + d * 30 * s, y - 50 * s); p.arc(x + d * 26 * s, y - 56 * s, 5 * s, 0, TAU);
    p.rect(x - 24 * s, y - 20 * s, 12 * s, 20 * s); p.rect(x + 6 * s, y - 20 * s, 12 * s, 20 * s);
    p.moveTo(x + d * 22 * s, y - 30 * s); p.lineTo(x + d * 34 * s, y); p.lineTo(x + d * 40 * s, y); p.lineTo(x + d * 30 * s, y - 34 * s); p.closePath();
  } else {
    p.ellipse(x, y - 52 * s, 24 * s, 30 * s, 0, 0, TAU);
    p.moveTo(x + 11 * s, y - 88 * s); p.arc(x, y - 88 * s, 11 * s, 0, TAU);
    p.moveTo(x + 5 * s, y - 100 * s); p.arc(x, y - 100 * s, 5 * s, 0, TAU);
    p.rect(x - d * 20 * s - 7 * s, y - 34 * s, 14 * s, 34 * s);
    p.moveTo(x + d * 14 * s, y - 42 * s); p.lineTo(x + d * 56 * s, y - 92 * s); p.lineTo(x + d * 64 * s, y - 84 * s); p.lineTo(x + d * 22 * s, y - 30 * s); p.closePath();
    p.moveTo(x - d * 18 * s, y - 70 * s); p.lineTo(x - d * 34 * s, y - 50 * s); p.lineTo(x - d * 28 * s, y - 46 * s); p.lineTo(x - d * 12 * s, y - 62 * s); p.closePath();
  }
  fillPath(ctx, p, c);
  // mawashi
  const m = P2();
  if (pose === 'stand') { m.moveTo(x - 30 * s, y - 40 * s); m.quadraticCurveTo(x, y - 30 * s, x + 30 * s, y - 40 * s); m.lineTo(x + 28 * s, y - 31 * s); m.quadraticCurveTo(x, y - 21 * s, x - 28 * s, y - 31 * s); m.closePath(); m.rect(x - 5 * s, y - 28 * s, 10 * s, 26 * s); }
  else if (pose === 'crouch') m.rect(x - 26 * s, y - 26 * s, 50 * s, 8 * s); else m.rect(x - 24 * s, y - 36 * s, 48 * s, 9 * s);
  fillPath(ctx, m, rgba(o.mawashi || [40, 30, 90]));
  if (pose === 'stand' && !o.noFringe) { const f = P2(); for (let k = -3; k <= 3; k++) { if (k === 0) continue; f.moveTo(x + k * 6 * s, y - 28 * s + Math.abs(k) * s); f.lineTo(x + k * 6.4 * s, y - 12 * s); } strokePath(ctx, f, rgba(o.mawashi || [40, 30, 90]), 1.6 * s); }
}

TEMPLATES.sumo = (ctx, R, o) => {
  const purple = [86, 40, 120], gold = [214, 175, 92], clay = [196, 160, 112];
  rect(ctx, 0, 0, SW, SH, '#0b0a0e');
  // tiers of the stands rising behind, crowd in boxes
  for (let row = 0; row < 7; row++) {
    const y = 88 - row * 12, a = 0.9 - row * 0.1;
    rect(ctx, -20, y - 12, SW + 40, 12, rgba(mix([60, 40, 30], [20, 16, 18], row / 7), 1));
    const heads = []; for (let x = -10; x < SW + 10; x += between(R, 7, 10)) heads.push([x, y - 7 + between(R, -1, 1), 3]);
    dots(ctx, heads, rgba([14, 12, 14], a));
    const box = P2(); for (let x = -20; x < SW + 20; x += 48) { box.moveTo(x, y - 12); box.lineTo(x, y); } strokePath(ctx, box, rgba([180, 120, 70], 0.25), 1, 'butt');
  }
  glow(ctx, CX, 40, 520, [255, 210, 150], 0.25, true);
  // nobori banners of the wrestlers on the flanks
  for (let x = 140, i = 0; x < SW - 140; x += 44, i++) { if (x > 420 && x < 930) continue; const c = [[200, 40, 50], [40, 90, 160], [240, 220, 120], [30, 120, 80]][i % 4]; line(ctx, x, 30, x, 92, '#1a1418', 1.2); rect(ctx, x + 1, 32, 12, 46, rgba(c)); rect(ctx, x + 5, 36, 4, 36, rgba([255, 255, 255], 0.5)); }
  // the hanging roof over the ring
  const rw = 380, ry = 2;
  const roof = P2(); roof.moveTo(CX - rw / 2 - 20, ry + 30); roof.lineTo(CX - rw / 2 + 30, ry - 10); roof.lineTo(CX + rw / 2 - 30, ry - 10); roof.lineTo(CX + rw / 2 + 20, ry + 30); roof.closePath();
  fillPath(ctx, roof, lin(ctx, 0, ry - 10, 0, ry + 30, [[0, '#3a2a1e'], [1, '#1a120c']]));
  strokePath(ctx, roof, rgba(gold, 0.8), 1.6);
  for (let k = 0; k < 6; k++) line(ctx, CX - rw / 2 + 40 + k * (rw - 80) / 5, ry - 10, CX - rw / 2 + 40 + k * (rw - 80) / 5, ry - 22, '#1a120c', 3);
  const val = P2(); val.moveTo(CX - rw / 2 - 20, ry + 30); for (let k = 0; k < 10; k++) { const x0 = CX - rw / 2 - 20 + k * (rw + 40) / 10; val.lineTo(x0, ry + 30); val.quadraticCurveTo(x0 + (rw + 40) / 20, ry + 52, x0 + (rw + 40) / 10, ry + 30); } val.closePath();
  fillPath(ctx, val, lin(ctx, 0, ry + 30, 0, ry + 52, [[0, rgba(purple)], [1, rgba(shade(purple, -0.3))]]));
  for (let k = 0; k < 10; k++) circle(ctx, CX - rw / 2 - 20 + (k + 0.5) * (rw + 40) / 10, ry + 37, 4, rgba([245, 240, 230], 0.9));
  // the four tassels: the two at the front show
  const tassel = (x, c) => { line(ctx, x, ry + 30, x, ry + 50, rgba(c), 2); const t = P2(); t.moveTo(x - 3, ry + 50); t.lineTo(x + 3, ry + 50); t.lineTo(x + 10, ry + 86); t.quadraticCurveTo(x, ry + 92, x - 10, ry + 86); t.closePath(); fillPath(ctx, t, lin(ctx, 0, ry + 50, 0, ry + 90, [[0, rgba(shade(c, 0.2))], [1, rgba(shade(c, -0.3))]])); circle(ctx, x, ry + 50, 5, rgba(c)); };
  tassel(CX - rw / 2 - 10, [40, 110, 90]); tassel(CX + rw / 2 + 10, [200, 40, 40]);
  // spotlights onto the ring
  for (const x of [CX - 140, CX + 140]) beam(ctx, x, ry + 40, Math.PI / 2, 120, 0.4, [255, 230, 190], 0.18, { blur: 4 });
  // the two wrestlers face off either side of the referee (the dealer)
  for (const [x, flip] of [[CX - 150, false], [CX + 150, true]]) { glow(ctx, x, 70, 80, [255, 220, 170], 0.35, true); rikishi(ctx, x + (flip ? -1.4 : 1.4), 92, 84, 'stand', rgba([255, 214, 170], 0.75), { flip, mawashi: [255, 214, 170], noFringe: true }); rikishi(ctx, x, 93, 84, 'stand', '#120e10', { flip, mawashi: flip ? [30, 30, 30] : [60, 40, 120] }); }
  // the ring's clay top and its straw edge
  rect(ctx, CX - 330, 89, 660, 6, lin(ctx, 0, 89, 0, 95, [[0, rgba(clay)], [1, rgba(shade(clay, -0.3))]]));
  // corners: shiko on the left, a salt throw on the right
  anchored(ctx, 'L', () => { glow(ctx, 90, 220, 220, [255, 210, 150], 0.3, true); rikishi(ctx, 110, 340, 230, 'shiko', '#0e0b0c', { mawashi: [140, 30, 40] }); });
  anchored(ctx, 'R', () => {
    glow(ctx, SW - 90, 220, 220, [255, 210, 150], 0.3, true);
    rikishi(ctx, SW - 110, 340, 230, 'shiko', '#0e0b0c', { flip: true, mawashi: [30, 30, 30] });
    const salt = []; for (let i = 0; i < 80; i++) { const a = between(R, -2.4, -1.2), r = between(R, 10, 80); salt.push([SW - 170 + Math.cos(a) * r, 120 + Math.sin(a) * r * 0.6, between(R, 0.8, 1.8)]); } dots(ctx, salt, rgba([255, 255, 255], 0.85));
  });
  // the dohyo floor under the rail: clay and the straw bale circle
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, rgba(shade(clay, -0.45))], [1, rgba(shade(clay, -0.8))]]));
  const bale = P2(); bale.ellipse(CX, F - 60, 760, 110, 0, 0, Math.PI); strokePath(ctx, bale, rgba([210, 190, 130], 0.8), 7);
  const bale2 = P2(); bale2.ellipse(CX, F - 60, 760, 110, 0, 0, Math.PI); strokePath(ctx, bale2, rgba([120, 100, 60], 0.6), 1.5);
  finish(ctx, { split: 0.25, vignette: 0.5 });
};
