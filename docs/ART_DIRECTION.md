# Art direction

One rule: **the world is drawn, people are portraits.**

- **The world** (forts, sky, the table's surroundings, emblems) is drawn in
  code, flat and silhouetted, at dusk. Files: `lib/ui/art/`.
- **People** (the 100 players, Renoir) are photographic portraits, always
  inside a frame: a seat ring at the table, the gate on the welcome screen.
- **Colour** follows the app icon's split: the red side (Ferrari Red
  `#FF2800`, torches, sunset) on the left, the blue side (Miami Blue
  `#00B5C8`, moonlight, a sentry with a spear) on the right. Stone is warm
  near-black. Each kingdom keeps its own felt hue (`lib/config/venues.dart`),
  and its banners hang in that hue's bright tier either side of the gate.

## Where it shows

| Place | What | Code |
|---|---|---|
| Welcome screen | The whole fort at dusk, gate open, Renoir standing in it; the premise beside it | `FortGeometry.welcome`, `lib/app/startup/disclaimer_splash.dart` |
| Behind the table | One of the kingdom's seven scenes, picked per game (rules below); the fort parapet only when a game has no kingdom | `KingdomSceneBackdrop` in `lib/ui/art/kingdom_scene.dart`, `pickKingdomScene` in `lib/config/kingdom_scenes.dart`; the fallback is `FortGeometry.table` |
| On the felt | A fort emblem in the kingdom's style, 18% opacity | `FortEmblem` in `lib/ui/art/fort_emblem.dart` |
| Card backs | Classic engraved backs in red and blue only | `lib/config/card_backs.dart` |
| Kingdom flags | Modern national flags (rules below) | `lib/config/venues.dart` |

## Kingdom flags

A kingdom's flag is set once, in `lib/config/venues.dart` (`flagAsset`), and
every list that shows a kingdom reads it from there (`kingdomFlagAsset`).

1. A kingdom that is one country flies that country's modern national flag.
2. A kingdom spanning several countries flies the flag of the country with
   the most of its forts; a tie goes to the country listed first, and no two
   kingdoms share a flag.
3. Kept as they are, because they already fit the whole kingdom: the ten
   Indian kingdoms (their historical state flags), Scandinavia (Nordic
   Council), Arabia (Gulf Cooperation Council), Sub-Saharan Africa (African
   Union) and the four US regions (state and city flags).

Country flags live in `assets/images/flags/world/`, rendered at 160 x 120
from flag-icons 7.6.0 (MIT, Panayiotis Lipiridis; licence in
`docs/licenses/`, registered in the app by `lib/config/third_party_notices.dart`
and credited in the About box). `test/kingdom_flags_test.dart` checks every
flag exists and none repeats.

| Kingdom | Flag | Why |
|---|---|---|
| North Africa | Egypt | 3 of 9 forts, listed first (Morocco also 3) |
| Persia & Mesopotamia | Iran | 5 of 9 |
| Central Asia | Uzbekistan | 5 of 11 |
| Indian Ocean Isles | Sri Lanka | 4 of 10 |
| Atlantic Isles | Bermuda | 3 of 7 |
| French & Dutch Isles | Curaçao | 2 of 7 (Guadeloupe flies France's flag, already France's) |
| Pacific | New Zealand | 4 of 12 |
| Arctic | United States | Alaska, 4 of 5 |
| Britain & Ireland | England | 5 of 10 |
| Iberia | Spain | 6 of 10 |
| Low Countries | Netherlands | 4 of 8 |
| Central Europe | European Union | eight countries |
| Balkans & Mediterranean | Croatia | 3 of 10 |
| Baltic Marches | Ukraine | 3 of 10, listed first (Belarus also 3) |
| Mekong | Thailand | 5 of 9 |
| Straits | Malaysia | 7 of 12 |
| Mexico & Central America | Mexico | 6 of 12 |
| Caribbean | Puerto Rico | 2 of 12, listed first (US Virgin Islands also 2) |
| Andes | Venezuela | 4 of 11 |
| Southern Cone | Chile | 5 of 12 |

Replaced in November 2026, because they were borrowed from the older
kingdom map: Korea had China's flag, Japan the Rising Sun flag, Vietnam and
Mekong the ASEAN flag, Indonesia a colonial Straits ensign, Taiwan a
Portuguese colonial flag, Philippines the US Virgin Islands', Brazil
UNASUR's, Russia & Siberia Serbia's, Central Asia Russia's, Canada the 1964
Pearson pennant, France and Italy old royal flags, Mexico & Central America,
Andes and Southern Cone US state flags (Texas, Colorado, Virginia).

## Kingdom scenes

Every kingdom has seven scenes of its own, drawn for that place:

| Slot | What | Examples |
|---|---|---|
| history | a battle, a siege or a fort from the kingdom's past | Panipat (New Delhi), the Great Wall (China), the Alamo (Southern USA) |
| animals | the wildlife it is known for | Gir lions (Baroda), pandas (China), kangaroos (Australia) |
| bar | a bar, pub or casino with local character | an Irish pub, a Macau casino, a tango bar |
| rock | a concert | a stadium of light sticks (Taiwan), desert blues by the fire (North Africa) |
| sport | its sport | sumo, buzkashi, a Boxing Day Test |
| wild (two) | landscapes, festivals, space | the Northern Lights, Día de Muertos, a launch over the steppe |

A game picks one at random, never the scene the player saw last time in that
kingdom; a title match always gets the history scene. 350 scenes in all.

Only the strip above the rail, the four corners and the floor strip show, so
each scene is a panorama: something tall behind the dealer, rim-lit
silhouettes in the two hero zones either side of him, low shapes under the
HUD pills, backlit pieces in the corners. Light sits behind the silhouettes
(a bright horizon band), never on them.

Scenes are written as canvas code in `tools/scenes/` (one list of all 350 in
`kingdoms.js`), recorded to small display lists in `assets/scenes/`, and
drawn by the app once per game into an image. See `tools/scenes/README.md`.
Silhouettes of animals, ships and soldiers come from game-icons.net
(CC BY 3.0, credited in the About box and `docs/licenses/`).

Avoid: working places of worship as the subject of a scene (ancient ruins are
fine), sites of slavery, real
people, and anything that reads as a joke about a culture.

## Fort styles

`fortStyleForKingdom` (`lib/ui/art/fort_style.dart`):

- **classic**: square merlons, round arches, a pennant. Europe, the
  Americas, Africa south of the Sahara, Oceania, the isles.
- **domed**: rounded merlons, domed pavilions, pointed arches. The Indian
  Ocean circuit (except Sikkim), Arabia, Persia & Mesopotamia, Central Asia,
  North Africa, Indian Ocean Isles.
- **eastern**: tiered, upturned roofs. China, Japan, Korea, Taiwan, Vietnam,
  Mekong, Sikkim.

## Retired (November 2026)

- The fort and kingdom "watermarks" in `assets/images/watermarks/` were
  icon-library pictures, most of them not forts (a barbecue grill for Bhadra
  Fort, a lobster for Co Loa Citadel, a jeep, an olive, an anchor for
  Baroda). The table no longer shows them; the files stay until nothing
  references them.
- The zebra, giraffe and leopard card backs, the paint-splash back, and the
  green and black backs are no longer dealt.

## Not yet aligned

- **The dealer at the table** is a cartoon painted in code
  (`lib/ui/widgets/slash_avatar.dart`), one skin per kingdom, with
  shuffling hands. It belongs to the drawn world, but its outlined cartoon
  style is busier than the silhouettes around it. Renoir, the portrait on the
  welcome screen, has no shuffle frames yet; when he does, he can deal.
- The home, venue and fort screens are still plain black; they can take the
  same backdrop.
