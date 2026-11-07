// War & history scenes.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};

// small soldier with a spear, feet at (x, y)
function soldierPath(p, x, y, h, o = {}) {
  personPath(p, x, y, h);
  const s = h / 100, sx = x + (o.spearSide ?? 1) * 13 * s;
  p.rect(sx - 0.9 * s - 0.4, y - 128 * s, 1.8 * s + 0.8, 128 * s);
  p.moveTo(sx, y - 142 * s); p.lineTo(sx + 3.5 * s + 0.6, y - 126 * s); p.lineTo(sx - 3.5 * s - 0.6, y - 126 * s); p.closePath();
  if (o.helmet === 'kabuto') { p.moveTo(x - 9 * s, y - 92 * s); p.quadraticCurveTo(x, y - 106 * s, x + 9 * s, y - 92 * s); p.closePath(); p.moveTo(x - 7 * s, y - 100 * s); p.quadraticCurveTo(x - 10 * s, y - 112 * s, x - 3 * s, y - 104 * s); p.moveTo(x + 7 * s, y - 100 * s); p.quadraticCurveTo(x + 10 * s, y - 112 * s, x + 3 * s, y - 104 * s); }
  if (o.turban) { p.moveTo(x - 8 * s, y - 90 * s); p.quadraticCurveTo(x, y - 104 * s, x + 8 * s, y - 90 * s); p.closePath(); }
}
function howdah(ctx, x, y, s, cloth, dark) {
  // canopy seat on an elephant's back; (x, y) = middle of the back
  const p = P2();
  p.rect(x - 9 * s, y - 9 * s, 18 * s, 9 * s);
  p.moveTo(x - 11 * s, y - 9 * s); p.quadraticCurveTo(x, y - 24 * s, x + 11 * s, y - 9 * s); p.closePath();
  p.rect(x - 0.6, y - 30 * s, 1.2, 8 * s);
  fillPath(ctx, p, dark);
  const c = P2(); c.moveTo(x - 14 * s, y + 1 * s); c.lineTo(x + 14 * s, y + 1 * s); c.lineTo(x + 12 * s, y + 16 * s); c.lineTo(x - 12 * s, y + 16 * s); c.closePath();
  fillPath(ctx, c, rgba(cloth, 0.95));
  const t = P2(); for (let k = -10; k <= 10; k += 5) { t.moveTo(x + k * s, y + 16 * s); t.lineTo(x + k * s, y + 19 * s); } strokePath(ctx, t, rgba(shade(cloth, 0.3)), 1.2 * s);
}

TEMPLATES.rajputRamparts = (ctx, R, o) => {
  const saffron = o.banner || [255, 145, 30], red = [200, 36, 44], dark = '#120709', stone = o.stone || [96, 40, 52];
  sky(ctx, ['#120a26', '#2c1642', '#7a2a4c', '#d2583a', '#f6a24e'], 0, HORIZON);
  ground(ctx, ['#e48a44', '#6a2a1c', '#1c0b09']);
  glow(ctx, CX - 330, 84, 360, [255, 120, 40], 0.5, true);
  stars(ctx, R, 50, [CX + 140, 0, SW, 40], { bright: 3, alpha: 0.75 });
  // the hill and the fort along its crest, in mid-tone so the army reads in front
  const hill = ridgeFn(R, 16, [0.008, 0.021]);
  ridge(ctx, R, 78, 16, lin(ctx, 0, 50, 0, 90, [[0, rgba(shade(stone, -0.25))], [1, rgba(shade(stone, -0.45))]]), { fn: hill, bottom: 100 });
  const wins = rajputFort(ctx, R, -20, SW + 20, 66, 34, lin(ctx, 0, 20, 0, 80, [[0, rgba(shade(stone, 0.05))], [1, rgba(shade(stone, -0.3))]]), { towers: 10, merlon: 4 });
  dots(ctx, wins.map(([x, y]) => [x, y, 1.2]), rgba([255, 196, 100], 0.9));
  for (const [x, y] of wins.slice(0, 14)) glow(ctx, x, y, 8, [255, 150, 60], 0.22, true);
  // the great gate behind the dealer
  const gw = 140, gTop = 12, gx = CX;
  const gate = P2(); gate.rect(gx - gw / 2, gTop + 16, gw, 90);
  for (let mx = gx - gw / 2; mx < gx + gw / 2 - 4; mx += 9) { gate.rect(mx, gTop + 11, 5, 5); gate.moveTo(mx + 5, gTop + 11); gate.arc(mx + 2.5, gTop + 11, 2.5, 0, Math.PI, true); }
  fillPath(ctx, gate, lin(ctx, gx - gw / 2, 0, gx + gw / 2, 0, [[0, rgba(shade(stone, 0.12))], [0.5, rgba(shade(stone, -0.12))], [1, rgba(shade(stone, -0.4))]]));
  for (const s of [-1, 1]) {
    const bx = gx + s * (gw / 2 + 13), bp = P2(); bp.rect(bx - 16, gTop + 4, 32, 100);
    fillPath(ctx, bp, lin(ctx, bx - 16, 0, bx + 16, 0, [[0, rgba(shade(stone, 0.08))], [1, rgba(shade(stone, -0.45))]]));
    chhatri(ctx, bx, gTop + 4, 28, rgba(shade(stone, -0.2)));
    for (const yy of [gTop + 26, gTop + 50]) { glow(ctx, bx, yy, 10, [255, 160, 70], 0.35, true); rect(ctx, bx - 2, yy - 4, 4, 8, rgba([255, 205, 130], 0.95)); }
    line(ctx, bx, gTop - 26, bx, gTop - 6, dark, 1.4); pennant(ctx, bx, gTop - 26, s * 22, 10, saffron, { wave: 2 });
  }
  const arch = P2(); cuspedArch(arch, gx - 36, gx + 36, gTop + 26, 110);
  fillPath(ctx, arch, '#0a0405');
  ctx.save(); ctx.clip(arch); glow(ctx, gx, 98, 90, [255, 130, 50], 0.65); ctx.restore();
  strokePath(ctx, arch, rgba([255, 205, 150], 0.3), 2);
  for (const s of [-1, 1]) {
    const x = gx + s * 52, y = gTop + 22, bw = 14, bh = 38;
    const bp = P2(); bp.moveTo(x - bw / 2, y); bp.lineTo(x + bw / 2, y); bp.lineTo(x + bw / 2, y + bh); bp.lineTo(x, y + bh - 7); bp.lineTo(x - bw / 2, y + bh); bp.closePath();
    fillPath(ctx, bp, lin(ctx, x - bw / 2, 0, x + bw / 2, 0, [[0, rgba(saffron, 0.65)], [0.5, rgba(saffron, 1)], [1, rgba(saffron, 0.55)]]));
    circle(ctx, x, y + bh * 0.4, 3.2, rgba([255, 232, 170], 0.95));
  }
  // dust lit by the sunset, behind the army
  horizonHaze(ctx, 82, 12, [255, 170, 90], 0.55);
  // flanks: ranks of infantry with banners (low, under the pills)
  const ranks = P2();
  for (let x = 120; x < SW - 120; x += between(R, 9, 14)) { if (x > HERO_L[0] - 10 && x < HERO_R[1] + 10) continue; soldierPath(ranks, x, 93 + R() * 2, between(R, 20, 24), { turban: true, spearSide: R() < 0.5 ? -1 : 1 }); }
  fillPath(ctx, ranks, dark);
  for (const x of [190, 290, 380, 1000, 1100, 1210]) { line(ctx, x, 44, x, 92, dark, 1.4); pennant(ctx, x, 44, x < CX ? 15 : -15, 9, R() < 0.6 ? saffron : red, { wave: 1.5 }); }
  // hero zones: war elephants left of the dealer, cavalry right
  for (const [x, s] of [[505, 66], [590, 60]]) {
    rimIcon(ctx, 'elephant', x, 95, s, dark, [255, 170, 90]);
    const hy = 95 - s * 0.74, hp = P2(); hp.moveTo(x - s * 0.17, hy); hp.quadraticCurveTo(x - s * 0.07, hy - s * 0.24, x + s * 0.03, hy); hp.closePath(); hp.rect(x - s * 0.18, hy, s * 0.23, s * 0.05); fillPath(ctx, hp, dark);
    line(ctx, x - s * 0.07, hy - s * 0.2, x - s * 0.07, hy - s * 0.52, dark, 1.2); pennant(ctx, x - s * 0.07, hy - s * 0.52, 13, 8, saffron, { wave: 1.5 });
    const cloth = P2(); cloth.moveTo(x - s * 0.21, hy + s * 0.07); cloth.quadraticCurveTo(x - s * 0.07, hy + s * 0.03, x + s * 0.07, hy + s * 0.07); cloth.lineTo(x + s * 0.05, hy + s * 0.22); for (let k = 0; k < 4; k++) { const x0 = x + s * 0.05 - (k + 1) * s * 0.065; cloth.quadraticCurveTo(x0 + s * 0.032, hy + s * 0.27, x0, hy + s * 0.22); } cloth.closePath();
    fillPath(ctx, cloth, lin(ctx, 0, hy, 0, hy + s * 0.26, [[0, rgba(shade(red, -0.3), 0.9)], [1, rgba(red, 0.9)]])); strokePath(ctx, cloth, rgba([240, 190, 90], 0.7), 0.8);
  }
  for (const [x, s, a] of [[760, 52, -0.5], [835, 56, -0.35], [905, 50, -0.6]]) {
    rimIcon(ctx, 'cavalry', x, 95, s, dark, [255, 170, 90], { flip: true, dx: 1.4 });
    const lx = x - s * 0.05, ly = 95 - s * 0.62; line(ctx, lx, ly + 10, lx + Math.cos(a - Math.PI / 2) * 34, ly + Math.sin(a - Math.PI / 2) * 34, dark, 1.4);
    pennant(ctx, lx + Math.cos(a - Math.PI / 2) * 30, ly + Math.sin(a - Math.PI / 2) * 30, -11, 7, saffron);
  }
  // corners: a great war elephant and the royal standard; a lancer on the right
  anchored(ctx, 'L', () => {
    glow(ctx, 40, 150, 230, [255, 150, 60], 0.45, true);
    line(ctx, 170, -10, 170, 240, '#0b0507', 3.5);
    const fp = P2(); fp.moveTo(170, 4); fp.quadraticCurveTo(220, 24, 268, 10); fp.lineTo(256, 40); fp.quadraticCurveTo(214, 52, 170, 46); fp.closePath();
    fillPath(ctx, fp, lin(ctx, 170, 0, 268, 0, [[0, rgba(saffron, 0.95)], [1, rgba(shade(saffron, -0.25), 0.95)]]));
    rimIcon(ctx, 'elephant', 50, 330, 240, '#0b0507', [255, 170, 90], { dx: 1.2, dy: -0.6 });
  });
  anchored(ctx, 'R', () => {
    glow(ctx, SW - 30, 170, 230, [255, 150, 60], 0.38, true);
    rimIcon(ctx, 'cavalry', SW - 70, 320, 230, '#0b0507', [255, 170, 90], { flip: true, dx: -1.2, dy: -0.6 });
    line(ctx, SW - 190, 10, SW - 120, 250, '#0b0507', 3.5);
    pennant(ctx, SW - 190, 10, -34, 16, saffron, { wave: 3 });
  });
  // the field under the rail
  const fl = P2(); for (let i = 0; i < 40; i++) { const x = between(R, 0, SW), y = between(R, F + 8, SH); fl.moveTo(x, y); fl.lineTo(x + between(R, 10, 40), y); } strokePath(ctx, fl, rgba([0, 0, 0], 0.25), 1.2);
  glow(ctx, 140, F + 30, 240, [255, 130, 50], 0.25, true);
  finish(ctx, { split: 0.35, vignette: 0.45 });
};

// A coastal fort, cannons out, tall ships in the bay (for sea forts).
TEMPLATES.seaFortCannons = (ctx, R, o) => {
  const dark = '#070b10', sea = o.sea || [16, 52, 74];
  sky(ctx, o.sky || ['#0c1430', '#28325e', '#a64e5c', '#f19a5a'], 0, 110);
  sunDisc(ctx, CX - 260, 82, 20, [255, 120, 50], [255, 210, 120], 86);
  rect(ctx, 0, 84, SW, SH - 84, lin(ctx, 0, 84, 0, 150, [[0, rgba(sea)], [1, rgba(shade(sea, -0.6))]]));
  for (let i = 0; i < 26; i++) { const y = 86 + i * 1.6; rect(ctx, CX - 260 - 60 + i * 2, y, 120 - i * 4, 1, rgba([255, 200, 120], 0.5 - i * 0.017)); }
  for (const [x, s, flip] of [[CX - 150, 46, false], [CX + 200, 58, true], [CX + 330, 36, true]]) iconAt(ctx, 'galleon', x, 90, s, dark, { flip });
  for (const x of [CX - 400, CX + 430]) { for (let k = 0; k < 3; k++) glow(ctx, x + k * 6, 70, 18, [255, 160, 60], 0.3, true); }
  // ramparts along the foreground
  const wall = P2(); wall.moveTo(-20, 120); wall.lineTo(-20, 78); for (let x = -20; x < SW + 20; x += 26) { wall.lineTo(x, 78); wall.lineTo(x, 70); wall.lineTo(x + 14, 70); wall.lineTo(x + 14, 78); } wall.lineTo(SW + 20, 78); wall.lineTo(SW + 20, 120); wall.closePath();
  fillPath(ctx, wall, lin(ctx, 0, 70, 0, 120, [[0, '#2a2622'], [1, '#0a0908']]));
  for (const x of [CX - 300, CX - 190, CX + 190, CX + 300]) iconAt(ctx, 'cannon', x, 82, 30, dark, { flip: x > CX });
  anchored(ctx, 'L', () => { iconAt(ctx, 'cannon', 70, 300, 200, dark); });
  anchored(ctx, 'R', () => { iconAt(ctx, 'pirate-cannon', SW - 80, 300, 180, dark, { flip: true }); });
  rect(ctx, 0, F - 10, SW, SH - F + 10, lin(ctx, 0, F - 10, 0, SH, [[0, '#2a2420'], [1, '#0b0908']]));
  finish(ctx, { split: 0.4 });
};

// Japanese castle at dusk, samurai with nobori banners.
TEMPLATES.samuraiCastle = (ctx, R, o) => {
  const dark = '#0c0a10', plaster = '#efe9dd', red = [196, 32, 44], white = [238, 234, 222], black = [22, 20, 26];
  sky(ctx, ['#10142c', '#2a2a52', '#6e3c66', '#cc6a78', '#f3ac7c'], 0, HORIZON);
  ground(ctx, ['#d8907a', '#5a3040', '#140c14']);
  glow(ctx, CX - 340, 84, 360, [255, 130, 90], 0.45, true);
  stars(ctx, R, 46, [CX + 140, 0, SW, 40], { bright: 2, alpha: 0.7 });
  ridge(ctx, R, 80, 26, rgba([70, 52, 92]), { freqs: [0.005, 0.014], bottom: 100 });
  // stone walls with a white parapet wall on top
  const iw = P2(); iw.moveTo(-20, 110); iw.lineTo(-20, 72); for (let x = -20; x <= SW + 20; x += 140) { iw.quadraticCurveTo(x + 40, 70, x + 70, 62); iw.quadraticCurveTo(x + 100, 70, x + 140, 72); } iw.lineTo(SW + 20, 110); iw.closePath();
  fillPath(ctx, iw, lin(ctx, 0, 60, 0, 100, [[0, '#5a5462'], [1, '#221e28']]));
  // sakura groves on the walls
  for (const [x, w] of [[300, 110], [470, 70], [890, 70], [1080, 120]]) canopy(ctx, R, x, 60, w, 30, [255, 214, 228], [214, 132, 168], { sparkle: [255, 255, 255] });
  // the keep (right hero zone), a turret (left hero zone), the gate behind the dealer
  const lights = tenshu(ctx, 842, 78, 62, { wall: plaster });
  tenshu(ctx, 520, 78, 48, { wall: plaster, tiers: 2 });
  for (const [x, y] of lights) { glow(ctx, x, y, 7, [255, 180, 90], 0.35, true); rect(ctx, x - 1.4, y - 1.4, 2.8, 2.8, rgba([255, 214, 140], 0.95)); }
  const g = P2(); g.rect(CX - 58, 40, 116, 60); fillPath(ctx, g, lin(ctx, CX - 58, 0, CX + 58, 0, [[0, plaster], [1, rgba(shade(plaster, -0.4))]]));
  const gr = P2(); gr.moveTo(CX - 84, 44); gr.quadraticCurveTo(CX - 50, 40, CX - 44, 22); gr.lineTo(CX + 44, 22); gr.quadraticCurveTo(CX + 50, 40, CX + 84, 44); gr.lineTo(CX + 70, 48); gr.lineTo(CX - 70, 48); gr.closePath(); fillPath(ctx, gr, '#1c2228');
  for (const s of [-1, 1]) { const f = P2(); f.moveTo(CX + s * 44, 22); f.quadraticCurveTo(CX + s * 52, 12, CX + s * 46, 9); f.lineTo(CX + s * 40, 22); f.closePath(); fillPath(ctx, f, '#c9a24e'); }
  rect(ctx, CX - 34, 54, 68, 50, '#0a0806'); glow(ctx, CX, 96, 64, [255, 140, 70], 0.5, true);
  horizonHaze(ctx, 84, 10, [255, 180, 150], 0.45);
  // flanks: samurai ranks and their nobori
  const ranks = P2();
  for (let x = 120; x < SW - 120; x += between(R, 10, 15)) { if (x > HERO_L[0] - 10 && x < HERO_R[1] + 10) continue; soldierPath(ranks, x, 94 + R() * 2, between(R, 20, 24), { helmet: 'kabuto', spearSide: R() < 0.5 ? -1 : 1 }); }
  fillPath(ctx, ranks, dark);
  const nob = (x, top, h, c) => { line(ctx, x, top, x, 94, dark, 1.3); line(ctx, x, top + 1, x + h * 0.26, top + 1, dark, 1.1); rect(ctx, x + 0.6, top + 1, h * 0.25, h * 0.6, rgba(c)); circle(ctx, x + h * 0.125 + 0.6, top + 1 + h * 0.16, h * 0.07, rgba(c === red ? white : red)); };
  for (const [x, c] of [[170, red], [240, white], [320, black], [395, red], [1000, white], [1070, red], [1150, black], [1225, white]]) nob(x, 42, 40, c);
  // mounted samurai either side of the gate
  for (const [x, s, flip] of [[600, 50, false], [745, 50, true]]) rimIcon(ctx, 'cavalry', x, 96, s, dark, [255, 190, 150], { flip, dx: flip ? 1.4 : -1.4 });
  // corners: banners on the left, an archer on the right
  anchored(ctx, 'L', () => {
    glow(ctx, 30, 200, 200, [255, 140, 100], 0.35, true);
    for (const [x, c] of [[36, red], [88, white], [140, black]]) { line(ctx, x, -5, x, 300, '#08070a', 3); line(ctx, x, 4, x + 34, 4, '#08070a', 2.5); rect(ctx, x + 1.5, 4, 32, 130, rgba(c)); circle(ctx, x + 17.5, 36, 10, rgba(c === red ? white : red)); }
  });
  anchored(ctx, 'R', () => { glow(ctx, SW - 70, 200, 220, [255, 150, 110], 0.4, true); rimIcon(ctx, 'archer', SW - 95, 330, 250, '#08070a', [255, 190, 150], { flip: true, dx: -1, dy: -0.5 }); });
  const rake = P2(); for (let y = F + 10; y < SH; y += 7) { rake.moveTo(0, y); for (let x = 0; x <= SW; x += 40) { rake.quadraticCurveTo(x + 10, y - 2, x + 20, y); rake.quadraticCurveTo(x + 30, y + 2, x + 40, y); } } strokePath(ctx, rake, rgba([255, 255, 255], 0.06), 1);
  finish(ctx, { split: 0.35 });
};
