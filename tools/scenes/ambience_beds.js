// Which ambience bed (a quiet sound loop, assets/sounds/ambience/bed_<name>.m4a)
// plays under each scene. A scene can name its own with opts.bed.
const BEDS = ['sea', 'jungle', 'meadow', 'desert', 'night', 'snow', 'lake', 'city', 'pub', 'casino', 'stadium', 'concert', 'camp', 'festival', 'storm', 'underwater'];
const KIND_BED = { history: 'camp', animals: 'meadow', bar: 'pub', rock: 'concert', sport: 'stadium', wild: 'night' };
const TEMPLATE_BED = {
  seaFort: 'sea', navalBattle: 'sea', shoreBattle: 'sea', longship: 'sea', vikings: 'sea', radarBase: 'snow', winterCitadel: 'snow', andesCrossing: 'snow', himalayanFort: 'snow', westernTown: 'desert', desertCitadel: 'desert',
  underwater: 'underwater',
  casino: 'casino', bar_montecarlo: 'casino', beachShack: 'sea', streetTent: 'city',
  campfireBand: 'camp',
  boatRace: 'lake', waterSport: 'sea', winterSport: 'snow', streetCourt: 'city', runners: 'meadow',
  cityNight: 'city', nightBazaar: 'festival', rocketLaunch: 'night', waterway: 'lake', storm: 'storm', waterfalls: 'lake', dancers: 'festival', saltFlat: 'desert', palaceLights: 'festival',
  volcano: 'night', fields: 'meadow', canalCity: 'city', auroraScene: 'snow', nightTrain: 'night', walledCity: 'city', coastDunes: 'sea', parade: 'festival', observatory: 'night', desertNight: 'night',
  seaRocks: 'sea', glowBay: 'sea', balloons: 'meadow', harbourDusk: 'sea', persianGarden: 'night', stiltFishers: 'sea', baobabAvenue: 'meadow', islandSunset: 'sea', glacier: 'snow', foliage: 'meadow',
  kiteFestival: 'festival', milkyWayDesert: 'desert', fujiStars: 'night', hanabi: 'festival', monumentMoon: 'desert',
};
const LAND_BED = { coast: 'sea', beachNight: 'sea', ice: 'snow', snow: 'snow', jungle: 'jungle', riverbank: 'lake', wetGrass: 'lake' };
function bedFor(kind, template, o) {
  o = o || {};
  if (o.bed) return o.bed;
  if (template === 'wildlife') return LAND_BED[o.land] || (o.sky === 'night' ? 'night' : 'meadow');
  if (template === 'lanterns') return o.mode === 'river' ? 'lake' : 'night';
  if (template === 'peaks') return o.peak === 'hills' ? 'meadow' : 'snow';
  if (template === 'asianGate' && o.calm) return 'snow';
  if (template === 'cityNight' && o.fireworks) return 'festival';
  if (template === 'lounge' && o.style === 'rooftop') return 'city';
  return TEMPLATE_BED[template] || KIND_BED[kind];
}
if (typeof module !== 'undefined') module.exports = { BEDS, bedFor };
