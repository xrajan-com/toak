// Animal scenes.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

// Peacock perched at (x, y) (its feet), facing left or right, train hanging down.
function peacock(ctx, R, x, y, s, o = {}) {
  const dir = o.flip ? -1 : 1, trainLen = s * (o.train || 3.2);
  // train: a long tapering fan hanging down and back
  const tx = x - dir * s * 0.35, ty = y - s * 0.05;
  const train = P2(); train.moveTo(tx - dir * s * 0.05, ty - s * 0.12);
  train.quadraticCurveTo(tx - dir * s * 0.9, ty + trainLen * 0.4, tx - dir * s * 0.55, ty + trainLen);
  train.quadraticCurveTo(tx - dir * s * 0.1, ty + trainLen * 1.05, tx + dir * s * 0.2, ty + trainLen * 0.92);
  train.quadraticCurveTo(tx + dir * s * 0.05, ty + trainLen * 0.4, tx + dir * s * 0.1, ty);
  train.closePath();
  fillPath(ctx, train, lin(ctx, 0, ty, 0, ty + trainLen, [[0, rgba([30, 90, 70])], [0.5, rgba([40, 110, 60])], [1, rgba([110, 90, 30])]]));
  const eyes = [], rings = [], cores = [];
  for (let i = 0; i < 22; i++) {
    const t = 0.18 + R() * 0.8, w = s * (0.25 + t * 0.55), ex = tx - dir * s * 0.18 + (R() - 0.5) * w, ey = ty + trainLen * t;
    rings.push([ex, ey, s * 0.075]); eyes.push([ex, ey, s * 0.05]); cores.push([ex, ey, s * 0.025]);
  }
  dots(ctx, rings, rgba([210, 170, 60], 0.9)); dots(ctx, eyes, rgba([20, 120, 140], 0.95)); dots(ctx, cores, rgba([20, 30, 80], 0.95));
  // body and neck
  const b = P2(); b.ellipse(x - dir * s * 0.1, y - s * 0.22, s * 0.32, s * 0.2, dir * 0.35, 0, TAU); fillPath(ctx, b, lin(ctx, x - s * 0.4, 0, x + s * 0.4, 0, [[0, rgba([20, 60, 110])], [1, rgba([30, 90, 150])]]));
  const n = P2(); n.moveTo(x + dir * s * 0.08, y - s * 0.32); n.quadraticCurveTo(x + dir * s * 0.28, y - s * 0.55, x + dir * s * 0.16, y - s * 0.78); n.lineTo(x + dir * s * 0.26, y - s * 0.82); n.quadraticCurveTo(x + dir * s * 0.4, y - s * 0.5, x + dir * s * 0.22, y - s * 0.24); n.closePath();
  fillPath(ctx, n, rgba([24, 80, 170]));
  circle(ctx, x + dir * s * 0.22, y - s * 0.84, s * 0.08, rgba([24, 80, 170]));
  const bk = P2(); bk.moveTo(x + dir * s * 0.28, y - s * 0.87); bk.lineTo(x + dir * s * 0.4, y - s * 0.83); bk.lineTo(x + dir * s * 0.28, y - s * 0.8); bk.closePath(); fillPath(ctx, bk, rgba([60, 50, 40]));
  const cr = P2(); for (let k = -1; k <= 1; k++) { cr.moveTo(x + dir * s * 0.2, y - s * 0.9); cr.lineTo(x + dir * s * (0.2 + k * 0.06), y - s * 1.05); } strokePath(ctx, cr, rgba([24, 80, 170]), s * 0.015);
  dots(ctx, [-1, 0, 1].map((k) => [x + dir * s * (0.2 + k * 0.06), y - s * 1.06, s * 0.025]), rgba([40, 110, 190]));
  circle(ctx, x + dir * s * 0.24, y - s * 0.86, s * 0.018, rgba([255, 255, 255], 0.9));
  // legs onto the perch
  line(ctx, x - dir * s * 0.05, y - s * 0.06, x - dir * s * 0.02, y, rgba([90, 80, 70]), s * 0.03);
}

// A red-crowned crane. pose: 'stand' | 'dance' | 'bow'. (x, y) = feet.
function crane(ctx, x, y, h, pose = 'stand', o = {}) {
  const d = o.flip ? -1 : 1, white = o.white || [244, 246, 250], black = '#16161c';
  const legs = P2(); legs.moveTo(x - h * 0.04, y); legs.lineTo(x - d * h * 0.01, y - h * 0.46); legs.moveTo(x + h * 0.05, y); legs.lineTo(x + d * h * 0.02, y - h * 0.46); strokePath(ctx, legs, black, h * 0.022);
  const bx = x, by = y - h * 0.55;
  if (pose === 'dance') {
    for (const side of [-1, 1]) {
      const w = P2(); const sx = bx + side * h * 0.05, sy = by - h * 0.06;
      w.moveTo(sx, sy); w.quadraticCurveTo(sx + side * h * 0.25, sy - h * 0.55, sx + side * h * 0.62, sy - h * 0.42);
      for (let k = 0; k < 5; k++) { const t = k / 5; w.lineTo(sx + side * h * (0.62 - t * 0.1), sy - h * (0.42 - t * 0.38) + h * 0.06); w.lineTo(sx + side * h * (0.58 - t * 0.12), sy - h * (0.34 - t * 0.36)); }
      w.quadraticCurveTo(sx + side * h * 0.25, sy - h * 0.05, sx, sy + h * 0.04); w.closePath();
      fillPath(ctx, w, lin(ctx, sx, sy - h * 0.5, sx, sy, [[0, rgba(shade(white, -0.08))], [1, rgba(white)]]));
      const tip = P2(); tip.moveTo(sx + side * h * 0.62, sy - h * 0.42); for (let k = 0; k < 5; k++) { const t = k / 5; tip.lineTo(sx + side * h * (0.62 - t * 0.1), sy - h * (0.42 - t * 0.38) + h * 0.06); tip.lineTo(sx + side * h * (0.58 - t * 0.12), sy - h * (0.34 - t * 0.36)); } tip.lineTo(sx + side * h * 0.44, sy - h * 0.1); tip.quadraticCurveTo(sx + side * h * 0.5, sy - h * 0.3, sx + side * h * 0.62, sy - h * 0.42); tip.closePath();
      fillPath(ctx, tip, black);
    }
  }
  const body = P2(); body.ellipse(bx, by, h * 0.21, h * 0.12, d * (pose === 'bow' ? 0.5 : 0.12), 0, TAU); fillPath(ctx, body, lin(ctx, 0, by - h * 0.12, 0, by + h * 0.12, [[0, rgba(white)], [1, rgba(shade(white, -0.25))]]));
  const bustle = P2(); bustle.moveTo(bx - d * h * 0.12, by - h * 0.08); bustle.quadraticCurveTo(bx - d * h * 0.36, by - h * 0.02, bx - d * h * 0.3, by + h * 0.12); bustle.quadraticCurveTo(bx - d * h * 0.2, by + h * 0.06, bx - d * h * 0.08, by + h * 0.06); bustle.closePath(); fillPath(ctx, bustle, black);
  const hx2 = pose === 'bow' ? bx + d * h * 0.36 : bx + d * h * (pose === 'dance' ? 0.08 : 0.17), hy = pose === 'bow' ? by + h * 0.05 : by - h * (pose === 'dance' ? 0.5 : 0.44);
  const neck = P2(); neck.moveTo(bx + d * h * 0.14, by - h * 0.05); neck.quadraticCurveTo(bx + d * h * 0.28, by - h * 0.22, hx2, hy); strokePath(ctx, neck, black, h * 0.05);
  circle(ctx, hx2, hy, h * 0.035, black); circle(ctx, hx2 - d * h * 0.005, hy - h * 0.03, h * 0.02, rgba([214, 30, 40]));
  const beak = P2(); beak.moveTo(hx2 + d * h * 0.02, hy - h * 0.012); beak.lineTo(hx2 + d * h * 0.13, hy + h * (pose === 'dance' ? -0.04 : 0.01)); beak.lineTo(hx2 + d * h * 0.02, hy + h * 0.015); beak.closePath(); fillPath(ctx, beak, rgba([190, 180, 140]));
}

TEMPLATES.desertCaravan = (ctx, R, o) => {
  const dark = '#1c0d10';
  sky(ctx, ['#22143a', '#5c2a56', '#c45a44', '#f39c4c', '#ffd27c'], 0, HORIZON);
  ground(ctx, ['#e09048', '#7a3c22', '#20100c']);
  sunDisc(ctx, 540, 72, 25, [255, 120, 50], [255, 220, 130], 80);
  stars(ctx, R, 30, [CX + 200, 0, SW, 30], { bright: 1, alpha: 0.6 });
  const birds = P2(); for (const [bx, by, s] of [[760, 26, 5], [778, 20, 4], [792, 30, 4.5], [460, 18, 4]]) { birds.moveTo(bx - s, by - s * 0.4); birds.quadraticCurveTo(bx - s * 0.4, by - s * 0.6, bx, by); birds.quadraticCurveTo(bx + s * 0.4, by - s * 0.6, bx + s, by - s * 0.4); } strokePath(ctx, birds, rgba([40, 16, 24], 0.9), 1.2);
  // far dunes and a hill fort on the left flank
  ridge(ctx, R, 82, 12, rgba([150, 70, 80]), { freqs: [0.004, 0.011], bottom: 100 });
  rajputFort(ctx, R, 150, 330, 74, 62, rgba([120, 54, 70]), { towers: 3, merlon: 3 });
  // the main dune: its crest carries the caravan across the sun
  const crest = (x) => 82 - 8 * Math.exp(-Math.pow((x - 520) / 160, 2)) - 4 * Math.sin(x * 0.01);
  const dune = P2(); dune.moveTo(-20, 120); for (let x = -20; x <= SW + 20; x += 6) dune.lineTo(x, crest(x)); dune.lineTo(SW + 20, 120); dune.closePath();
  fillPath(ctx, dune, lin(ctx, 0, 70, 0, 100, [[0, '#b2582e'], [1, '#5a2414']]));
  const edge = P2(); edge.moveTo(-20, crest(-20)); for (let x = -20; x <= SW + 20; x += 6) edge.lineTo(x, crest(x)); strokePath(ctx, edge, rgba([255, 200, 120], 0.55), 1.4);
  // the caravan
  const lead = []; let prev = null;
  for (const [x, s] of [[420, 30], [462, 34], [505, 36], [550, 36], [596, 34]]) {
    const base = crest(x) + 1;
    rimIcon(ctx, 'camel', x, base, s, dark, [255, 190, 110], { dx: -1.2 });
    const rp = P2(); personPath(rp, x - s * 0.06, base - s * 0.62, s * 0.42); fillPath(ctx, rp, dark);
    const tb = P2(); tb.moveTo(x - s * 0.13, base - s * 0.98); tb.quadraticCurveTo(x - s * 0.06, base - s * 1.08, x + s * 0.01, base - s * 0.98); fillPath(ctx, tb, rgba([200, 40, 50]));
    if (prev) line(ctx, prev[0], prev[1], x - s * 0.36, base - s * 0.55, rgba([30, 14, 16], 0.8), 0.6);
    prev = [x + s * 0.38, base - s * 0.8];
  }
  const walker = P2(); personPath(walker, 640, crest(640) + 1, 22); fillPath(ctx, walker, dark);
  // a desert hamlet and its well on the right
  for (const [x, s] of [[770, 26], [812, 30], [905, 24]]) {
    const hut = P2(); hut.rect(x - s * 0.5, 86 - s * 0.6, s, s * 0.6); hut.moveTo(x - s * 0.64, 86 - s * 0.58); hut.lineTo(x, 86 - s * 1.25); hut.lineTo(x + s * 0.64, 86 - s * 0.58); hut.closePath();
    fillPath(ctx, hut, dark); rect(ctx, x - s * 0.12, 86 - s * 0.36, s * 0.24, s * 0.36, rgba([255, 170, 80], 0.9)); glow(ctx, x, 86 - s * 0.2, 18, [255, 150, 60], 0.35, true);
  }
  const wpath = P2(); personPath(wpath, 860, 87, 24, { armUp: 1 }); wpath.ellipse(866.5, 61, 4, 3, 0, 0, TAU); wpath.ellipse(866.5, 56, 3, 2.4, 0, 0, TAU); fillPath(ctx, wpath, dark);
  // a khejri tree
  const tree = P2(); tree.moveTo(1000, 88); tree.quadraticCurveTo(1004, 70, 996, 58); tree.lineTo(1000, 57); tree.quadraticCurveTo(1010, 68, 1006, 88); tree.closePath(); fillPath(ctx, tree, dark);
  canopy(ctx, R, 1000, 52, 70, 16, [70, 40, 30], [30, 14, 12], { n: 40 });
  // corners: a camel on the left, a peacock on the right
  anchored(ctx, 'L', () => {
    glow(ctx, 50, 150, 220, [255, 160, 70], 0.4, true);
    rimIcon(ctx, 'camel', 70, 330, 250, '#170a0c', [255, 190, 110], { dx: 1, dy: -0.5 });
    const sad = P2(); sad.moveTo(26, 168); sad.quadraticCurveTo(68, 150, 112, 166); sad.lineTo(108, 206); for (let k = 0; k < 6; k++) sad.quadraticCurveTo(104 - k * 14 + 7, 216, 96 - k * 14, 206); sad.closePath();
    fillPath(ctx, sad, lin(ctx, 0, 150, 0, 210, [[0, rgba([170, 26, 40])], [1, rgba([220, 50, 60])]])); strokePath(ctx, sad, rgba([255, 200, 90], 0.85), 1.6);
    dots(ctx, [[34, 190, 3], [56, 196, 3], [78, 194, 3], [98, 186, 3]], rgba([255, 214, 90]));
  });
  anchored(ctx, 'R', () => {
    glow(ctx, SW - 60, 150, 200, [255, 160, 80], 0.3, true);
    const br = P2(); br.moveTo(SW + 10, 150); br.quadraticCurveTo(SW - 60, 156, SW - 130, 140); strokePath(ctx, br, '#1a0c0a', 7);
    peacock(ctx, R, SW - 80, 150, 56, { flip: true, train: 3.2 });
  });
  const rip = P2(); for (let y = F + 8; y < SH; y += 9) { rip.moveTo(0, y); for (let x = 0; x <= SW; x += 60) rip.quadraticCurveTo(x + 30, y - 3 + Math.sin(x + y) * 2, x + 60, y); } strokePath(ctx, rip, rgba([255, 190, 120], 0.08), 1.2);
  glow(ctx, 120, F + 50, 240, [255, 140, 60], 0.18, true);
  finish(ctx, { split: 0.3, vignette: 0.45 });
};

TEMPLATES.cranesSnow = (ctx, R, o) => {
  sky(ctx, ['#18203e', '#3c4a78', '#8e76a0', '#dca6b0', '#f6d4c2'], 0, HORIZON);
  ground(ctx, ['#e6ecf6', '#6a789c', '#1a2036']);
  glow(ctx, CX - 300, 80, 320, [255, 190, 170], 0.35, true);
  stars(ctx, R, 30, [CX + 200, 0, SW, 26], { bright: 1, alpha: 0.5 });
  // snowy mountains
  const mf = ridgeFn(R, 34, [0.006, 0.019, 0.05]);
  ridge(ctx, R, 82, 34, lin(ctx, 0, 40, 0, 86, [[0, '#f2f4fa'], [0.5, '#b8c0dc'], [1, '#7a84aa']]), { fn: mf, bottom: 100 });
  ridge(ctx, R, 84, 14, rgba([110, 120, 160]), { freqs: [0.01, 0.03], bottom: 100 });
  // bare larches on the flanks
  const trees = P2();
  for (let x = 120; x < SW - 120; x += between(R, 14, 26)) {
    if (x > HERO_L[0] - 20 && x < HERO_R[1] + 20) continue;
    const h = between(R, 26, 44), base = 88;
    trees.moveTo(x, base); trees.lineTo(x, base - h);
    for (let k = 0.3; k < 0.95; k += 0.12) { const yy = base - h * k, l = h * (1 - k) * 0.35; trees.moveTo(x, yy); trees.lineTo(x - l, yy + l * 0.5); trees.moveTo(x, yy); trees.lineTo(x + l, yy + l * 0.5); }
  }
  strokePath(ctx, trees, rgba([40, 40, 60], 0.9), 1);
  // the snowfield the cranes stand on
  horizonHaze(ctx, 86, 6, [255, 255, 255], 0.35);
  crane(ctx, 520, 92, 62, 'dance');
  crane(ctx, 590, 92, 58, 'bow', { flip: true });
  crane(ctx, 770, 92, 56, 'stand', { flip: true });
  crane(ctx, 830, 93, 60, 'dance', { flip: true });
  crane(ctx, 905, 92, 50, 'stand');
  crane(ctx, 300, 90, 30, 'stand'); crane(ctx, 340, 90, 28, 'bow', { flip: true }); crane(ctx, 1040, 90, 30, 'stand', { flip: true });
  // falling snow
  const snow = [], big = [];
  for (let i = 0; i < 260; i++) snow.push([between(R, 0, SW), between(R, 0, SH), between(R, 0.5, 1.3)]);
  for (let i = 0; i < 26; i++) big.push([between(R, 0, SW), between(R, 0, SH), between(R, 1.8, 3)]);
  dots(ctx, snow, rgba([255, 255, 255], 0.7));
  withBlur(ctx, 1.2, () => dots(ctx, big, rgba([255, 255, 255], 0.5)));
  // corners: a crane on the left, a snowy pine on the right
  anchored(ctx, 'L', () => { glow(ctx, 40, 160, 180, [200, 190, 230], 0.25, true); crane(ctx, 20, 300, 190, 'stand', { white: [236, 238, 246] }); });
  anchored(ctx, 'R', () => {
    iconAt(ctx, 'pine-tree', SW - 80, 340, 300, '#101a22');
    const caps = []; for (let i = 0; i < 60; i++) { const yy = between(R, 60, 300), w = (yy - 40) * 0.42; caps.push([SW - 80 + between(R, -w, w), yy, between(R, 2, 5)]); } dots(ctx, caps, rgba([235, 240, 250], 0.9));
  });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#8a9ac0'], [0.3, '#4a5a80'], [1, '#141a2c']]));
  const sp = []; for (let i = 0; i < 80; i++) sp.push([between(R, 0, SW), between(R, F + 4, SH), 0.7]); dots(ctx, sp, rgba([235, 245, 255], 0.6));
  finish(ctx, { split: 0.3, vignette: 0.4 });
};
