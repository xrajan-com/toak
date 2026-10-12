# Economy rules

What a game costs and pays in X Poker. The server enforces these rules
(`backend/src/economy/`); the app explains them to the player and must say the
same thing. Prices and prizes come from the catalog
(`backend/src/economy/catalog.json`, exported from `lib/core/aup.dart`).

## The rules (rules version 2, build 87 on)

| Situation | Effect on the wallet |
| --- | --- |
| Enter a fort or main event | The catalog entry fee is held, then spent when the cards are dealt. |
| Finish in a paid place | The catalog prize for that place. |
| Finish outside the prizes | Nothing more. The entry fee was the cost. |
| Leave the table | Nothing more. Counts as last place. |
| Game interrupted (app closed, phone restarted) | Closed after a 10-minute safety window. Counts as leaving: last place, the fee stays spent. |
| Entry held but cards never dealt | The fee is refunded in full (at once, or after an hour). |
| Quick Game | Free. Results count in the stats; the wallet never changes. |

**The entry fee is the most a game can cost.** The entry sheet shows the fee,
the prize for each paid place, and this rule before anything is charged.

Forts pay 60/25/15% of their prize pool to 1st, 2nd and 3rd
(`kFortPayoutShares`). Main events are winner takes all. Wallet caps: 20 Aura
per circuit, 100 Aura in all.

## Rules versions

The app sends `X-Economy-Rules` with every request. The server applies the
rules the app describes, so the app never says one thing while the server does
another.

| Version | Builds | Interrupted game |
| --- | --- | --- |
| 1 (no header) | up to 86 | Fee refunded, because those builds say so. |
| 2 | 87 on | Counts as leaving: the fee stays spent. |

`ECONOMY_RULES_VERSION` in `backend/src/economy/constants.js` and
`economyRulesVersion` in `lib/config/economy_rules.dart` must match;
`test/economy_rules_test.dart` checks they do. Raise both when the rules a
player is told about change.

## History

**October 2026 (build 87).** Before this, every non-winning finish also took
0.1% of the whole wallet and every quit took 0.3%; an interrupted game was
refunded minus 0.3%. Because the charge grew with the wallet while prizes did
not, a typical player stalled near 9 Aura and needed an ever higher win rate to
climb, and the charge was never shown. An interrupted game also cost less than
leaving properly, so closing the app was the cheapest way out of a losing
table. All three charges are gone; losing, leaving and an interrupted game
now cost exactly the entry fee. Quick Game, which also charged 0.1% per loss,
is now free.

## Table structure

Every table plays the blind structure in `lib/config/blind_structure.dart`:
twenty levels from 100/200 to 15,000/30,000, two orbits each, with antes of
about 12.5% of the big blind from level 4.
