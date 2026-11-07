// The first eight bars (November 2026 prototypes), ported to the scene kit.
var TEMPLATES = typeof TEMPLATES !== 'undefined' ? TEMPLATES : {};
var SHELF = 0.93, UPPER = 0.40;
function glowCircle(ctx, x, y, r, col, a) { ctx.fillStyle = rad(ctx, x, y, r, [[0, rgba(col, a)], [0.4, rgba(col, a * 0.35)], [1, rgba(col, 0)]]); ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fill(); }
function blurred(ctx, px, fn) { ctx.save(); ctx.filter = `blur(${px}px)`; fn(); ctx.restore(); }
function backlightStrip(ctx, x0, x1, y, hgt, col, a) { ctx.fillStyle = lin(ctx, 0, y - hgt, 0, y, [[0, rgba(col, 0)], [1, rgba(col, a)]]); ctx.fillRect(x0, y - hgt, x1 - x0, hgt); }
function pendant(ctx, x, top, len, sw, shade, light, style = 'dome') {
  ctx.strokeStyle = 'rgba(10,8,6,.9)'; ctx.lineWidth = Math.max(1, sw * .04); ctx.beginPath(); ctx.moveTo(x, top); ctx.lineTo(x, top + len); ctx.stroke();
  const y = top + len, sh = sw * .55;
  // light cone
  ctx.fillStyle = lin(ctx, 0, y, 0, y + sw * 4, [[0, rgba(light, .30)], [1, rgba(light, 0)]]);
  ctx.beginPath(); ctx.moveTo(x - sw * .4, y + sh * .9); ctx.lineTo(x - sw * 1.6, y + sw * 4); ctx.lineTo(x + sw * 1.6, y + sw * 4); ctx.lineTo(x + sw * .4, y + sh * .9); ctx.fill();
  glowCircle(ctx, x, y + sh, sw * 1.5, light, .55);
  ctx.fillStyle = lin(ctx, x - sw / 2, 0, x + sw / 2, 0, [[0, rgba(mix(shade, [0, 0, 0], .4), 1)], [.4, rgba(shade, 1)], [1, rgba(mix(shade, [0, 0, 0], .5), 1)]]);
  ctx.beginPath();
  if (style === 'dome') { ctx.moveTo(x - sw / 2, y + sh); ctx.quadraticCurveTo(x - sw / 2, y, x, y); ctx.quadraticCurveTo(x + sw / 2, y, x + sw / 2, y + sh); }
  else { ctx.moveTo(x - sw * .15, y); ctx.lineTo(x + sw * .15, y); ctx.lineTo(x + sw / 2, y + sh); ctx.lineTo(x - sw / 2, y + sh); }
  ctx.closePath(); ctx.fill();
  ctx.fillStyle = rgba(mix(light, [255, 255, 255], .5), .95); ctx.beginPath(); ctx.ellipse(x, y + sh, sw * .42, sw * .08, 0, 0, 7); ctx.fill();
}
function edison(ctx, x, top, len, r, light) {
  ctx.strokeStyle = 'rgba(10,8,6,.9)'; ctx.lineWidth = Math.max(1, r * .12); ctx.beginPath(); ctx.moveTo(x, top); ctx.lineTo(x, top + len); ctx.stroke();
  const y = top + len + r;
  glowCircle(ctx, x, y, r * 6, light, .45);
  ctx.fillStyle = '#2a2018'; ctx.fillRect(x - r * .35, top + len - r * .2, r * .7, r * .5);
  ctx.fillStyle = rgba(mix(light, [255, 255, 255], .2), .35); ctx.beginPath(); ctx.ellipse(x, y, r * .75, r, 0, 0, 7); ctx.fill();
  ctx.strokeStyle = rgba(mix(light, [255, 255, 255], .6), 1); ctx.lineWidth = Math.max(1, r * .14);
  ctx.beginPath(); ctx.moveTo(x - r * .3, y + r * .3); ctx.quadraticCurveTo(x, y - r * .5, x + r * .3, y + r * .3); ctx.stroke();
}
function neonPath(ctx, path, col, lw) {
  blurred(ctx, lw * 4, () => { ctx.strokeStyle = rgba(col, .9); ctx.lineWidth = lw * 3; ctx.stroke(path); });
  ctx.strokeStyle = rgba(col, 1); ctx.lineWidth = lw * 1.4; ctx.stroke(path);
  ctx.strokeStyle = rgba(mix(col, [255, 255, 255], .75), 1); ctx.lineWidth = lw * .55; ctx.stroke(path);
}

TEMPLATES.bar_speakeasy = (ctx, R, o) => {
  const w = SW, h = SH, B = 91, F = 457;
  ctx.fillStyle = '#2b1712'; ctx.fillRect(0, 0, w, h);
  const bh = B * .1, bw = bh * 2.6;
  for (let y = 0, row = 0; y < 300; y += bh, row++) for (let x = (row % 2) * -bw / 2; x < w; x += bw) {
    ctx.fillStyle = rgba(mix([92, 42, 30], [128, 64, 42], Math.floor(R() * 4) / 3), 1); ctx.fillRect(x + 1.5, y + 1.5, bw - 3, bh - 3);
  }
  ctx.fillStyle = rad(ctx, w / 2, B * .3, w * .6, [[0, 'rgba(255,170,80,.20)'], [1, 'rgba(0,0,0,.55)']]); ctx.fillRect(0, 0, w, h);
  const pal = { glass: [[120, 70, 30], [90, 60, 40], [60, 80, 50], [140, 90, 40]], liquid: [[190, 110, 30], [160, 80, 20], [210, 140, 50]], label: [[230, 215, 180], [40, 30, 25], [200, 170, 110]], cap: [[30, 20, 15], [150, 110, 50]] };
  backlightStrip(ctx, 0, w, B * UPPER, B * .28, [255, 170, 70], .55); backlightStrip(ctx, 0, w, B * SHELF, B * .5, [255, 170, 70], .6);
  bottleRow(ctx, R, 0, w, B * UPPER, B * .30, pal, { backlit: [255, 170, 80] }); shelf(ctx, 0, w, B * UPPER, B * .05, [70, 40, 25], [45, 25, 15]);
  bottleRow(ctx, R, 0, w, B * SHELF, B * .48, pal, { backlit: [255, 170, 80] }); shelf(ctx, 0, w, B * SHELF, B * .07, [70, 40, 25], [45, 25, 15]);
  for (const [x, l] of [[.31, .16], [.37, .26], [.63, .26], [.69, .16]]) edison(ctx, x * w, 0, B * l, B * .05, [255, 170, 70]);
  { const g = P2(); g.moveTo(w * .5 - B * .12, B * .1); g.lineTo(w * .5 + B * .12, B * .1); g.lineTo(w * .5, B * .3); g.closePath(); g.moveTo(w * .5, B * .3); g.lineTo(w * .5, B * .44); g.moveTo(w * .5 - B * .07, B * .44); g.lineTo(w * .5 + B * .07, B * .44); neonPath(ctx, g, [255, 160, 60], B * .012); }
  ctx.fillStyle = lin(ctx, 0, F, 0, h, [[0, '#3a2116'], [1, '#160b07']]); ctx.fillRect(0, F, w, h - F);
  ctx.fillStyle = '#c99a4b'; ctx.fillRect(0, F + (h - F) * .18, w, Math.max(2, B * .03));
  for (let x = 0; x < w; x += w / 9) { ctx.strokeStyle = 'rgba(0,0,0,.35)'; ctx.lineWidth = 2; ctx.strokeRect(x + 8, F + (h - F) * .3, w / 9 - 16, (h - F) * .6); }
  finish(ctx, { split: 0.3, vignette: .5 });
};

TEMPLATES.bar_tokyo = (ctx, R, o) => {
  const w = SW, h = SH, B = 91, F = 457;
  ctx.fillStyle = lin(ctx, 0, 0, 0, h, [[0, '#070a1c'], [1, '#03040c']]); ctx.fillRect(0, 0, w, h);
  for (let x = 0; x < w; x += w / 60) { ctx.fillStyle = 'rgba(255,255,255,.025)'; ctx.fillRect(x, 0, w / 120, h); }
  const pal = { glass: [[200, 230, 255], [150, 200, 230], [230, 230, 240], [90, 140, 120]], liquid: [[230, 240, 255], [255, 200, 220], [180, 230, 255]], label: [[255, 255, 255], [20, 20, 30], [230, 30, 80]], cap: [[20, 20, 30], [220, 40, 70]] };
  backlightStrip(ctx, 0, w, B * SHELF, B * .55, [0, 181, 200], .55); backlightStrip(ctx, 0, w, B * UPPER, B * .3, [255, 45, 149], .5);
  bottleRow(ctx, R, 0, w, B * UPPER, B * .3, pal, { backlit: [255, 120, 200], kinds: ['tall', 'gin', 'wine', 'round'] }); shelf(ctx, 0, w, B * UPPER, B * .04, [180, 220, 240], [40, 60, 80]);
  bottleRow(ctx, R, 0, w, B * SHELF, B * .48, pal, { backlit: [120, 230, 255], kinds: ['tall', 'gin', 'whisky', 'round'] }); shelf(ctx, 0, w, B * SHELF, B * .06, [180, 220, 240], [40, 60, 80]);
  for (const x of [.31, .69]) {
    const cx = x * w, cy = B * .3, r = B * .15;
    ctx.strokeStyle = '#111'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.moveTo(cx, 0); ctx.lineTo(cx, cy - r); ctx.stroke();
    glowCircle(ctx, cx, cy, r * 3, [255, 80, 40], .5);
    ctx.fillStyle = rad(ctx, cx, cy, r * 1.2, [[0, '#ffb070'], [.6, '#e8401c'], [1, '#7a1408']]); ctx.beginPath(); ctx.ellipse(cx, cy, r * .85, r, 0, 0, 7); ctx.fill();
    ctx.strokeStyle = 'rgba(80,10,0,.5)'; ctx.lineWidth = 1; for (let i = -2; i <= 2; i++) { ctx.beginPath(); ctx.ellipse(cx, cy + i * r * .35, r * .85 * Math.sqrt(1 - (i * .35) ** 2), r * .06, 0, 0, 7); ctx.stroke(); }
    ctx.fillStyle = '#1a0c06'; ctx.fillRect(cx - r * .45, cy - r - 2, r * .9, 4); ctx.fillRect(cx - r * .45, cy + r - 2, r * .9, 4);
  }
  { const g = P2(); g.moveTo(w * .42 - B * .1, B * .14); g.lineTo(w * .42 + B * .1, B * .14); g.lineTo(w * .42, B * .32); g.closePath(); g.moveTo(w * .42, B * .32); g.lineTo(w * .42, B * .42); neonPath(ctx, g, [255, 45, 149], B * .014); }
  const cx = w * .58, cy = B * .27, rr = B * .12;
  const p = new Path2D(); p.arc(cx, cy, rr, 0, 7); neonPath(ctx, p, [0, 181, 200], B * .014);
  const p2 = new Path2D(); p2.moveTo(cx - rr * .55, cy - rr * .55); p2.lineTo(cx + rr * .55, cy + rr * .55); p2.moveTo(cx + rr * .55, cy - rr * .55); p2.lineTo(cx - rr * .55, cy + rr * .55); neonPath(ctx, p2, [255, 45, 149], B * .014);
  ctx.fillStyle = lin(ctx, 0, F, 0, h, [[0, '#0d0f1f'], [1, '#020208']]); ctx.fillRect(0, F, w, h - F);
  const ul = new Path2D(); ul.moveTo(0, F + (h - F) * .2); ul.lineTo(w, F + (h - F) * .2); neonPath(ctx, ul, [255, 45, 149], B * .01);
  ctx.fillStyle = lin(ctx, 0, F + (h - F) * .2, 0, h, [[0, 'rgba(255,45,149,.25)'], [1, 'rgba(255,45,149,0)']]); ctx.fillRect(0, F + (h - F) * .2, w, h - F);
  finish(ctx, { split: 0.3, vignette: .45 });
};

TEMPLATES.bar_deco = (ctx, R, o) => {
  const w = SW, h = SH, B = 91, F = 457;
  ctx.fillStyle = '#0b0a08'; ctx.fillRect(0, 0, w, h);
  const fan = (cx, cy, fw, strong) => {
    ctx.save(); ctx.beginPath(); ctx.arc(cx, cy, fw * .62, Math.PI, 0); ctx.clip();
    ctx.fillStyle = lin(ctx, 0, cy - fw * .6, 0, cy, [[0, '#2a2112'], [1, '#14100a']]); ctx.fillRect(cx - fw, cy - fw, fw * 2, fw);
    ctx.strokeStyle = `rgba(214,175,92,${strong ? .9 : .6})`; ctx.lineWidth = strong ? 1.6 : 1.1;
    for (let a = 0; a <= 18; a++) { const t = Math.PI + a * Math.PI / 18; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.cos(t) * fw, cy + Math.sin(t) * fw); ctx.stroke(); }
    for (const rr of [.62, .5, .38, .26]) { ctx.lineWidth = rr === .62 ? 3 : 1.4; ctx.beginPath(); ctx.arc(cx, cy, fw * rr, Math.PI, 0); ctx.stroke(); }
    ctx.restore();
  };
  for (let x = B * .6; x < w + B; x += B * 1.2) fan(x, B * SHELF, B * 1.2, false);
  fan(w / 2, B * SHELF, B * 1.75, true);
  const pal = { glass: [[40, 70, 40], [30, 50, 30], [220, 210, 190]], liquid: [[240, 210, 120], [250, 230, 160]], label: [[214, 175, 92], [240, 235, 220], [20, 20, 20]], cap: [[214, 175, 92], [190, 150, 70]] };
  bottleRow(ctx, R, 0, w * .44, B * SHELF, B * .48, pal, { kinds: ['champagne', 'champagne', 'wine', 'decanter'], backlit: [255, 220, 150] });
  bottleRow(ctx, R, w * .56, w, B * SHELF, B * .48, pal, { kinds: ['champagne', 'champagne', 'wine', 'decanter'], backlit: [255, 220, 150] });
  shelf(ctx, 0, w, B * SHELF, B * .07, [214, 175, 92], [120, 90, 40]);
  for (const side of [-1, 1]) {
    const cx = w * .5 + side * w * .085, base = B * SHELF, g = B * .13;
    for (let row = 0; row < 3; row++) for (let i = 0; i <= 2 - row; i++) {
      const x = cx + (i - (2 - row) / 2) * g, y = base - row * g;
      ctx.strokeStyle = 'rgba(255,235,180,.95)'; ctx.lineWidth = 1.4; ctx.beginPath(); ctx.moveTo(x - g * .45, y - g * .8); ctx.quadraticCurveTo(x, y - g * .3, x + g * .45, y - g * .8); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(x, y - g * .45); ctx.lineTo(x, y - g * .05); ctx.moveTo(x - g * .25, y - g * .03); ctx.lineTo(x + g * .25, y - g * .03); ctx.stroke();
      ctx.fillStyle = 'rgba(250,220,130,.8)'; ctx.beginPath(); ctx.moveTo(x - g * .4, y - g * .75); ctx.quadraticCurveTo(x, y - g * .35, x + g * .4, y - g * .75); ctx.fill();
    }
  }
  for (const x of [.32, .68]) { glowCircle(ctx, x * w, B * .28, B * .45, [255, 210, 140], .55); ctx.fillStyle = '#d6af5c'; ctx.beginPath(); ctx.moveTo(x * w - B * .07, B * .38); ctx.lineTo(x * w + B * .07, B * .38); ctx.lineTo(x * w + B * .04, B * .16); ctx.lineTo(x * w - B * .04, B * .16); ctx.fill(); }
  ctx.fillStyle = lin(ctx, 0, F, 0, h, [[0, '#15120c'], [1, '#050403']]); ctx.fillRect(0, F, w, h - F);
  ctx.strokeStyle = 'rgba(214,175,92,.8)'; ctx.lineWidth = 2;
  const cy = F + (h - F) * .35, ch = (h - F) * .2;
  ctx.beginPath(); for (let x = 0; x < w; x += ch * 2) { ctx.moveTo(x, cy + ch); ctx.lineTo(x + ch, cy); ctx.lineTo(x + ch * 2, cy + ch); } ctx.stroke();
  ctx.fillStyle = '#d6af5c'; ctx.fillRect(0, F + (h - F) * .14, w, 3);
  finish(ctx, { split: 0.3, vignette: .45 });
};

TEMPLATES.bar_tiki = (ctx, R, o) => {
  const w = SW, h = SH, B = 91, F = 457;
  ctx.fillStyle = lin(ctx, 0, 0, 0, B, [[0, '#2a1446'], [.25, '#b23a5e'], [.45, '#ff8a3d'], [.62, '#ffc56b']]); ctx.fillRect(0, 0, w, B);
  ctx.fillStyle = '#05343c'; ctx.fillRect(0, B, w, h - B);
  glowCircle(ctx, w * .5, B * .62, B * 1.1, [255, 220, 120], .75);
  ctx.fillStyle = 'rgba(255,240,200,.95)'; ctx.beginPath(); ctx.arc(w * .5, B * .62, B * .22, Math.PI, 0); ctx.fill();
  ctx.fillStyle = lin(ctx, 0, B * .62, 0, B, [[0, '#0aa3b5'], [1, '#05697a']]); ctx.fillRect(0, B * .62, w, B * .4);
  for (let i = 0; i < 14; i++) { ctx.fillStyle = 'rgba(255,230,170,.55)'; ctx.fillRect(w * .5 - B * (.55 - i * .03), B * (.66 + i * .022), B * (1.1 - i * .06), 1.5); }
  const pal = { glass: [[140, 90, 40], [60, 90, 60], [180, 140, 80]], liquid: [[200, 120, 40], [230, 170, 60]], label: [[255, 230, 180], [200, 60, 40], [40, 120, 110]], cap: [[60, 40, 20]] };
  bottleRow(ctx, R, 0, w * .4, B * SHELF, B * .48, pal, { kinds: ['rum', 'rum', 'round', 'wine'] }); bottleRow(ctx, R, w * .6, w, B * SHELF, B * .48, pal, { kinds: ['rum', 'rum', 'round', 'wine'] });
  for (let x = 0; x < w; x += B * .16) { ctx.fillStyle = '#8a6430'; ctx.fillRect(x, B * SHELF, B * .13, B * .08); ctx.fillStyle = 'rgba(0,0,0,.25)'; ctx.fillRect(x + B * .06, B * SHELF, 1.5, B * .08); }
  for (const x of [.39, .61]) {
    const cx = x * w, base = B * SHELF, mh = B * .4, mw = B * .2;
    ctx.fillStyle = lin(ctx, cx - mw / 2, 0, cx + mw / 2, 0, [[0, '#5a3a18'], [.4, '#9a6a32'], [1, '#4a2e12']]); ctx.fillRect(cx - mw / 2, base - mh, mw, mh);
    ctx.fillStyle = '#2a1608'; ctx.fillRect(cx - mw * .32, base - mh * .7, mw * .22, mh * .1); ctx.fillRect(cx + mw * .1, base - mh * .7, mw * .22, mh * .1); ctx.fillRect(cx - mw * .3, base - mh * .38, mw * .6, mh * .14);
    ctx.fillStyle = '#3aa65a'; ctx.beginPath(); ctx.moveTo(cx + mw * .2, base - mh); ctx.quadraticCurveTo(cx + mw * .9, base - mh * 1.5, cx + mw * .4, base - mh * 1.25); ctx.fill();
    ctx.strokeStyle = '#ff5fa2'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(cx - mw * .2, base - mh); ctx.lineTo(cx - mw * .45, base - mh * 1.35); ctx.stroke();
  }
  for (let x = 0; x < w; x += 6) { const l = B * (.1 + R() * .08); ctx.strokeStyle = rgba(mix([150, 110, 50], [200, 160, 90], Math.floor(R() * 3) / 2), 1); ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x + (R() - .5) * 6, l); ctx.stroke(); }
  for (const [sx, dir] of [[0, 1], [w, -1]]) for (let i = 0; i < 7; i++) {
    const a = (dir > 0 ? .25 : Math.PI - .25) + dir * i * .16, len = B * (1.1 + R() * .7);
    ctx.save(); ctx.translate(sx, B * .3); ctx.rotate(a); ctx.fillStyle = '#0b2a14';
    ctx.beginPath(); ctx.moveTo(0, 0); ctx.quadraticCurveTo(len * .5, -B * .14, len, B * .05); ctx.quadraticCurveTo(len * .5, B * .03, 0, 0); ctx.fill();
    ctx.strokeStyle = '#0b2a14'; ctx.lineWidth = 2.2; for (let t = .15; t < 1; t += .06) { ctx.beginPath(); ctx.moveTo(len * t, -B * .03); ctx.lineTo(len * t + B * .05, B * .12); ctx.stroke(); }
    ctx.restore();
  }
  stringLights(ctx, w * .29, B * .1, w * .71, B * .1, B * .22, 16, [255, 200, 120], B * .022);
  ctx.fillStyle = lin(ctx, 0, F, 0, h, [[0, '#e6c48a'], [1, '#b08a52']]); ctx.fillRect(0, F, w, h - F);
  for (let x = 0; x < w; x += B * .12) { ctx.fillStyle = lin(ctx, x, 0, x + B * .1, 0, [[0, '#7a5426'], [.5, '#b4823e'], [1, '#6a461c']]); ctx.fillRect(x, F + (h - F) * .12, B * .1, (h - F) * .5); ctx.fillStyle = 'rgba(0,0,0,.3)'; ctx.fillRect(x, F + (h - F) * .3, B * .1, 2); }
  finish(ctx, { split: 0.3, vignette: .4 });
};

TEMPLATES.bar_rooftop = (ctx, R, o) => {
  const w = SW, h = SH, B = 91, F = 457;
  ctx.fillStyle = lin(ctx, 0, 0, 0, h, [[0, '#050b1e'], [.2, '#14204a'], [1, '#0a0f22']]); ctx.fillRect(0, 0, w, h);
  for (let i = 0; i < 70; i++) { ctx.fillStyle = `rgba(255,255,255,${(.3 + Math.floor(R() * 3) * .25).toFixed(2)})`; ctx.fillRect(R() * w, R() * B * .45, 1.3, 1.3); }
  const mx = w * .62, my = B * .2, mr = B * .1;
  glowCircle(ctx, mx, my, mr * 4, [200, 230, 255], .35);
  ctx.fillStyle = '#eef6ff'; ctx.beginPath(); ctx.arc(mx, my, mr, 0, 7); ctx.fill(); ctx.fillStyle = '#14204a'; ctx.beginPath(); ctx.arc(mx + mr * .4, my - mr * .2, mr * .9, 0, 7); ctx.fill();
  for (const [depth, col, winA] of [[0, '#18234a', .3], [1, '#0b1129', .75]]) {
    let x = -10; while (x < w) {
      const bw = B * (.2 + R() * .35), bh = B * (depth ? .35 + R() * .4 : .5 + R() * .4), top = B * .95 - bh;
      ctx.fillStyle = col; ctx.fillRect(x, top, bw, bh + 4);
      if (R() < .25) { ctx.fillRect(x + bw * .45, top - B * .12, bw * .1, B * .12); glowCircle(ctx, x + bw * .5, top - B * .12, B * .035, [255, 60, 60], .9); }
      for (let wy = top + 4; wy < B * .92; wy += B * .055) for (let wx = x + 3; wx < x + bw - 4; wx += B * .05) if (R() < .45) { ctx.fillStyle = `rgba(255,${200 + Math.floor(R() * 3) * 20},120,${(winA * (.5 + Math.floor(R() * 3) * .25)).toFixed(2)})`; ctx.fillRect(wx, wy, B * .022, B * .028); }
      x += bw + B * .012;
    }
  }
  ctx.fillStyle = 'rgba(160,220,255,.08)'; ctx.fillRect(0, B * .78, w, B * .22); ctx.fillStyle = 'rgba(200,230,255,.5)'; ctx.fillRect(0, B * .78, w, 2);
  for (let x = 0; x < w; x += B * .5) ctx.fillRect(x, B * .78, 2, B * .22);
  stringLights(ctx, w * .285, B * .04, w * .5, B * .04, B * .22, 9, [255, 210, 140], B * .02);
  stringLights(ctx, w * .5, B * .04, w * .765, B * .04, B * .22, 9, [255, 210, 140], B * .02);
  for (const x of [.38, .62]) { const cx = x * w, base = B * .78; ctx.fillStyle = 'rgba(220,240,255,.55)'; ctx.beginPath(); ctx.moveTo(cx - B * .05, base - B * .16); ctx.lineTo(cx + B * .05, base - B * .16); ctx.lineTo(cx, base - B * .08); ctx.fill(); ctx.fillRect(cx - .8, base - B * .08, 1.6, B * .07); ctx.fillStyle = 'rgba(255,90,140,.85)'; ctx.beginPath(); ctx.moveTo(cx - B * .038, base - B * .15); ctx.lineTo(cx + B * .038, base - B * .15); ctx.lineTo(cx, base - B * .1); ctx.fill(); }
  ctx.fillStyle = lin(ctx, 0, F, 0, h, [[0, '#3a2a1c'], [1, '#140d08']]); ctx.fillRect(0, F, w, h - F);
  for (let y = F; y < h; y += (h - F) * .14) { ctx.fillStyle = 'rgba(0,0,0,.35)'; ctx.fillRect(0, y, w, 2); }
  for (const x of [.04, .96]) { ctx.fillStyle = '#1c2a1c'; ctx.beginPath(); ctx.arc(x * w, F + (h - F) * .3, B * .35, Math.PI, 0); ctx.fill(); glowCircle(ctx, x * w, F + (h - F) * .4, B * .4, [255, 200, 120], .35); }
  finish(ctx, { split: 0.3, vignette: .45 });
};

TEMPLATES.bar_library = (ctx, R, o) => {
  const w = SW, h = SH, B = 91, F = 457;
  ctx.fillStyle = '#0f1f17'; ctx.fillRect(0, 0, w, h);
  const bay = B * 1.3;
  for (let x = 0; x < w; x += bay) {
    ctx.fillStyle = '#2a170c'; ctx.fillRect(x, 0, B * .07, h); ctx.fillStyle = 'rgba(255,200,140,.08)'; ctx.fillRect(x + B * .012, 0, B * .012, h);
    let bx = x + B * .09; while (bx < x + bay - B * .03) {
      const bwid = B * (.04 + R() * .035), bht = B * (.26 + R() * .1);
      ctx.fillStyle = rgba([[110, 24, 24], [20, 50, 30], [30, 40, 80], [120, 90, 40], [60, 30, 50], [40, 30, 20]][Math.floor(R() * 6)], 1);
      ctx.fillRect(bx, B * UPPER - bht, bwid, bht); ctx.fillStyle = 'rgba(214,175,92,.6)'; ctx.fillRect(bx, B * UPPER - bht * .8, bwid, 1.2); ctx.fillRect(bx, B * UPPER - bht * .25, bwid, 1.2);
      bx += bwid + .6; if (R() < .08) bx += B * .06;
    }
    shelf(ctx, x, x + bay, B * UPPER, B * .06, [90, 52, 26], [55, 30, 14]);
    bottleRow(ctx, R, x + B * .07, x + bay - B * .02, B * SHELF, B * .48, { glass: [[130, 80, 30], [70, 50, 30], [200, 190, 170]], liquid: [[180, 100, 30], [140, 70, 20]], label: [[230, 215, 180], [30, 20, 15]], cap: [[30, 20, 15], [200, 160, 80]] }, { kinds: ['whisky', 'decanter', 'whisky', 'round'], backlit: [255, 180, 90] });
    shelf(ctx, x, x + bay, B * SHELF, B * .07, [90, 52, 26], [55, 30, 14]);
  }
  // wall clock above the dealer
  const cx = w * .5, cy = B * .26, cr = B * .2;
  glowCircle(ctx, cx, cy, cr * 2, [255, 210, 140], .3);
  ctx.fillStyle = '#c99a4b'; ctx.beginPath(); ctx.arc(cx, cy, cr, 0, 7); ctx.fill();
  ctx.fillStyle = '#f2e6c8'; ctx.beginPath(); ctx.arc(cx, cy, cr * .86, 0, 7); ctx.fill();
  ctx.strokeStyle = '#2a170c'; for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2; ctx.lineWidth = i % 3 ? 1 : 2.2; ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * cr * .72, cy + Math.sin(a) * cr * .72); ctx.lineTo(cx + Math.cos(a) * cr * .82, cy + Math.sin(a) * cr * .82); ctx.stroke(); }
  ctx.lineWidth = 2.4; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + cr * .35, cy - cr * .3); ctx.stroke(); ctx.lineWidth = 1.6; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx - cr * .1, cy - cr * .6); ctx.stroke();
  for (const x of [.36, .64]) {
    const lx = x * w, y = B * SHELF;
    glowCircle(ctx, lx, y - B * .1, B * .5, [255, 210, 130], .5);
    ctx.fillStyle = '#c99a4b'; ctx.fillRect(lx - 1.8, y - B * .26, 3.6, B * .26); ctx.fillRect(lx - B * .07, y - 4, B * .14, 4);
    ctx.fillStyle = lin(ctx, 0, y - B * .36, 0, y - B * .24, [[0, '#2f8a4a'], [1, '#0d3a1e']]); ctx.beginPath(); ctx.moveTo(lx - B * .15, y - B * .23); ctx.quadraticCurveTo(lx, y - B * .42, lx + B * .15, y - B * .23); ctx.closePath(); ctx.fill();
  }
  ctx.fillStyle = lin(ctx, 0, F, 0, h, [[0, '#4a1d12'], [1, '#1c0905']]); ctx.fillRect(0, F, w, h - F);
  ctx.fillStyle = '#c99a4b'; ctx.fillRect(0, F + (h - F) * .14, w, 3);
  for (let x = B * .05; x < w; x += B * .07) { ctx.fillStyle = '#d9b468'; ctx.beginPath(); ctx.arc(x, F + (h - F) * .22, 2.2, 0, 7); ctx.fill(); }
  finish(ctx, { split: 0.3, vignette: .5 });
};

TEMPLATES.bar_montecarlo = (ctx, R, o) => {
  const w = SW, h = SH, B = 91, F = 457;
  ctx.fillStyle = lin(ctx, 0, 0, 0, h, [[0, '#d9cfbf'], [1, '#8f8576']]); ctx.fillRect(0, 0, w, h);
  for (let i = 0; i < 40; i++) { ctx.strokeStyle = `rgba(120,110,100,${.15 + R() * .2})`; ctx.lineWidth = .8 + R(); ctx.beginPath(); let x = R() * w, y = R() * B; ctx.moveTo(x, y); for (let k = 0; k < 5; k++) { x += (R() - .3) * B * .4; y += (R() - .5) * B * .2; ctx.lineTo(x, y); } ctx.stroke(); }
  ctx.fillStyle = 'rgba(30,20,10,.35)'; ctx.fillRect(0, 0, w, h);
  ctx.fillStyle = lin(ctx, 0, B * .45, 0, B * SHELF, [[0, 'rgba(250,240,220,.15)'], [1, 'rgba(250,240,220,.35)']]); ctx.fillRect(w * .2, B * .45, w * .6, B * (SHELF - .45));
  ctx.strokeStyle = '#c9a24e'; ctx.lineWidth = 3; ctx.strokeRect(w * .2, B * .45, w * .6, B * (SHELF - .45));
  const pal = { glass: [[230, 220, 200], [200, 190, 170]], liquid: [[190, 100, 30], [160, 70, 20]], label: [[214, 175, 92], [250, 245, 235]], cap: [[214, 175, 92]] };
  bottleRow(ctx, R, w * .21, w * .45, B * SHELF, B * .42, pal, { kinds: ['decanter', 'decanter', 'round', 'champagne'], backlit: [255, 200, 130] });
  bottleRow(ctx, R, w * .55, w * .79, B * SHELF, B * .42, pal, { kinds: ['decanter', 'decanter', 'round', 'champagne'], backlit: [255, 200, 130] });
  shelf(ctx, w * .18, w * .82, B * SHELF, B * .07, [214, 175, 92], [140, 105, 40]);
  for (const [x0, dir] of [[0, 1], [w, -1]]) {
    ctx.fillStyle = lin(ctx, x0, 0, x0 + dir * w * .2, 0, [[0, 'rgba(90,10,18,1)'], [.5, 'rgba(160,22,40,1)'], [1, 'rgba(58,5,10,1)']]);
    ctx.beginPath(); ctx.moveTo(x0, 0); ctx.lineTo(x0 + dir * w * .21, 0); ctx.quadraticCurveTo(x0 + dir * w * .1, B * .55, x0 + dir * w * .04, B * 1.2); ctx.lineTo(x0, B * 1.2); ctx.fill();
    ctx.strokeStyle = 'rgba(0,0,0,.35)'; ctx.lineWidth = 2; for (let k = 1; k < 6; k++) { ctx.beginPath(); ctx.moveTo(x0 + dir * w * .035 * k, 0); ctx.quadraticCurveTo(x0 + dir * w * .022 * k, B * .6, x0 + dir * w * .008 * k, B * 1.2); ctx.stroke(); }
    ctx.fillStyle = '#d6af5c'; ctx.beginPath(); ctx.arc(x0 + dir * w * .085, B * .58, B * .05, 0, 7); ctx.fill();
  }
  const chandelier = (cx, cy, s) => {
    glowCircle(ctx, cx, cy, s * 3.2, [255, 230, 170], .6);
    ctx.strokeStyle = '#c9a24e'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.moveTo(cx, 0); ctx.lineTo(cx, cy); ctx.stroke();
    for (const [ry, rw] of [[0, 1], [s * .35, .7], [s * .65, .4]]) { ctx.beginPath(); ctx.ellipse(cx, cy + ry, s * rw, s * .2 * rw, 0, 0, 7); ctx.stroke(); }
    for (const [ry, rw, n] of [[0, 1, 18], [s * .35, .7, 12], [s * .65, .4, 8]]) for (let i = 0; i < n; i++) {
      const a = i / n * Math.PI * 2, x = cx + Math.cos(a) * s * rw, y = cy + ry + Math.sin(a) * s * .2 * rw, d = s * (.25 + (i % 3) * .1);
      ctx.strokeStyle = 'rgba(255,255,255,.7)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x, y + d); ctx.stroke();
      ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(x, y + d, 1.7, 0, 7); ctx.fill();
    }
    for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2; glowCircle(ctx, cx + Math.cos(a) * s * .7, cy - s * .12, s * .3, [255, 240, 200], .95); }
  };
  chandelier(w * .5, B * .16, B * .22); chandelier(w * .34, B * .14, B * .13); chandelier(w * .66, B * .14, B * .13);
  ctx.fillStyle = lin(ctx, 0, F, 0, h, [[0, 'rgba(90,10,18,1)'], [1, 'rgba(34,3,10,1)']]); ctx.fillRect(0, F, w, h - F);
  ctx.strokeStyle = 'rgba(214,175,92,.55)'; ctx.lineWidth = 1.5;
  for (let x = 0; x < w; x += B * .3) for (let y = F + (h - F) * .2; y < h; y += B * .3) { ctx.beginPath(); ctx.moveTo(x, y - B * .1); ctx.lineTo(x + B * .1, y); ctx.lineTo(x, y + B * .1); ctx.lineTo(x - B * .1, y); ctx.closePath(); ctx.stroke(); }
  ctx.fillStyle = '#d6af5c'; ctx.fillRect(0, F + (h - F) * .12, w, 3);
  finish(ctx, { split: 0.3, vignette: .5 });
};

TEMPLATES.bar_paddock = (ctx, R, o) => {
  const w = SW, h = SH, B = 91, F = 457;
  ctx.fillStyle = '#0c0d10'; ctx.fillRect(0, 0, w, h);
  const c = B * .1, chk = P2();
  for (let y = 0, k = 0; y < h; y += c / 2, k++) if (k % 2) chk.rect(0, y, w, c / 2);
  for (let x = 0, k = 0; x < w; x += c, k++) if (k % 2) chk.rect(x, 0, c, h);
  ctx.fillStyle = '#17191e'; ctx.fill(chk, 'evenodd');
  for (const [y, col] of [[B * .06, [255, 40, 0]], [B * .46, [0, 181, 200]]]) { const p = new Path2D(); p.moveTo(0, y); p.lineTo(w, y); neonPath(ctx, p, col, B * .01); }
  backlightStrip(ctx, 0, w, B * SHELF, B * .4, [255, 255, 255], .18);
  const trophy = (cx, base, th) => {
    ctx.fillStyle = lin(ctx, cx - th * .3, 0, cx + th * .3, 0, [[0, '#8a6a20'], [.4, '#ffe08a'], [1, '#7a5a18']]);
    ctx.beginPath(); ctx.moveTo(cx - th * .28, base - th); ctx.quadraticCurveTo(cx - th * .3, base - th * .45, cx - th * .06, base - th * .4); ctx.lineTo(cx - th * .05, base - th * .18); ctx.lineTo(cx - th * .2, base - th * .12); ctx.lineTo(cx - th * .2, base); ctx.lineTo(cx + th * .2, base); ctx.lineTo(cx + th * .2, base - th * .12); ctx.lineTo(cx + th * .05, base - th * .18); ctx.lineTo(cx + th * .06, base - th * .4); ctx.quadraticCurveTo(cx + th * .3, base - th * .45, cx + th * .28, base - th); ctx.closePath(); ctx.fill();
    ctx.strokeStyle = '#d4b04a'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(cx - th * .3, base - th * .75, th * .1, Math.PI * .5, Math.PI * 1.5); ctx.stroke(); ctx.beginPath(); ctx.arc(cx + th * .3, base - th * .75, th * .1, -Math.PI * .5, Math.PI * .5); ctx.stroke();
  };
  for (let x = B * .3, i = 0; x < w; x += B * .5, i++) {
    if (Math.abs(x - w / 2) < B * .35) continue;
    if (i % 3 === 1) bottle(ctx, x, B * SHELF, B * .5, 'champagne', [20, 40, 30], [240, 210, 120], [214, 175, 92], { cap: [214, 175, 92] });
    else trophy(x, B * SHELF, B * (i % 3 ? .4 : .48));
  }
  shelf(ctx, 0, w, B * SHELF, B * .06, [200, 200, 205], [60, 62, 68]);
  for (const x0 of [w * .3, w * .6]) { const s = B * .055; for (let r = 0; r < 3; r++) for (let k = 0; k < 6; k++) { ctx.fillStyle = (r + k) % 2 ? '#f2f2f2' : '#111'; ctx.fillRect(x0 + k * s, B * .14 + r * s, s, s); } }
  { const g = P2(), s = B * .13; g.moveTo(w * .5 - s, B * .28 - s); g.lineTo(w * .5 + s, B * .28 + s); g.moveTo(w * .5 + s, B * .28 - s); g.lineTo(w * .5 - s, B * .28 + s); neonPath(ctx, g, [255, 40, 0], B * .02); }
  ctx.fillStyle = '#1a1b1f'; ctx.fillRect(0, F, w, h - F);
  const kh = (h - F) * .16, ky = F + (h - F) * .12; for (let x = 0, i = 0; x < w; x += B * .25, i++) { ctx.fillStyle = i % 2 ? '#f2f2f2' : '#FF2800'; ctx.beginPath(); ctx.moveTo(x, ky + kh); ctx.lineTo(x + B * .08, ky); ctx.lineTo(x + B * .33, ky); ctx.lineTo(x + B * .25, ky + kh); ctx.fill(); }
  finish(ctx, { split: 0.3, vignette: .45 });
};

