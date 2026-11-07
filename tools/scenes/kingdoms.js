// Seven scenes for every kingdom, in this order: war & history, animals,
// bar, rock, sport, and two wild cards. Each entry: [kind, template, title,
// options]. Titles say what the scene shows; templates live in t_*.js.
// Grounded in each kingdom's forts (lib/config/sub_kingdoms.dart) and culture.
var KINGDOMS = {};

// ---------------- Indian Ocean circuit ----------------
KINGDOMS['Baroda'] = [
  ['history', 'seaFort', 'The siege of Diu', { ships: 'galleon', palms: true, flags: [[240, 240, 240], [30, 60, 140]] }],
  ['animals', 'wildlife', 'Lions of Gir', { land: 'dryForest', trees: [380, 960, 1080], animals: [{ kind: 'lion', x: 520, s: 46 }, { kind: 'lioness', x: 590, s: 38, pose: 'lie' }, { kind: 'lioness', x: 790, s: 40, flip: true }, { kind: 'lion', x: 880, s: 44, pose: 'sit', flip: true }], cornerL: (ctx, R, d, rim) => { bigCat(ctx, 40, 330, 150, rgba(rim, 0.8), { mane: true, pose: 'sit' }); bigCat(ctx, 42, 331, 150, d, { mane: true, pose: 'sit' }); }, cornerR: (ctx, R, d) => tree(ctx, R, 'teak', SW - 80, 340, 300, d) }],
  ['bar', 'beachShack', 'A beach shack in Diu', { style: 'shack' }],
  ['rock', 'festival', 'A riverfront concert', { backdrop: 'city', screen: 'rings', c1: [230, 60, 120], c2: [255, 180, 40], beam: [60, 200, 255] }],
  ['sport', 'stadiumNight', 'Cricket in the biggest stadium', { sport: 'cricket', cols: [[255, 255, 255], [30, 60, 160], [80, 160, 255]], board: [30, 60, 160] }],
  ['wild', 'saltFlat', 'The White Rann under a full moon', { tents: true, walkers: true }],
  ['wild', 'dancers', 'Garba nights', { center: 'lamp', sticks: true }],
];
KINGDOMS['Hyderabad'] = [
  ['history', 'indianWar', 'Golconda by torchlight', { style: 'deccan', layout: 'granite', banner: [250, 200, 40], sky: 'warmNight' }],
  ['animals', 'wildlife', 'Blackbuck on the Deccan', { land: 'grassland', animals: [{ kind: 'antelope', x: 480, s: 40, spiral: true }, { kind: 'antelope', x: 540, s: 36, spiral: true, flip: true }, { kind: 'antelope', x: 600, s: 30 }, { kind: 'antelope', x: 760, s: 42, spiral: true, flip: true }, { kind: 'antelope', x: 840, s: 34 }, { kind: 'antelope', x: 905, s: 38, spiral: true, flip: true }], birds: 6 }],
  ['bar', 'bar_rooftop', 'A rooftop bar over the city of pearls', {}],
  ['rock', 'stadiumRock', 'An arena show', { screen: 'eq', c1: [255, 140, 20], c2: [255, 220, 120], beam: [120, 200, 255] }],
  ['sport', 'indoorCourt', 'Badminton finals', { court: 'badminton', cols: [[255, 255, 255], [255, 140, 20], [40, 160, 120]] }],
  ['wild', 'nightBazaar', 'The bangle bazaar at night', { sparkle: [[255, 60, 120], [80, 200, 255], [255, 220, 80], [120, 255, 140]] }],
  ['wild', 'rocketLaunch', 'A launch from Sriharikota', { style: 'pslv' }],
];
KINGDOMS['Indore'] = [
  ['history', 'indianWar', 'The siege of Gwalior', { style: 'rajput', stone: [96, 70, 64], banner: [250, 190, 40], left: 'cannons', right: 'cavalry' }],
  ['animals', 'wildlife', 'Tigers of Kanha', { land: 'jungle', trees: [380, 1000], animals: [{ kind: 'tiger', x: 530, s: 60 }, { kind: 'tiger', x: 840, s: 52, flip: true }], birds: 4 }],
  ['bar', 'bar_montecarlo', 'A Holkar palace lounge', {}],
  ['rock', 'festival', 'A festival at the ruins of Mandu', { backdrop: 'ruins', screen: 'sun', c1: [255, 90, 60], c2: [255, 200, 90] }],
  ['sport', 'akhada', 'Kushti in the akhada', {}],
  ['wild', 'nightBazaar', 'Sarafa night market', { steam: true, awningC: [[230, 140, 30], [200, 40, 50], [250, 220, 90], [60, 140, 90]] }],
  ['wild', 'lanterns', 'Lamps on the Narmada at Maheshwar', { mode: 'river', ghats: true, boats: true, cornerTree: false }],
];
KINGDOMS['Jaipur'] = [
  ['history', 'rajputRamparts', 'Mehrangarh at dusk', {}],
  ['animals', 'desertCaravan', 'A caravan across the Thar', {}],
  ['bar', 'palaceRooftop', 'The palace rooftop bar', {}],
  ['rock', 'desertFestival', 'A desert festival below the palace', {}],
  ['sport', 'polo', 'Polo at the palace grounds', {}],
  ['wild', 'milkyWayDesert', 'The Milky Way over the Thar', {}],
  ['wild', 'kiteFestival', 'Kites over the pink city', {}],
];
KINGDOMS['Maratha Empire'] = [
  ['history', 'indianWar', 'Raigad on its cliff', { style: 'maratha', layout: 'cliff', left: 'cavalry', right: 'cavalry', banner: [255, 130, 20] }],
  ['animals', 'wildlife', 'A leopard of the Sahyadris', { land: 'jungle', sky: 'dusk', sun: [CX - 300, 70, 22], animals: [{ kind: 'leopard', x: 560, s: 50, pose: 'sit', base: 92 }, { kind: 'leopard', x: 820, s: 46, flip: true }], extra: (ctx, R) => { const r = P2(); r.moveTo(470, 96); r.quadraticCurveTo(520, 74, 600, 78); r.quadraticCurveTo(640, 86, 650, 96); r.closePath(); fillPath(ctx, r, '#141210'); } }],
  ['bar', 'bar_speakeasy', 'A Bombay jazz-age bar', {}],
  ['rock', 'festival', 'An open-air festival in the hills', { backdrop: 'hills', screen: 'eq', c1: [60, 180, 255], c2: [255, 80, 160] }],
  ['sport', 'indoorCourt', 'Kabaddi night', { court: 'kabaddi', cols: [[255, 255, 255], [255, 130, 20], [40, 90, 200]] }],
  ['wild', 'waterfalls', 'Monsoon falls on the Sahyadris', { style: 'monsoon' }],
  ['wild', 'cityNight', 'Marine Drive and the sea link', { bridge: 'cable', promenade: true, skylineH: 52 }],
];
KINGDOMS['Mysore'] = [
  ['history', 'indianWar', 'Tipu\'s rockets over Srirangapatna', { style: 'deccan', rockets: true, left: 'rocketeers', right: 'cavalry', banner: [255, 150, 20], stripes: [20, 10, 10], sky: 'warmNight' }],
  ['animals', 'wildlife', 'Elephants on the Kabini', { land: 'riverbank', sky: 'golden', trees: [360, 1010], animals: [{ kind: 'elephant', x: 500, s: 56 }, { kind: 'elephant', x: 560, s: 36 }, { kind: 'elephant', x: 790, s: 60, flip: true }, { kind: 'elephant', x: 880, s: 50, flip: true }], birds: 5 }],
  ['bar', 'pub', 'A Bangalore brewery', { style: 'brewery' }],
  ['rock', 'stadiumRock', 'Metal night in Bangalore', { crowd: 'horns', pyro: true, c1: [255, 40, 20], c2: [255, 160, 40], screen: 'eye' }],
  ['sport', 'horseRace', 'Race day at the turf club', { style: 'turf' }],
  ['wild', 'palaceLights', 'The palace lit for Dasara', { elephants: true }],
  ['wild', 'peaks', 'Mist over the Coorg hills', { time: 'sunrise', peak: 'hills', foreground: 'tea', snow: false }],
];
KINGDOMS['New Delhi'] = [
  ['history', 'indianWar', 'Panipat: guns and elephants', { style: 'mughal', left: 'cannons', right: 'elephants', banner: [200, 30, 50], banner2: [30, 120, 60] }],
  ['animals', 'wildlife', 'Gharials on the Chambal', { land: 'riverbank', sandbank: true, trees: [], animals: [{ kind: 'gharial', x: 520, s: 26, base: 94 }, { kind: 'gharial', x: 800, s: 22, flip: true, base: 92 }, { kind: 'gharial', x: 950, s: 18, base: 95 }, { kind: 'heron', x: 640, s: 34, base: 92 }, { kind: 'heron', x: 720, s: 30, base: 90, flip: true }], birds: 9 }],
  ['bar', 'bar_library', 'A club library bar', {}],
  ['rock', 'stadiumRock', 'An arena night in the capital', { screen: 'rings', c1: [120, 80, 255], c2: [255, 100, 200], beam: [80, 220, 255] }],
  ['sport', 'stadiumNight', 'Cricket by the old walls', { sport: 'cricket', backdrop: 'ruins', cols: [[255, 255, 255], [40, 80, 200], [230, 40, 40]] }],
  ['wild', 'cityNight', 'Diwali over the old city', { water: false, skylineH: 28, sky: 'warmNight', fireworks: [[420, 26, 40, [255, 200, 80]], [700, 14, 34, [255, 80, 120]], [960, 30, 44, [120, 255, 160]]] }],
  ['wild', 'monumentMoon', 'A minaret under the moon', { kind: 'minaret' }],
];
KINGDOMS['Sikh Empire'] = [
  ['history', 'indianWar', 'Crossing the Indus at Attock', { style: 'sikh', layout: 'river', left: 'cavalry', right: 'cavalry', banner: [255, 140, 30], banner2: [30, 50, 140] }],
  ['animals', 'wildlife', 'Horses in the mustard fields', { land: 'mustard', trees: [], animals: [{ kind: 'horse', x: 500, s: 48 }, { kind: 'horse', x: 580, s: 50, pose: 'gallop' }, { kind: 'horse', x: 780, s: 52, pose: 'gallop', flip: true }, { kind: 'horse', x: 880, s: 46, flip: true }], birds: 5 }],
  ['bar', 'bar_deco', 'A Patiala palace bar', {}],
  ['rock', 'festival', 'A bhangra-rock night', { backdrop: 'fortress', screen: 'eq', c1: [255, 150, 20], c2: [60, 120, 255], extra: (ctx, R) => { for (const x of [470, 870]) { const p = P2(); personPath(p, x, 92, 34); fillPath(ctx, p, '#07060c'); const d = P2(); d.ellipse(x + 2, 66, 8, 6, 0, 0, TAU); fillPath(ctx, d, rgba([200, 150, 80])); } } }],
  ['sport', 'stadiumNight', 'Hockey on blue turf', { sport: 'hockey', cols: [[255, 255, 255], [255, 140, 30], [30, 50, 140]] }],
  ['wild', 'peaks', 'The Dhauladhar over Kangra', { time: 'night', foreground: 'ruins' }],
  ['wild', 'dancers', 'Lohri bonfires', { center: 'fire', skirts: false, canopyLights: false, sky: 'deepNight' }],
];
KINGDOMS['Sikkim'] = [
  ['history', 'himalayanFort', 'Rabdentse under Kangchenjunga', {}],
  ['animals', 'wildlife', 'Rhinos of Kaziranga', { land: 'wetGrass', sun: [CX + 260, 70, 20], animals: [{ kind: 'rhino', x: 520, s: 40 }, { kind: 'rhino', x: 600, s: 28 }, { kind: 'elephant', x: 820, s: 56, flip: true }, { kind: 'rhino', x: 900, s: 36, flip: true }], birds: 7 }],
  ['bar', 'colonialClub', 'A hill-station club', { view: 'hills' }],
  ['rock', 'festival', 'Rain-soaked rock in the hills', { backdrop: 'pines', rain: true, screen: 'eq', c1: [80, 220, 160], c2: [255, 200, 80], sky: 'night' }],
  ['sport', 'stadiumNight', 'The Kolkata derby', { sport: 'football', cols: [[150, 30, 40], [30, 110, 60], [255, 220, 60]], flares: true }],
  ['wild', 'peaks', 'The toy train through the tea hills', { time: 'sunrise', foreground: 'tea', train: true }],
  ['wild', 'wildlife', 'Turtles come ashore under the moon', { land: 'beachNight', moon: [CX + 220, 22, 12], stars: 120, rim: [200, 210, 255], dark: '#121014', animals: [{ kind: 'turtle', x: 470, s: 30 }, { kind: 'turtle', x: 540, s: 26, flip: true }, { kind: 'turtle', x: 600, s: 22 }, { kind: 'turtle', x: 760, s: 28, flip: true }, { kind: 'turtle', x: 830, s: 24 }, { kind: 'turtle', x: 900, s: 30, flip: true }] }],
];
KINGDOMS['Travancore'] = [
  ['history', 'seaFort', 'Colachel: the Dutch fleet turned back', { ships: 'galleon', palms: true, time: 'dawn', flags: [[240, 240, 240], [255, 140, 30]] }],
  ['animals', 'wildlife', 'Hornbills of the Western Ghats', { land: 'jungle', sun: [CX - 260, 74, 20], trees: [430, 900], animals: [{ kind: 'monkey', x: 540, s: 40 }, { kind: 'monkey', x: 790, s: 36, flip: true }], extra: (ctx, R) => { for (const [x, y, f] of [[480, 44, false], [860, 40, true], [610, 30, false]]) { line(ctx, x - 40, y + 10, x + 40, y + 6, '#0e120c', 3); hornbill(ctx, x, y, 12, '#0e120c', { flip: f }); } } }],
  ['bar', 'beachShack', 'A toddy shop on the backwaters', { style: 'toddy' }],
  ['rock', 'festival', 'A beach festival at Kovalam', { backdrop: 'beach', palms: true, screen: 'sun', c1: [255, 80, 60], c2: [255, 200, 60] }],
  ['sport', 'boatRace', 'The snake boat race', { style: 'snake' }],
  ['wild', 'waterway', 'Houseboats on the backwaters', { style: 'backwaters' }],
  ['wild', 'storm', 'Monsoon over the Arabian Sea', { lighthouse: true }],
];

// ---------------- Eurasia circuit ----------------
function towerBridge(ctx, R) { const c = rgba([70, 76, 104]); const p = P2(); for (const x of [880, 1040]) { p.rect(x - 14, 20, 28, 54); p.moveTo(x - 16, 20); p.lineTo(x, 4); p.lineTo(x + 16, 20); p.closePath(); for (const s of [-1, 1]) { p.moveTo(x + s * 14 - 3, 20); p.lineTo(x + s * 14, 10); p.lineTo(x + s * 14 + 3, 20); p.closePath(); } } p.rect(894, 30, 132, 4); p.rect(760, 58, 400, 4); fillPath(ctx, p, c); const cb = P2(); cb.moveTo(760, 58); cb.quadraticCurveTo(820, 40, 866, 26); cb.moveTo(1054, 26); cb.quadraticCurveTo(1100, 40, 1160, 58); strokePath(ctx, cb, c, 1.6); const l = []; for (const x of [880, 1040]) for (let y = 28; y < 70; y += 6) l.push([x - 8, y, 1.2], [x + 8, y, 1.2]); for (let x = 760; x < 1160; x += 8) l.push([x, 57, 1]); dots(ctx, l, rgba([255, 220, 150])); glow(ctx, 960, 40, 160, [255, 200, 120], 0.25, true); }
function chateau(ctx, R) { castleOnRock(ctx, R, 900, 80, 60, rgba([30, 26, 36]), { cones: true, lit: [255, 210, 140] }); }
function pragueCastle(ctx, R) { const h = P2(); h.moveTo(560, 74); h.quadraticCurveTo(700, 40, 1000, 46); h.lineTo(1100, 74); h.closePath(); fillPath(ctx, h, rgba([20, 22, 34])); const c = P2(); c.rect(700, 34, 260, 14); for (const [x, ht] of [[760, 30], [830, 46], [850, 40]]) { c.rect(x - 5, 48 - ht, 10, ht); c.moveTo(x - 6, 48 - ht); c.lineTo(x, 48 - ht - 14); c.lineTo(x + 6, 48 - ht); c.closePath(); } fillPath(ctx, c, rgba([40, 40, 56])); const l = []; for (let x = 704; x < 956; x += 6) l.push([x, 41, 1]); dots(ctx, l, rgba([255, 210, 140])); glow(ctx, 830, 30, 80, [255, 200, 120], 0.25, true); }
function alhambra(ctx, R) { mountains(ctx, R, 70, 30, [90, 96, 130], { snow: [240, 240, 250], snowLine: 0.4, bottom: 74 }); const h = P2(); h.moveTo(300, 92); h.quadraticCurveTo(500, 66, 1000, 70); h.lineTo(1100, 92); h.closePath(); fillPath(ctx, h, rgba([24, 22, 26])); const a = P2(); a.rect(480, 50, 460, 22); for (const [x, ht] of [[500, 18], [620, 30], [760, 22], [900, 26]]) a.rect(x - 14, 50 - ht, 28, ht); for (let x = 480; x < 940; x += 8) a.rect(x, 46, 5, 4); fillPath(ctx, a, rgba([150, 90, 60])); const l = []; for (let i = 0; i < 40; i++) l.push([between(R, 486, 934), between(R, 54, 70), 1]); dots(ctx, l, rgba([255, 214, 150])); glow(ctx, 700, 60, 300, [255, 170, 90], 0.25, true); }
function storkTowers(ctx, R) { for (const [x, h] of [[470, 60], [880, 54]]) { const t = P2(); t.rect(x - 16, 92 - h, 32, h); t.moveTo(x - 20, 92 - h); t.lineTo(x, 92 - h - 14); t.lineTo(x + 20, 92 - h); t.closePath(); fillPath(ctx, t, rgba([90, 60, 50])); const n = P2(); n.ellipse(x, 92 - h - 14, 14, 4, 0, 0, TAU); fillPath(ctx, n, rgba([60, 40, 26])); iconAt(ctx, 'heron', x - 2, 92 - h - 14, 30, '#140c0c'); } }
KINGDOMS['Britain & Ireland'] = [
  ['history', 'castleSiege', 'Longbows at the castle walls', { castle: 'keep', left: 'archers', banner: [200, 30, 40], banner2: [240, 200, 60] }],
  ['animals', 'wildlife', 'Highland stags in the mist', { land: 'plains', sky: 'dawn', sun: [CX - 280, 70, 18], rim: [255, 214, 190], animals: [{ kind: 'deer', x: 520, s: 54 }, { kind: 'deer', x: 600, s: 42 }, { kind: 'deer', x: 820, s: 50, flip: true }], extra: (ctx, R) => withBlur(ctx, 8, () => { for (let i = 0; i < 10; i++) oval(ctx, between(R, 0, SW), between(R, 70, 90), between(R, 60, 140), 8, rgba([230, 230, 240], 0.4)); }) }],
  ['bar', 'pub', 'An Irish pub', { style: 'irish' }],
  ['rock', 'stadiumRock', 'Stadium rock', { screen: 'eye', c1: [255, 40, 60], c2: [255, 255, 255], beam: [60, 120, 255] }],
  ['sport', 'stadiumNight', 'Floodlit football', { sport: 'football', cols: [[255, 255, 255], [200, 20, 30], [30, 60, 160]] }],
  ['wild', 'monumentMoon', 'Standing stones under the stars', { kind: 'stones', moonX: CX + 260 }],
  ['wild', 'cityNight', 'The Thames at night', { landmark: towerBridge, skylineH: 40 }],
];
KINGDOMS['France'] = [
  ['history', 'castleSiege', 'Carcassonne under siege', { castle: 'conical', banner: [30, 60, 160], banner2: [240, 220, 120] }],
  ['animals', 'wildlife', 'Flamingos of the Camargue', { land: 'riverbank', sky: 'pinkDusk', trees: [], rim: [255, 200, 200], animals: [{ kind: 'flamingo', x: 480, s: 40 }, { kind: 'flamingo', x: 530, s: 36 }, { kind: 'flamingo', x: 590, s: 42, flip: true }, { kind: 'horse', x: 800, s: 44, pose: 'gallop', flip: true }, { kind: 'horse', x: 880, s: 40, pose: 'gallop', flip: true }], dark: '#2a1418' }],
  ['bar', 'bar_deco', 'A Paris art deco bar', {}],
  ['rock', 'festival', 'A summer festival by the tower', { backdrop: 'eiffel', screen: 'rings', c1: [60, 120, 255], c2: [255, 60, 80], beam: [255, 255, 255] }],
  ['sport', 'cyclingRoad', 'The great mountain stage', { road: 'alps' }],
  ['wild', 'fields', 'Lavender at sunset', { crop: 'lavender', hills: true, farmhouse: true }],
  ['wild', 'cityNight', 'Fireworks over a château', { water: false, skylineH: 12, sky: 'deepNight', landmark: chateau, fireworks: [[480, 24, 40, [80, 140, 255]], [700, 12, 34, [255, 255, 255]], [1040, 22, 44, [255, 60, 80]]] }],
];
KINGDOMS['Italy'] = [
  ['history', 'ancientArmy', 'A legion before the temple', { army: 'roman' }],
  ['animals', 'wildlife', 'Wolves of the Apennines', { land: 'snow', sky: 'night', moon: [CX + 220, 24, 14], stars: 120, sun: false, rim: [200, 220, 255], dark: '#0c0e16', animals: [{ kind: 'wolf', x: 520, s: 54 }, { kind: 'wolf', x: 600, s: 40 }, { kind: 'wolf', x: 820, s: 50, flip: true }] }],
  ['bar', 'terraceBar', 'Aperitivo on the coast', { style: 'amalfi' }],
  ['rock', 'festival', 'Rock in the Roman arena', { backdrop: 'arena', screen: 'sun', c1: [255, 90, 40], c2: [255, 220, 120] }],
  ['sport', 'racetrack', 'Monza, the temple of speed', { track: 'monza' }],
  ['wild', 'canalCity', 'Venice by night', { style: 'venice' }],
  ['wild', 'volcano', 'Etna erupts over the sea', { sea: true }],
];
KINGDOMS['Iberia'] = [
  ['history', 'seaFort', 'Caravels leave the river mouth', { ships: 'galleon', battle: false, time: 'dawn', lighthouse: true, flags: [[240, 240, 240], [200, 30, 40]] }],
  ['animals', 'wildlife', 'Storks on the old towers', { land: 'grassland', sky: 'golden', trees: [], landmark: storkTowers, birds: 8 }],
  ['bar', 'cellarBar', 'A bodega with ham and wine', { style: 'bodega' }],
  ['rock', 'festival', 'A beach festival on the Mediterranean', { backdrop: 'beach', palms: true, screen: 'rings', c1: [255, 60, 120], c2: [255, 200, 40] }],
  ['sport', 'stadiumNight', 'The great rivalry', { sport: 'football', cols: [[255, 255, 255], [160, 20, 40], [30, 60, 140]], confetti: true }],
  ['wild', 'monumentMoon', 'The Alhambra under the stars', { kind: 'tower', tower: alhambra, moonX: CX + 300 }],
  ['wild', 'fields', 'Sunflowers of Andalusia', { crop: 'sunflowers', hills: true }],
];
KINGDOMS['Low Countries'] = [
  ['history', 'starFort', 'Musketeers at the star fort', { bands: [[200, 30, 40], [250, 250, 250], [30, 60, 140]] }],
  ['animals', 'wildlife', 'Herons on the polder', { land: 'riverbank', sky: 'dawn', trees: [], rim: [255, 220, 200], animals: [{ kind: 'heron', x: 520, s: 46 }, { kind: 'heron', x: 590, s: 40, flip: true }, { kind: 'heron', x: 800, s: 44 }], extra: (ctx, R) => { for (const [x, h] of [[180, 60], [320, 50], [1040, 58], [1180, 44]]) windmill(ctx, x, 84, h, rgba([40, 34, 40]), x * 0.01); } }],
  ['bar', 'pub', 'A Belgian beer café', { style: 'belgian' }],
  ['rock', 'festival', 'A festival on the polder', { backdrop: 'windmills', screen: 'eq', c1: [255, 120, 20], c2: [60, 160, 255] }],
  ['sport', 'winterSport', 'Skating on the frozen canals', { kind: 'canalSkate' }],
  ['wild', 'fields', 'Tulip fields', { crop: 'tulips', windmills: true, sky: 'dawn' }],
  ['wild', 'canalCity', 'Canal houses at night', { style: 'amsterdam' }],
];
KINGDOMS['Scandinavia'] = [
  ['history', 'vikings', 'Longships in the fjord', {}],
  ['animals', 'auroraScene', 'Reindeer under the aurora', { reindeer: true, cabin: false }],
  ['bar', 'iceBar', 'An ice bar', {}],
  ['rock', 'festival', 'Metal under the northern lights', { backdrop: 'pines', aurora: true, fire: true, crowd: 'horns', screen: 'eye', c1: [200, 30, 30], c2: [255, 160, 60], sky: 'arctic', lasers: false }],
  ['sport', 'winterSport', 'Ski jumping', { kind: 'skiJump' }],
  ['wild', 'dancers', 'Midsummer around the maypole', { center: 'pole', sky: 'midnightSun', canopyLights: false }],
  ['wild', 'peaks', 'Island peaks under the stars', { time: 'night', peak: 'spires', foreground: 'pines' }],
];
KINGDOMS['Central Europe'] = [
  ['history', 'castleSiege', 'Knights at the brick castle', { castle: 'brick', banner: [240, 240, 240], banner2: [240, 240, 240], cross: [20, 20, 20] }],
  ['animals', 'wildlife', 'Bison of the old forest', { land: 'forest', trees: [380, 960, 1040], animals: [{ kind: 'bison', x: 520, s: 54 }, { kind: 'bison', x: 600, s: 40 }, { kind: 'bison', x: 820, s: 50, flip: true }] }],
  ['bar', 'pub', 'A Munich beer hall', { style: 'bavarian' }],
  ['rock', 'stadiumRock', 'Fire and steel on stage', { pyro: true, c1: [255, 60, 20], c2: [255, 200, 60], screen: 'eq', crowd: 'horns' }],
  ['sport', 'winterSport', 'Night slalom', { kind: 'slalom' }],
  ['wild', 'cityNight', 'The castle over the river', { bridge: 'stone', landmark: pragueCastle, skylineH: 30, spires: 0.4 }],
  ['wild', 'monumentMoon', 'A Carpathian castle under the moon', { kind: 'castle', bats: true, moonX: CX + 200 }],
];
KINGDOMS['Balkans & Mediterranean'] = [
  ['history', 'ancientArmy', 'The phalanx below the temple', { army: 'greek' }],
  ['animals', 'wildlife', 'Dolphins at sunset', { land: 'coast', sun: [CX + 260, 58, 20], animals: [{ kind: 'dolphin', x: 500, s: 40, base: 80 }, { kind: 'dolphin', x: 570, s: 34, base: 84 }, { kind: 'dolphin', x: 800, s: 42, base: 78, flip: true }, { kind: 'sailboat', x: 950, s: 30, base: 74 }], dark: '#0a1018' }],
  ['bar', 'terraceBar', 'An island taverna', { style: 'island' }],
  ['rock', 'festival', 'A festival inside the fortress', { backdrop: 'fortress', screen: 'eq', c1: [255, 40, 120], c2: [60, 220, 255] }],
  ['sport', 'indoorCourt', 'Water polo', { court: 'waterPolo', cols: [[255, 255, 255], [30, 80, 200], [220, 30, 40]] }],
  ['wild', 'walledCity', 'A walled city by the sea', {}],
  ['wild', 'waterfalls', 'Lakes and waterfalls', { style: 'lakes', sky: 'golden' }],
];
KINGDOMS['Baltic Marches'] = [
  ['history', 'castleSiege', 'The island castle besieged', { castle: 'island', banner: [200, 30, 40], banner2: [240, 240, 240] }],
  ['animals', 'wildlife', 'Elk in the morning bog', { land: 'wetGrass', sky: 'dawn', rim: [255, 220, 200], animals: [{ kind: 'moose', x: 530, s: 56 }, { kind: 'moose', x: 820, s: 50, flip: true }], extra: (ctx, R) => withBlur(ctx, 8, () => { for (let i = 0; i < 10; i++) oval(ctx, between(R, 0, SW), between(R, 74, 92), between(R, 60, 140), 8, rgba([230, 230, 240], 0.4)); }) }],
  ['bar', 'cellarBar', 'A medieval cellar bar', { style: 'cellar' }],
  ['rock', 'festival', 'A festival in the pines by the sea', { backdrop: 'pines', screen: 'sun', c1: [255, 140, 40], c2: [255, 220, 120] }],
  ['sport', 'indoorCourt', 'Basketball night', { court: 'basketball', cols: [[255, 255, 255], [30, 130, 60], [250, 200, 40]] }],
  ['wild', 'coastDunes', 'The amber coast at sunset', {}],
  ['wild', 'monumentMoon', 'A castle on its rock in the mist', { kind: 'castle', sky: 'blueHour', extra: (ctx, R) => withBlur(ctx, 10, () => { for (let i = 0; i < 12; i++) oval(ctx, between(R, 0, SW), between(R, 70, 94), between(R, 60, 140), 10, rgba([200, 210, 230], 0.45)); }) }],
];
KINGDOMS['Russia & Siberia'] = [
  ['history', 'winterCitadel', 'The citadel in winter', {}],
  ['animals', 'wildlife', 'A tiger in the snow', { land: 'snow', trees: [380, 1000], rim: [255, 230, 210], dark: '#120a08', animals: [{ kind: 'tiger', x: 530, s: 62 }, { kind: 'tiger', x: 830, s: 50, flip: true }], extra: (ctx, R) => { const s = []; for (let i = 0; i < 200; i++) s.push([between(R, 0, SW), between(R, 0, SH), between(R, 0.5, 1.4)]); dots(ctx, s, rgba([255, 255, 255], 0.7)); } }],
  ['bar', 'cellarBar', 'A frosted vodka bar', { style: 'vodka' }],
  ['rock', 'liveHouse', 'An underground rock club', { c1: [255, 30, 30], c2: [255, 200, 40] }],
  ['sport', 'indoorCourt', 'Ice hockey', { court: 'iceHockey', cols: [[255, 255, 255], [200, 20, 30], [30, 60, 160]] }],
  ['wild', 'nightTrain', 'The long train through the taiga', { land: 'taiga' }],
  ['wild', 'saltFlat', 'A frozen lake under the stars', { hills: true, sky: 'night', moonX: CX - 240 }],
];

// ---------------- Australasia circuit ----------------
KINGDOMS['Japan'] = [
  ['history', 'samuraiCastle', 'The castle at dusk', {}],
  ['animals', 'cranesSnow', 'Cranes dancing in the snow', {}],
  ['bar', 'izakaya', 'An izakaya', {}],
  ['rock', 'liveHouse', 'A Tokyo live house', {}],
  ['sport', 'sumo', 'Sumo under the hanging roof', {}],
  ['wild', 'fujiStars', 'Fuji under the stars', {}],
  ['wild', 'hanabi', 'Summer fireworks over the river', {}],
];
// ---------------- landmarks used below ----------------
function supertrees(ctx, R) {
  for (const [x, h] of [[440, 44], [500, 56], [560, 40], [880, 50], [940, 36]]) { const p = P2(), b = 74; p.moveTo(x - 4, b); p.lineTo(x - 1.5, b - h * 0.8); p.lineTo(x - h * 0.28, b - h); p.lineTo(x + h * 0.28, b - h); p.lineTo(x + 1.5, b - h * 0.8); p.lineTo(x + 4, b); p.closePath(); fillPath(ctx, p, rgba([30, 26, 44])); const l = []; for (let k = 0; k < 14; k++) { const a = Math.PI + k * Math.PI / 13; l.push([x + Math.cos(a) * h * 0.26, b - h - Math.sin(a) * 2, 1.2]); } dots(ctx, l, rgba([255, 80, 200])); glow(ctx, x, b - h, h * 0.4, [200, 80, 255], 0.4, true); }
  const m = P2(); for (const x of [1040, 1080, 1120]) { m.moveTo(x - 10, 74); m.lineTo(x - 6, 20); m.lineTo(x + 8, 20); m.lineTo(x + 10, 74); m.closePath(); } m.moveTo(1020, 18); m.lineTo(1150, 16); m.quadraticCurveTo(1160, 18, 1150, 22); m.lineTo(1024, 22); m.closePath(); fillPath(ctx, m, rgba([40, 40, 56])); const w = []; for (const x of [1040, 1080, 1120]) for (let y = 26; y < 72; y += 3) w.push([x, y, 0.7]); dots(ctx, w, rgba([255, 220, 160], 0.7));
}
function operaHouse(ctx, R) { const p = P2(); for (const [x, w, h] of [[440, 30, 30], [470, 34, 40], [505, 30, 34], [560, 24, 24], [585, 26, 30]]) { p.moveTo(x - w * 0.5, 72); p.quadraticCurveTo(x - w * 0.4, 72 - h, x + w * 0.5, 72 - h * 1.05); p.quadraticCurveTo(x + w * 0.2, 72 - h * 0.5, x + w * 0.4, 72); p.closePath(); } fillPath(ctx, p, lin(ctx, 0, 30, 0, 72, [[0, '#f4f0e8'], [1, '#a8a49c']])); rect(ctx, 400, 70, 220, 4, rgba([120, 110, 100])); glow(ctx, 500, 60, 90, [255, 230, 200], 0.3, true); }
function seoulTower(ctx, R) { const h = P2(); h.moveTo(760, 74); h.quadraticCurveTo(900, 40, 1040, 74); h.closePath(); fillPath(ctx, h, rgba([16, 20, 30])); glow(ctx, 900, 20, 60, [120, 200, 255], 0.35, true); tvTower(ctx, 900, 52, 56, rgba([120, 130, 160])); const l = []; for (let y = 6; y < 50; y += 3) l.push([900, y, 0.8]); dots(ctx, l, rgba([200, 230, 255])); circle(ctx, 900, 17, 3, rgba([160, 220, 255])); }
function taipei101(ctx, R) { glow(ctx, 900, 30, 90, [120, 255, 180], 0.35, true); supertall(ctx, 900, 74, 90, rgba([80, 110, 110]), { kind: 'stacked', lights: [160, 255, 200] }); }
function empireSkyline(ctx, R) { glow(ctx, 470, 20, 70, [255, 200, 120], 0.3, true); supertall(ctx, 470, 74, 84, rgba([90, 84, 100]), { lights: [255, 220, 150] }); glow(ctx, 1080, 30, 60, [160, 200, 255], 0.25, true); supertall(ctx, 1080, 74, 72, rgba([70, 80, 110]), { lights: [200, 220, 255] }); }
function goldenGate(ctx, R) { withBlur(ctx, 10, () => { for (let i = 0; i < 10; i++) oval(ctx, between(R, 500, 1300), between(R, 40, 70), between(R, 60, 140), 10, rgba([220, 220, 230], 0.35)); }); suspensionBridge(ctx, 560, 1320, 70, 58, rgba([190, 60, 40]), { towerW: 9 }); const l = []; for (let x = 560; x < 1320; x += 8) l.push([x, 69, 1]); dots(ctx, l, rgba([255, 214, 150])); }
function sugarloaf(ctx, R) { const p = P2(); p.moveTo(940, 74); p.quadraticCurveTo(960, 10, 990, 8); p.quadraticCurveTo(1016, 12, 1030, 74); p.closePath(); p.moveTo(1030, 74); p.quadraticCurveTo(1060, 50, 1090, 74); p.closePath(); p.moveTo(300, 74); p.quadraticCurveTo(360, 20, 420, 74); p.closePath(); fillPath(ctx, p, rgba([20, 26, 30])); line(ctx, 990, 10, 1060, 54, rgba([200, 200, 210], 0.5), 0.6); }
function isfahanBridge(ctx, R) { const p = P2(); p.rect(380, 52, 600, 20); fillPath(ctx, p, rgba([150, 100, 60])); const ar = P2(); for (let x = 390; x < 975; x += 26) { ar.moveTo(x, 72); ar.lineTo(x, 62); ar.quadraticCurveTo(x + 10, 54, x + 20, 62); ar.lineTo(x + 20, 72); ar.closePath(); } fillPath(ctx, ar, rgba([40, 20, 14])); const ar2 = P2(); for (let x = 392; x < 975; x += 13) { ar2.moveTo(x, 58); ar2.quadraticCurveTo(x + 5, 53, x + 10, 58); ar2.lineTo(x + 10, 60); ar2.lineTo(x, 60); ar2.closePath(); } fillPath(ctx, ar2, rgba([255, 200, 110], 0.85)); for (let x = 400; x < 975; x += 26) glow(ctx, x + 10, 66, 10, [255, 190, 100], 0.5, true); }
function teotihuacan(ctx, R) { stepPyramid(ctx, 560, 86, 150, rgba([110, 80, 80]), { steps: 5 }); stepPyramid(ctx, 960, 86, 110, rgba([100, 74, 74]), { steps: 5 }); }
function bambooGrove(ctx, R) { const p = P2(); for (let x = -20; x < SW + 20; x += between(R, 10, 22)) { if (x > 440 && x < 940 && R() < 0.6) continue; const h = between(R, 60, 100), w = between(R, 2, 4); p.rect(x, 96 - h, w, h); for (let y = 96 - h + 8; y < 96; y += 12) p.rect(x - 1, y, w + 2, 1.4); } fillPath(ctx, p, rgba([40, 70, 40])); const lv = P2(); for (let i = 0; i < 200; i++) { const x = between(R, -20, SW + 20), y = between(R, 0, 60); lv.ellipse(x, y, 6, 1.6, between(R, -0.6, 0.6), 0, TAU); } fillPath(ctx, lv, rgba([60, 100, 50], 0.8)); }
function mayon(ctx, R) { const p = P2(); p.moveTo(860, 86); p.quadraticCurveTo(980, 50, 1010, 14); p.lineTo(1020, 14); p.quadraticCurveTo(1050, 50, 1170, 86); p.closePath(); fillPath(ctx, p, rgba([40, 30, 40])); withBlur(ctx, 8, () => oval(ctx, 1030, 4, 40, 8, rgba([200, 190, 190], 0.4))); }
function wreckRocks(ctx, R) { }
const fogBank = (ctx, R, y0 = 70, y1 = 92, a = 0.4) => withBlur(ctx, 9, () => { for (let i = 0; i < 12; i++) oval(ctx, between(R, 0, SW), between(R, y0, y1), between(R, 60, 140), 9, rgba([230, 230, 240], a)); });

// ---------------- Australasia circuit (Japan is above) ----------------
KINGDOMS['China'] = [
  ['history', 'greatWall', 'The Great Wall at the pass', {}],
  ['animals', 'wildlife', 'Pandas in the bamboo', { land: 'forest', sky: 'dawn', sun: [CX - 300, 70, 18], rim: [255, 230, 210], dark: '#0e0e10', landmark: bambooGrove, extra: (ctx, R) => { panda(ctx, 500, 93, 46, { bamboo: true }); panda(ctx, 580, 93, 30); panda(ctx, 850, 93, 44, { flip: true, bamboo: true }); }, cornerL: (ctx, R, dark) => { const p = P2(); for (const x of [30, 70, 120, 160]) { p.rect(x, -10, 10, 360); for (let y = 0; y < 340; y += 50) p.rect(x - 2, y, 14, 4); } fillPath(ctx, p, '#14200e'); }, cornerR: (ctx, R) => panda(ctx, SW - 90, 330, 120, { flip: true, bamboo: true }) }],
  ['bar', 'casino', 'A Macau casino floor', { style: 'macau' }],
  ['rock', 'stadiumRock', 'A stadium show in red and gold', { screen: 'rings', c1: [255, 40, 40], c2: [255, 210, 60], beam: [255, 230, 160], fireworks: true }],
  ['sport', 'boatRace', 'Dragon boats on the river', { style: 'dragon' }],
  ['wild', 'waterway', 'The Li River karsts', { style: 'guilin' }],
  ['wild', 'peaks', 'The floating pillars in the mist', { peak: 'spires', time: 'sunrise', sky: 'dawn', foreground: 'pines', extra: (ctx, R) => fogBank(ctx, R, 50, 90, 0.45) }],
];
KINGDOMS['Korea'] = [
  ['history', 'asianGate', 'Fire arrows at the fortress gate', { style: 'korean', rockets: true, banners: [[200, 30, 40], [30, 60, 160], [250, 200, 40], [240, 240, 240]] }],
  ['animals', 'wildlife', 'A tiger in the autumn pines', { land: 'forest', sky: 'golden', trees: [360, 1000], rim: [255, 200, 140], animals: [{ kind: 'tiger', x: 540, s: 64 }, { kind: 'tiger', x: 820, s: 52, flip: true }], birds: 6, extra: (ctx, R) => { const lv = []; for (let i = 0; i < 120; i++) lv.push([between(R, 0, SW), between(R, 70, 96), between(R, 1, 2)]); dots(ctx, lv, rgba([230, 110, 40], 0.8)); } }],
  ['bar', 'streetTent', 'A street tent bar', { style: 'korea' }],
  ['rock', 'liveHouse', 'A Hongdae live club', { c1: [255, 60, 180], c2: [60, 220, 255] }],
  ['sport', 'indoorCourt', 'Taekwondo finals', { court: 'taekwondo', cols: [[255, 255, 255], [200, 30, 40], [30, 60, 160]] }],
  ['wild', 'cityNight', 'The Han River at night', { landmark: seoulTower, bridge: 'arch', bridgeC: [90, 100, 140], skylineH: 34, lightsC: [200, 220, 255] }],
  ['wild', 'asianGate', 'The palace in the first snow', { style: 'korean', calm: true }],
];
KINGDOMS['Taiwan'] = [
  ['history', 'seaFort', 'Junks besiege the harbour fort', { ships: 'mixed', time: 'dawn', flags: [[230, 120, 40], [240, 230, 210]] }],
  ['animals', 'wildlife', 'Spoonbills on the mudflats', { land: 'riverbank', sky: 'dawn', sandbank: true, trees: [], rim: [255, 220, 200], dark: '#141014', animals: [{ kind: 'heron', x: 470, s: 34 }, { kind: 'heron', x: 520, s: 30, flip: true }, { kind: 'heron', x: 580, s: 36 }, { kind: 'heron', x: 780, s: 34, flip: true }, { kind: 'heron', x: 840, s: 30 }, { kind: 'heron', x: 900, s: 36, flip: true }], birds: 10 }],
  ['bar', 'lounge', 'A mountain tea house', { style: 'jiufen' }],
  ['rock', 'stadiumRock', 'A stadium of light sticks', { crowd: 'sticks', screen: 'eq', c1: [80, 255, 140], c2: [255, 255, 255], stickC: [120, 255, 160] }],
  ['sport', 'stadiumNight', 'Night baseball', { sport: 'baseball', cols: [[255, 255, 255], [30, 60, 160], [230, 40, 40]] }],
  ['wild', 'nightBazaar', 'A night market', { steam: true, lanternC: [[230, 40, 40], [255, 200, 60]] }],
  ['wild', 'cityNight', 'Fireworks from the tower at New Year', { landmark: taipei101, water: false, skylineH: 44, fireworks: [[820, 30, 40, [255, 80, 80]], [980, 20, 34, [255, 220, 120]], [520, 26, 36, [120, 255, 180]]] }],
];
KINGDOMS['Vietnam'] = [
  ['history', 'asianGate', 'Elephants at the citadel gate', { style: 'vietnam', elephants: true, banners: [[230, 40, 30], [250, 200, 40]] }],
  ['animals', 'wildlife', 'Buffalo in the rice paddies', { land: 'wetGrass', sky: 'golden', field: [120, 170, 70], trees: [], rim: [255, 210, 150], extra: (ctx, R) => { buffalo(ctx, 520, 95, 50, '#141008', { rider: true }); buffalo(ctx, 840, 95, 46, '#141008', { flip: true }); buffalo(ctx, 920, 94, 34, '#141008', { flip: true }); for (const x of [200, 300, 1080, 1200]) palm(ctx, R, x, 86, between(R, 40, 56), rgba([20, 24, 16])); birds(ctx, R, 380, 10, 980, 40, 8, rgba([240, 240, 240], 0.85), 4); } }],
  ['bar', 'streetTent', 'Fresh beer on the street corner', { style: 'biaHoi' }],
  ['rock', 'festival', 'A festival in the green hills', { backdrop: 'hills', screen: 'sun', c1: [255, 60, 40], c2: [255, 220, 60], rain: true }],
  ['sport', 'stadiumNight', 'Football night', { sport: 'football', flares: true, cols: [[255, 255, 255], [220, 30, 30], [255, 220, 40]] }],
  ['wild', 'waterway', 'Junks in the bay of limestone isles', { style: 'halong' }],
  ['wild', 'lanterns', 'Lanterns on the river in the old town', { mode: 'river', boats: true, sky: 'blueHour', landmark: hoiAn, cornerTree: false }],
];
KINGDOMS['Mekong'] = [
  ['history', 'asianGate', 'War elephants at the palace gate', { style: 'thai', elephants: true, banners: [[230, 40, 30], [250, 200, 50], [200, 60, 120]] }],
  ['animals', 'wildlife', 'Elephants bathing in the river', { land: 'riverbank', sky: 'pinkDusk', trees: [300, 1060], tree: 'palm', rim: [255, 200, 160], animals: [{ kind: 'elephant', x: 520, s: 66 }, { kind: 'elephant', x: 600, s: 44 }, { kind: 'elephant', x: 820, s: 62, flip: true }], extra: (ctx, R) => { const sp = []; for (let i = 0; i < 40; i++) sp.push([between(R, 480, 880), between(R, 82, 94), between(R, 0.8, 1.8)]); dots(ctx, sp, rgba([230, 240, 255], 0.7)); } }],
  ['bar', 'lounge', 'A sky bar above the river', { style: 'rooftop', landmark: (ctx, R) => { supertall(ctx, 980, 78, 70, rgba([30, 30, 46]), { lights: [255, 210, 150] }); const r = []; for (let x = 0; x < SW; x += 4) r.push([x, 77 + Math.sin(x * 0.02) * 1, 0.7]); dots(ctx, r, rgba([255, 200, 130], 0.6)); } }],
  ['rock', 'festival', 'A full moon party on the beach', { backdrop: 'beach', sky: 'night', fire: true, palms: true, screen: 'rings', c1: [255, 60, 200], c2: [60, 255, 200], extra: (ctx, R) => moon(ctx, 1020, 16, 12, { halo: 10 }) }],
  ['sport', 'fightRing', 'Muay Thai at the stadium', { style: 'muayThai' }],
  ['wild', 'waterway', 'A floating market at dawn', { style: 'floating' }],
  ['wild', 'lanterns', 'Lanterns rising over the north', { sky: 'deepNight', hills: true }],
];
KINGDOMS['Philippines'] = [
  ['history', 'shoreBattle', 'Warriors on the shore at Mactan', {}],
  ['animals', 'underwater', 'A whale shark in the blue', { kind: 'whaleShark' }],
  ['bar', 'lounge', 'A karaoke bar', { style: 'karaoke' }],
  ['rock', 'festival', 'A beach festival under the volcano', { backdrop: 'beach', sky: 'pinkDusk', palms: true, screen: 'sun', c1: [255, 100, 60], c2: [255, 220, 80], extra: mayon }],
  ['sport', 'streetCourt', 'Basketball under the palms', {}],
  ['wild', 'volcano', 'A perfect cone at dusk', { sky: 'dusk', palms: true }],
  ['wild', 'seaRocks', 'The limestone lagoon at sunset', { sky: 'golden', shape: 'karst', rockC: [90, 110, 90] }],
];
KINGDOMS['Straits'] = [
  ['history', 'navalBattle', 'Pirate junks in the Strait', { ships: 'mixed', backdrop: 'islands', time: 'dusk', flags: [[230, 40, 40], [250, 250, 250]] }],
  ['animals', 'wildlife', 'Orangutans in the canopy', { land: 'jungle', trees: [300, 1060], rim: [255, 180, 120], dark: '#140a06', extra: (ctx, R) => { const v = P2(); for (let x = 420; x < 960; x += 40) { v.moveTo(x, -10); v.quadraticCurveTo(x + 10, 30, x + 4, 60); } strokePath(ctx, v, rgba([30, 40, 24]), 1.6); ape(ctx, 520, 10, 66, '#2a1208'); ape(ctx, 860, 4, 60, '#2a1208', { flip: true }); ape(ctx, 940, 22, 36, '#2a1208'); }, cornerL: (ctx, R) => ape(ctx, 70, -10, 260, '#1a0a04') }],
  ['bar', 'colonialClub', 'A long bar with ceiling fans', { view: 'harbour' }],
  ['rock', 'festival', 'A waterfront festival with lasers', { backdrop: 'city', screen: 'eq', c1: [255, 60, 200], c2: [60, 200, 255], lasers: true }],
  ['sport', 'racetrack', 'The night street race', { track: 'street' }],
  ['wild', 'cityNight', 'Supertrees by the bay', { landmark: supertrees, skylineH: 34, lightsC: [255, 200, 240] }],
  ['wild', 'storm', 'A thunderstorm over the Strait', { ship: true }],
];
KINGDOMS['Indonesia'] = [
  ['history', 'seaFort', 'A spice-island fort under the volcano', { peak: 'volcano', ships: 'galleon', time: 'dusk', palms: true, flags: [[230, 120, 40], [250, 250, 250], [40, 60, 160]] }],
  ['animals', 'wildlife', 'Dragons on the island shore', { land: 'savanna', sky: 'golden', trees: [320, 1040], tree: 'palm', rim: [255, 200, 140], extra: (ctx, R) => { komodo(ctx, 530, 91, 34, '#140c08'); komodo(ctx, 840, 91, 30, '#140c08', { flip: true }); komodo(ctx, 960, 90, 20, '#140c08', { flip: true }); }, cornerR: (ctx, R, dark) => komodo(ctx, SW - 110, 330, 80, dark, { flip: true }) }],
  ['bar', 'beachShack', 'A beach club at sunset', { style: 'shack', sky: 'golden' }],
  ['rock', 'festival', 'A rainforest festival in the rain', { backdrop: 'pines', rain: true, screen: 'rings', c1: [60, 255, 160], c2: [255, 230, 80] }],
  ['sport', 'waterSport', 'Surfing the reef break', { kind: 'surf' }],
  ['wild', 'dancers', 'A fire dance at dusk', { center: 'fire', skirts: false, canopyLights: false, sky: 'dusk' }],
  ['wild', 'fields', 'Rice terraces at dawn', { crop: 'rice', sky: 'dawn', hills: true }],
];
KINGDOMS['Australia'] = [
  ['history', 'frontierFort', 'The stockade at the goldfields', { style: 'stockade', troops: 'redcoats', sky: 'golden', flag: [[30, 50, 140], null, null], flagCross: true }],
  ['animals', 'wildlife', 'Kangaroos at sunset', { land: 'outback', trees: [300, 1060], rim: [255, 190, 120], animals: [{ kind: 'kangaroo', x: 500, s: 60 }, { kind: 'kangaroo', x: 580, s: 44 }, { kind: 'kangaroo', x: 840, s: 56, flip: true }], cornerL: (ctx, R, dark, rim) => rimIcon(ctx, 'koala', 90, 300, 160, dark, rim) }],
  ['bar', 'pub', 'An outback pub', { style: 'outback' }],
  ['rock', 'stadiumRock', 'Pub rock goes to the stadium', { screen: 'eq', crowd: 'horns', c1: [255, 200, 40], c2: [40, 160, 80] }],
  ['sport', 'stadiumNight', 'A Boxing Day Test', { sport: 'cricket', cols: [[255, 255, 255], [250, 200, 40], [30, 120, 60]] }],
  ['wild', 'cityNight', 'Fireworks over the harbour', { landmark: operaHouse, bridge: 'arch', bridgeC: [90, 96, 120], archH: 34, skylineH: 36, fireworks: [[620, 22, 40, [255, 200, 80]], [900, 14, 44, [255, 80, 120]], [1120, 24, 36, [120, 200, 255]]] }],
  ['wild', 'underwater', 'The coral reef', { kind: 'reef' }],
];

// ---------------- Americas circuit ----------------
KINGDOMS['Canada'] = [
  ['history', 'frontierFort', 'Redcoats at the cliff-top citadel', { style: 'stone', troops: 'redcoats', flag: [[200, 30, 40], null, [30, 50, 120]] }],
  ['animals', 'wildlife', 'Grizzlies at the salmon river', { land: 'forest', water: true, trees: [320, 1040], rim: [255, 200, 150], animals: [{ kind: 'bear', x: 520, s: 52 }, { kind: 'bear', x: 820, s: 48, flip: true }], extra: (ctx, R) => { const f = P2(); for (const [x, y] of [[560, 70], [600, 64], [780, 72]]) { f.ellipse(x, y, 5, 2, -0.6, 0, TAU); f.moveTo(x - 5, y + 3); f.lineTo(x - 8, y + 6); f.lineTo(x - 4, y + 5); f.closePath(); } fillPath(ctx, f, rgba([230, 150, 120])); } }],
  ['bar', 'lounge', 'A log lodge by the fire', { style: 'lodge' }],
  ['rock', 'festival', 'A festival in the pines by the lake', { backdrop: 'pines', screen: 'eye', c1: [255, 40, 40], c2: [255, 255, 255] }],
  ['sport', 'winterSport', 'Pond hockey at dusk', { kind: 'pondHockey' }],
  ['wild', 'peaks', 'Mountain lake at dawn', { peak: 'massif', time: 'sunrise', sky: 'dawn', foreground: 'pines' }],
  ['wild', 'auroraScene', 'Northern lights over the lake cabin', { cols: [[60, 255, 150], [80, 200, 255]] }],
];
KINGDOMS['Northeast USA'] = [
  ['history', 'frontierFort', 'A winter camp of the Continental Army', { style: 'stockade', troops: 'continental', sky: 'blueHour', flag: [[200, 30, 40], [250, 250, 250], [30, 50, 120]] }],
  ['animals', 'wildlife', 'Bald eagles over the river', { land: 'forest', water: true, trees: [300, 1060], rim: [255, 210, 160], extra: (ctx, R) => { soaring(ctx, 540, 30, 40, '#120c0a', { whiteHead: true }); soaring(ctx, 850, 22, 32, '#120c0a', { whiteHead: true, flip: true }); }, cornerR: (ctx, R, dark) => soaring(ctx, SW - 110, 140, 70, dark, { whiteHead: true }) }],
  ['bar', 'lounge', 'An uptown jazz club', { style: 'jazz' }],
  ['rock', 'liveHouse', 'A downtown punk club', { c1: [120, 255, 60], c2: [255, 60, 160] }],
  ['sport', 'indoorCourt', 'Basketball at the Garden', { court: 'basketball', cols: [[255, 255, 255], [250, 120, 40], [30, 80, 180]] }],
  ['wild', 'cityNight', 'The skyline and the bridge', { landmark: empireSkyline, bridge: 'suspension', bridgeC: [100, 100, 130], skylineH: 50, spires: 0.35 }],
  ['wild', 'foliage', 'Fall colours on the lake', {}],
];
KINGDOMS['Atlantic USA'] = [
  ['history', 'frontierFort', 'Rockets over the harbour fort', { style: 'stone', troops: 'continental', sky: 'deepNight', rockets: true, flag: [[200, 30, 40], [250, 250, 250], [30, 50, 120]] }],
  ['animals', 'wildlife', 'Dolphins and pelicans', { land: 'coast', sky: 'golden', rim: [255, 210, 150], animals: [{ kind: 'dolphin', x: 520, s: 40, base: 80 }, { kind: 'dolphin', x: 600, s: 34, base: 84 }, { kind: 'dolphin', x: 820, s: 40, base: 80, flip: true }], birds: 8 }],
  ['bar', 'casino', 'A boardwalk casino', { style: 'boardwalk' }],
  ['rock', 'festival', 'A beach festival with lasers', { backdrop: 'beach', palms: true, sky: 'night', screen: 'rings', c1: [255, 80, 200], c2: [60, 220, 255], lasers: true }],
  ['sport', 'racetrack', 'Speedway night', { track: 'oval' }],
  ['wild', 'rocketLaunch', 'Launch night at the cape', {}],
  ['wild', 'storm', 'A lighthouse in the storm', { lighthouse: true }],
];
KINGDOMS['Southern USA'] = [
  ['history', 'frontierFort', 'The old mission fort', { style: 'adobe', troops: 'texian', flag: [[30, 60, 160], [250, 250, 250], null] }],
  ['animals', 'wildlife', 'Alligators in the bayou', { land: 'riverbank', sky: 'pinkDusk', trees: [], rim: [255, 200, 180], dark: '#100c0c', extra: (ctx, R) => { const t = P2(); for (const x of [180, 300, 420, 960, 1080, 1220]) { t.moveTo(x - 16, 92); t.quadraticCurveTo(x - 5, 80, x - 3, 30); t.lineTo(x + 3, 30); t.quadraticCurveTo(x + 5, 80, x + 16, 92); t.closePath(); for (let k = -2; k <= 2; k++) t.ellipse(x + k * 12, 26 + Math.abs(k) * 4, 14, 6, k * 0.2, 0, TAU); } fillPath(ctx, t, rgba([24, 26, 20])); const m = P2(); for (const x of [180, 300, 420, 960, 1080, 1220]) for (let k = -3; k <= 3; k++) { m.moveTo(x + k * 10, 36); m.lineTo(x + k * 10 + 1, 56 + Math.abs(k) * 2); } strokePath(ctx, m, rgba([90, 100, 80], 0.6), 1); alligator(ctx, 530, 88, 26, '#100c0c'); alligator(ctx, 830, 89, 22, '#100c0c', { flip: true }); iconAt(ctx, 'heron', 640, 90, 40, '#100c0c'); const ff = []; for (let i = 0; i < 60; i++) ff.push([between(R, 0, SW), between(R, 40, 90), 1]); dots(ctx, ff, rgba([230, 255, 120], 0.8)); } }],
  ['bar', 'lounge', 'A honky-tonk on music row', { style: 'honkyTonk' }],
  ['rock', 'rockBoat', 'Blues on the riverboat', { style: 'riverboat', c1: [255, 160, 60], c2: [255, 220, 120] }],
  ['sport', 'stadiumNight', 'Friday night lights', { sport: 'americanFootball', cols: [[255, 255, 255], [190, 60, 30], [250, 250, 250]] }],
  ['wild', 'parade', 'A parade of beads and brass', { style: 'carnival', cols: [[140, 60, 200], [250, 200, 40], [40, 170, 80]] }],
  ['wild', 'desertNight', 'Stars over the cactus flats', { land: 'cactus' }],
];
KINGDOMS['Western USA'] = [
  ['history', 'westernTown', 'Showdown on main street', {}],
  ['animals', 'wildlife', 'Bison on the plains', { land: 'plains', trees: [], rim: [255, 200, 140], animals: [{ kind: 'bison', x: 480, s: 56 }, { kind: 'bison', x: 560, s: 48 }, { kind: 'bison', x: 620, s: 40 }, { kind: 'bison', x: 790, s: 54, flip: true }, { kind: 'bison', x: 880, s: 46, flip: true }], cornerL: (ctx, R, dark, rim) => rimIcon(ctx, 'bison', 90, 320, 200, dark, rim) }],
  ['bar', 'casino', 'A casino on the strip', { style: 'vegas' }],
  ['rock', 'redRocks', 'A concert between the red rocks', {}],
  ['sport', 'horseRace', 'Rodeo night', { style: 'rodeo' }],
  ['wild', 'cityNight', 'The red bridge in the fog', { landmark: goldenGate, skylineH: 30, sky: 'pinkDusk' }],
  ['wild', 'desertNight', 'Buttes under the Milky Way', { land: 'buttes' }],
];
KINGDOMS['Mexico & Central America'] = [
  ['history', 'ancientFort', 'Jaguar warriors at the pyramid city', { kind: 'maya' }],
  ['animals', 'wildlife', 'Monarch butterflies in the firs', { land: 'forest', sky: 'golden', trees: [300, 420, 960, 1080], rim: [255, 200, 140], extra: (ctx, R) => { butterflies(ctx, R, 220, [0, 0, SW, 96], [[250, 140, 30], [240, 110, 20], [255, 180, 60]], [2.6, 5]); hummingbird(ctx, 560, 44, 34, '#120a08'); hummingbird(ctx, 820, 36, 28, '#120a08', { flip: true }); }, cornerL: (ctx, R) => butterflies(ctx, R, 50, [0, 40, 200, 320], [[250, 140, 30], [255, 180, 60]], [8, 16]) }],
  ['bar', 'lounge', 'A cantina under paper flags', { style: 'cantina' }],
  ['rock', 'festival', 'A rock festival at the ruins', { backdrop: 'ruins', screen: 'sun', c1: [255, 60, 140], c2: [255, 200, 40] }],
  ['sport', 'fightRing', 'Masked wrestling night', { style: 'lucha' }],
  ['wild', 'parade', 'The Day of the Dead', { style: 'muertos' }],
  ['wild', 'balloons', 'Balloons over the pyramids at dawn', { landmark: teotihuacan }],
];
KINGDOMS['Caribbean'] = [
  ['history', 'navalBattle', 'Pirates attack a treasure galleon', { pirate: true, backdrop: 'islands', time: 'dusk' }],
  ['animals', 'underwater', 'A wreck on the reef', { kind: 'wreck' }],
  ['bar', 'lounge', 'A Havana bar', { style: 'havana' }],
  ['rock', 'festival', 'Reggae in the hills', { backdrop: 'hills', screen: 'sun', c1: [40, 180, 80], c2: [255, 220, 40], flags: [[40, 160, 70], [255, 210, 40], [220, 40, 40]], palms: true }],
  ['sport', 'stadiumNight', 'Cricket by the sea', { sport: 'cricket', backdrop: 'sea', cols: [[255, 255, 255], [130, 20, 40], [250, 200, 40]] }],
  ['wild', 'glowBay', 'The glowing bay', {}],
  ['wild', 'seaRocks', 'Twin peaks at sunset', { sky: 'pinkDusk', shape: 'pitons', rockC: [80, 110, 80] }],
];
KINGDOMS['Brazil'] = [
  ['history', 'seaFort', 'Galleons in the bay under the peak', { peak: 'sugarloaf', ships: 'galleon', time: 'dawn', flags: [[40, 140, 60], [250, 210, 40]] }],
  ['animals', 'wildlife', 'A jaguar by the river', { land: 'jungle', water: true, trees: [300, 1060], rim: [255, 190, 120], animals: [{ kind: 'leopard', x: 560, s: 60 }, { kind: 'leopard', x: 820, s: 54, flip: true, pose: 'lie' }], extra: (ctx, R) => { for (const [x, y, c] of [[470, 30, [230, 40, 40]], [520, 22, [40, 120, 230]], [880, 26, [250, 200, 40]], [930, 34, [230, 40, 40]]]) { bird(ctx, x, y, 7, rgba(c)); line(ctx, x, y, x - 10, y + 6, rgba(c), 2); } } }],
  ['bar', 'beachShack', 'A beach kiosk at sunset', { style: 'kiosk' }],
  ['rock', 'festival', 'Rock in the city', { backdrop: 'city', screen: 'rings', c1: [250, 210, 40], c2: [40, 180, 80], extra: (ctx, R) => { for (const [x, y, c] of [[300, 20, [255, 220, 60]], [1080, 16, [80, 220, 120]]]) firework(ctx, R, x, y, 30, c); } }],
  ['sport', 'stadiumNight', 'Football in the great bowl', { sport: 'football', flares: true, confetti: true, cols: [[255, 255, 255], [250, 210, 40], [40, 160, 70]] }],
  ['wild', 'parade', 'The samba parade', { style: 'samba' }],
  ['wild', 'cityNight', 'New Year fireworks on the beach', { landmark: sugarloaf, promenade: true, skylineH: 26, fireworks: [[560, 20, 40, [255, 255, 255]], [760, 12, 34, [255, 210, 60]], [1180, 24, 38, [80, 220, 160]]] }],
];
KINGDOMS['Andes'] = [
  ['history', 'ancientFort', 'Warriors on the terraced fortress', { kind: 'inca' }],
  ['animals', 'wildlife', 'Condors over the peaks', { land: 'plains', sky: 'dawn', snowCaps: true, trees: [], rim: [255, 220, 190], extra: (ctx, R) => { soaring(ctx, 520, 24, 30, '#100c0e'); soaring(ctx, 860, 34, 24, '#100c0e', { flip: true }); llama(ctx, 600, 96, 44, '#100c0e'); llama(ctx, 780, 96, 40, '#100c0e', { flip: true }); llama(ctx, 840, 96, 30, '#100c0e', { flip: true }); }, cornerR: (ctx, R, dark) => soaring(ctx, SW - 110, 120, 80, dark) }],
  ['bar', 'lounge', 'A pisco bar under wooden balconies', { style: 'balcony' }],
  ['rock', 'festival', 'A festival below the snow peaks', { backdrop: 'hills', sky: 'dusk', screen: 'eq', c1: [255, 80, 60], c2: [255, 220, 120] }],
  ['sport', 'cyclingRoad', 'A mountain stage in the high Andes', { road: 'alps' }],
  ['wild', 'saltFlat', 'The salt flat mirror', { mirror: true, sky: 'dusk', walkers: true }],
  ['wild', 'peaks', 'The lost city in the clouds', { peak: 'spires', time: 'sunrise', sky: 'dawn', foreground: 'ruins', extra: (ctx, R) => fogBank(ctx, R, 50, 86, 0.45) }],
];
KINGDOMS['Southern Cone'] = [
  ['history', 'andesCrossing', 'The army crosses the Andes', {}],
  ['animals', 'wildlife', 'Penguins on the Patagonian shore', { land: 'coast', sky: 'dawn', rim: [255, 220, 200], dark: '#0a0c10', animals: [{ kind: 'penguin', x: 470, s: 48, base: 92 }, { kind: 'penguin', x: 520, s: 40, base: 92 }, { kind: 'penguin', x: 575, s: 50, base: 92 }, { kind: 'penguin', x: 760, s: 46, base: 92, flip: true }, { kind: 'penguin', x: 820, s: 40, base: 92, flip: true }, { kind: 'penguin', x: 885, s: 50, base: 92, flip: true }], extra: (ctx, R) => rect(ctx, 0, 88, SW, 10, lin(ctx, 0, 88, 0, 98, [[0, '#7a7060'], [1, '#2a2620']])), cornerL: (ctx, R, dark, rim) => rimIcon(ctx, 'penguin', 90, 330, 200, dark, rim) }],
  ['bar', 'lounge', 'A tango bar', { style: 'tango' }],
  ['rock', 'stadiumRock', 'A stadium in sky blue', { screen: 'flag', flagCols: [[120, 190, 240], [255, 255, 255], [120, 190, 240]], confetti: true, c1: [120, 190, 240], c2: [255, 255, 255] }],
  ['sport', 'stadiumNight', 'A derby night in the old stadium', { sport: 'football', confetti: true, flares: true, cols: [[255, 255, 255], [30, 60, 160], [250, 210, 40]] }],
  ['wild', 'peaks', 'Granite towers at dawn', { peak: 'spires', time: 'sunrise', sky: 'golden', foreground: 'tents' }],
  ['wild', 'waterfalls', 'The great falls with a rainbow', { style: 'great', rainbow: true }],
];

// ---------------- Rest of the World circuit ----------------
KINGDOMS['North Africa'] = [
  ['history', 'desertCitadel', 'Horsemen at the citadel', { style: 'cairo', troops: 'cavalry', flags: [[200, 30, 40], [250, 250, 250], [20, 20, 20]] }],
  ['animals', 'wildlife', 'Fennec foxes in the dunes', { land: 'outback', sky: 'golden', ground: ['#e8b070', '#8a5a30', '#20120a'], trees: [], rim: [255, 210, 150], extra: (ctx, R) => { fennec(ctx, 540, 96, 40, '#160c08'); fennec(ctx, 600, 96, 30, '#160c08'); fennec(ctx, 820, 96, 38, '#160c08', { flip: true }); }, cornerL: (ctx, R, dark) => fennec(ctx, 90, 330, 220, dark) }],
  ['bar', 'lounge', 'A courtyard bar in the old city', { style: 'riad' }],
  ['rock', 'campfireBand', 'Desert blues by the fire', {}],
  ['sport', 'horseRace', 'The charge of the horsemen', { style: 'desert' }],
  ['wild', 'waterway', 'Feluccas on the river', { style: 'nile' }],
  ['wild', 'monumentMoon', 'The pyramids by moonlight', { kind: 'pyramids', land: 'dunes' }],
];
KINGDOMS['Sub-Saharan Africa'] = [
  ['history', 'stoneCity', 'Warriors at the great stone walls', {}],
  ['animals', 'wildlife', 'Giraffes and elephants at sunset', { land: 'savanna', trees: [300, 420, 1000], rim: [255, 190, 110], animals: [{ kind: 'giraffe', x: 500, s: 74 }, { kind: 'giraffe', x: 560, s: 60 }, { kind: 'elephant', x: 820, s: 62, flip: true }, { kind: 'elephant', x: 890, s: 44, flip: true }] }],
  ['bar', 'lounge', 'A safari lodge bar', { style: 'safari' }],
  ['rock', 'festival', 'A festival under the baobabs', { backdrop: 'baobab', screen: 'sun', c1: [255, 140, 40], c2: [255, 220, 80], fire: true }],
  ['sport', 'runners', 'Distance runners at dawn', {}],
  ['wild', 'peaks', 'The snow dome above the plains', { peak: 'cone', time: 'sunrise', sky: 'dawn', foreground: 'tents' }],
  ['wild', 'waterfalls', 'The smoke that thunders under a moonbow', { style: 'night', rainbow: true }],
];
KINGDOMS['Arabia'] = [
  ['history', 'desertCitadel', 'Camel riders at the fort', { style: 'oman', troops: 'camel', flags: [[200, 30, 40], [250, 250, 250], [30, 120, 60]] }],
  ['animals', 'wildlife', 'Oryx and falcons in the dunes', { land: 'outback', sky: 'golden', ground: ['#f0c080', '#9a6a3a', '#24140a'], trees: [], rim: [255, 220, 170], animals: [{ kind: 'antelope', x: 520, s: 50 }, { kind: 'antelope', x: 590, s: 40 }, { kind: 'antelope', x: 820, s: 48, flip: true }], extra: (ctx, R) => { soaring(ctx, 700, 20, 16, '#160c08'); soaring(ctx, 980, 30, 12, '#160c08', { flip: true }); }, cornerR: (ctx, R, dark) => soaring(ctx, SW - 110, 140, 70, dark) }],
  ['bar', 'lounge', 'A sky lounge beside the tallest tower', { style: 'rooftop', landmark: (ctx, R) => { glow(ctx, 900, 30, 90, [200, 220, 255], 0.3, true); supertall(ctx, 900, 78, 100, rgba([110, 120, 150]), { lights: [220, 235, 255] }); } }],
  ['rock', 'festival', 'A rave in the dunes', { backdrop: 'desert', screen: 'eye', c1: [255, 60, 200], c2: [60, 220, 255], lasers: true }],
  ['sport', 'horseRace', 'Camel racing at dawn', { style: 'desert', animal: 'camel', sky: 'dawn' }],
  ['wild', 'desertNight', 'A desert camp under the stars', { land: 'dunes' }],
  ['wild', 'harbourDusk', 'Dhows on the creek at dusk', {}],
];
KINGDOMS['Persia & Mesopotamia'] = [
  ['history', 'immortals', 'The Immortals at the palace of columns', {}],
  ['animals', 'wildlife', 'A cheetah on the steppe', { land: 'grassland', trees: [], rim: [255, 200, 140], farC: [140, 110, 120], animals: [{ kind: 'cheetah', x: 540, s: 56 }, { kind: 'cheetah', x: 820, s: 50, flip: true, pose: 'sit' }, { kind: 'antelope', x: 1000, s: 40, flip: true }] }],
  ['bar', 'lounge', 'A tea house under the arches', { style: 'teaHouse' }],
  ['rock', 'festival', 'Rock among the old columns', { backdrop: 'ruins', screen: 'rings', c1: [255, 120, 40], c2: [80, 160, 255], sky: 'deepNight' }],
  ['sport', 'akhada', 'The house of strength', { style: 'zurkhaneh' }],
  ['wild', 'cityNight', 'The bridge of arches at night', { landmark: isfahanBridge, skylineH: 22, spires: 0, lightsC: [255, 190, 110], cityC: [30, 22, 26] }],
  ['wild', 'persianGarden', 'A garden of pools and cypresses', {}],
];
KINGDOMS['Central Asia'] = [
  ['history', 'desertCitadel', 'Horse archers before the sloped fortress', { style: 'ark', troops: 'horseArchers', mud: [190, 150, 110], flags: [[40, 120, 200], [250, 250, 250], [40, 160, 70]] }],
  ['animals', 'wildlife', 'Eagle hunters on the steppe', { land: 'plains', sky: 'golden', snowCaps: true, trees: [], rim: [255, 210, 160], animals: [{ kind: 'horse', x: 540, s: 50, rider: true }, { kind: 'horse', x: 820, s: 46, rider: true, flip: true }], extra: (ctx, R) => { soaring(ctx, 620, 26, 24, '#140c08'); soaring(ctx, 760, 40, 18, '#140c08', { flip: true }); }, cornerR: (ctx, R, dark) => soaring(ctx, SW - 110, 140, 80, dark) }],
  ['bar', 'lounge', 'Inside a felt yurt', { style: 'yurt' }],
  ['rock', 'festival', 'Rock on the steppe', { backdrop: 'hills', fire: true, screen: 'sun', c1: [60, 160, 255], c2: [255, 210, 60] }],
  ['sport', 'horseRace', 'A buzkashi match', { style: 'buzkashi' }],
  ['wild', 'rocketLaunch', 'A launch over the steppe', { land: 'steppe' }],
  ['wild', 'peaks', 'Yurts below the high peaks', { peak: 'massif', time: 'sunrise', sky: 'golden', foreground: 'yurts' }],
];
KINGDOMS['Indian Ocean Isles'] = [
  ['history', 'rockFortress', 'The rock fortress above the jungle', {}],
  ['animals', 'underwater', 'Manta rays in the atoll', { kind: 'manta' }],
  ['bar', 'beachShack', 'An overwater bar', { style: 'overwater' }],
  ['rock', 'festival', 'A stage on the lagoon', { backdrop: 'beach', palms: true, sky: 'dusk', screen: 'sun', c1: [255, 140, 60], c2: [60, 220, 220] }],
  ['sport', 'waterSport', 'Kitesurfing the lagoon', { kind: 'kitesurf' }],
  ['wild', 'stiltFishers', 'Stilt fishermen at sunset', {}],
  ['wild', 'baobabAvenue', 'An avenue of baobabs at dusk', {}],
];
KINGDOMS['Atlantic Isles'] = [
  ['history', 'seaFort', 'Galleons off the island fort', { ships: 'galleon', time: 'dusk', lighthouse: 'striped', flags: [[200, 30, 40], [250, 250, 250], [30, 50, 120]] }],
  ['animals', 'wildlife', 'Whales off the islands', { land: 'coast', sky: 'dawn', rim: [255, 220, 190], dark: '#0a0c12', animals: [{ kind: 'whale-tail', x: 520, s: 50, base: 84 }, { kind: 'whale-tail', x: 860, s: 40, base: 86, flip: true }], birds: 8, extra: (ctx, R) => { const sp = []; for (let i = 0; i < 30; i++) sp.push([between(R, 480, 560), between(R, 60, 84), 1]); dots(ctx, sp, rgba([240, 250, 255], 0.6)); } }],
  ['bar', 'beachShack', 'A pink-sand beach bar', { style: 'pink' }],
  ['rock', 'rockBoat', 'A party catamaran', { style: 'catamaran', c1: [255, 80, 160], c2: [80, 220, 255] }],
  ['sport', 'waterSport', 'Racing yachts off the islands', { kind: 'sailing' }],
  ['wild', 'seaRocks', 'Sea arches at sunset', { arches: true, sky: 'golden', rockC: [170, 140, 120] }],
  ['wild', 'observatory', 'Observatories above the clouds', {}],
];
KINGDOMS['French & Dutch Isles'] = [
  ['history', 'navalBattle', 'Ships of the line at sea', { ships: 'line', backdrop: 'islands', time: 'dusk', flags: [[30, 60, 160], [250, 250, 250], [200, 30, 40]] }],
  ['animals', 'wildlife', 'Flamingos in the salt pans', { land: 'coast', sky: 'pinkDusk', rim: [255, 200, 200], dark: '#200c14', extra: (ctx, R) => { rect(ctx, 0, 84, SW, 14, lin(ctx, 0, 84, 0, 98, [[0, '#e8a0b0'], [1, '#6a4050']])); for (const [x, s, f] of [[460, 40, false], [510, 34, true], [570, 42, false], [770, 38, true], [830, 44, false], [890, 34, true]]) iconAt(ctx, 'flamingo', x, 94, s, '#200c14', { flip: f }); const c = P2(); for (const x of [200, 300, 1060, 1180]) { c.rect(x - 3, 60, 6, 30); c.rect(x - 12, 70, 4, 10); c.rect(x - 12, 78, 12, 3); c.rect(x + 8, 66, 4, 12); c.rect(x, 74, 12, 3); } fillPath(ctx, c, '#200c14'); }, cornerL: (ctx, R, dark, rim) => rimIcon(ctx, 'flamingo', 90, 330, 200, dark, rim) }],
  ['bar', 'lounge', 'A rum distillery bar', { style: 'distillery' }],
  ['rock', 'festival', 'A zouk festival on the beach', { backdrop: 'beach', palms: true, screen: 'rings', c1: [255, 160, 40], c2: [40, 200, 160], sky: 'warmNight' }],
  ['sport', 'waterSport', 'A race of sailing yoles', { kind: 'yoles' }],
  ['wild', 'canalCity', 'The painted waterfront', { style: 'harbour' }],
  ['wild', 'islandSunset', 'Wind-bent trees at sunset', {}],
];
KINGDOMS['Pacific'] = [
  ['history', 'ancientFort', 'War canoes below the hill fort', { kind: 'pa' }],
  ['animals', 'wildlife', 'Kiwi in the night forest', { land: 'forest', sky: 'night', sun: false, moon: [1000, 18, 9], stars: 80, trees: [320, 1040], tree: 'pine', rim: [200, 220, 255], dark: '#080a0e', animals: [{ kind: 'kiwi-bird', x: 540, s: 34 }, { kind: 'kiwi-bird', x: 600, s: 26 }, { kind: 'kiwi-bird', x: 820, s: 32, flip: true }], extra: (ctx, R) => { const ff = P2(); for (let x = -20; x < SW + 20; x += 30) { ff.moveTo(x, 96); for (let k = 0; k < 6; k++) { ff.moveTo(x, 96); ff.quadraticCurveTo(x + (k - 2.5) * 6, 80, x + (k - 2.5) * 12, 74 + Math.abs(k - 2.5) * 3); } } strokePath(ctx, ff, rgba([20, 40, 30]), 1.4); }, cornerL: (ctx, R, dark, rim) => rimIcon(ctx, 'kiwi-bird', 90, 330, 180, dark, rim) }],
  ['bar', 'bar_tiki', 'A tiki bar', {}],
  ['rock', 'festival', 'A festival in the green hills', { backdrop: 'hills', screen: 'eye', c1: [60, 220, 160], c2: [255, 255, 255] }],
  ['sport', 'stadiumNight', 'The war dance before kick-off', { sport: 'rugby', haka: true, cols: [[255, 255, 255], [20, 20, 20], [250, 250, 250]] }],
  ['wild', 'volcano', 'Lava meets the sea', { sea: true, sky: 'night' }],
  ['wild', 'dancers', 'Dancing by torchlight', { center: 'fire', skirts: [[230, 60, 40], [250, 200, 60], [40, 160, 120]], canopyLights: false, sky: 'pinkDusk' }],
];
KINGDOMS['Arctic'] = [
  ['history', 'radarBase', 'The radar station on the ice', {}],
  ['animals', 'wildlife', 'Polar bears on the ice', { land: 'ice', rim: [220, 240, 255], dark: '#0a0e16', animals: [{ kind: 'polar-bear', x: 530, s: 56 }, { kind: 'polar-bear', x: 600, s: 34 }, { kind: 'polar-bear', x: 830, s: 50, flip: true }], cornerR: (ctx, R, dark, rim) => rimIcon(ctx, 'polar-bear', SW - 110, 330, 200, dark, rim, { flip: true }) }],
  ['bar', 'pub', 'A gold-rush saloon', { style: 'saloon' }],
  ['rock', 'festival', 'A festival under the midnight sun', { backdrop: 'pines', sky: 'midnightSun', screen: 'sun', c1: [255, 160, 60], c2: [255, 230, 160] }],
  ['sport', 'winterSport', 'The long sled race', { kind: 'dogSled' }],
  ['wild', 'glacier', 'A glacier meets the sea', {}],
  ['wild', 'auroraScene', 'Northern lights over the ice', { fore: 'ice', cabin: false, cols: [[60, 255, 150], [255, 80, 200], [80, 200, 255]] }],
];

if (typeof module !== 'undefined') module.exports = { KINGDOMS };
