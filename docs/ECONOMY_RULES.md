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

**Starting bankroll.** Every account, guests included, holds at least
400,000 AUP in each circuit (2,000,000 in all): about three entries at a
typical fort (median paid fort 78,000-120,000 by circuit; the dearest is
376,000). Granted once per wallet; wallets that began on the old 10,000
starter are topped up to it once, and no balance is ever lowered
(`STARTER_VERSION` 2 in `backend/src/economy/constants.js`). Every kingdom
also has one free fort, the way back after a bad run: a player short of AUP
for a paid fort is offered it straight from the "Need more AUP?" dialog.

**Daily tribute (build 93 on).** Once per calendar day (the phone's day,
from the UTC offset it sends), any account with a server wallet can claim
AUP on the home screen: 50,000, 75,000, 100,000, 125,000, 150,000, 200,000
and 300,000 on days 1-7 of a run of consecutive days, then 300,000 every
day. A missed day starts the run again at day 1. It is paid into the circuit
of the player's latest fort entry (Indian Ocean before the first), so it
lands where AUP is being spent. Claims need four hours between them whatever
the calendar says, so changing time zone cannot pay twice
(`DAILY_TRIBUTE_LADDER` in `backend/src/economy/constants.js`, mirrored by
`kDailyTributeLadder` in `lib/core/daily_tribute.dart`;
`test/daily_tribute_test.dart` checks they match). A day 1 is about half a
typical fort entry and a day 7 about three: a reason to come back and play,
not a way around the free forts.

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

**November 2026 (build 93).** The daily tribute (above), with optional
reminders on the phone when it is ready.

**October 2026 (build 92).** The starter went from 10,000 AUP in all (2,000
a circuit, less than the cheapest paid fort at 52,000) to 400,000 a circuit,
and existing wallets were topped up to it once. Before, a new player could
enter only free forts and had to win one before any paid fort.

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
twenty levels from 100/200 to 15,000/30,000, one orbit each (a turbo
sit-and-go pace; two orbits until build 92), with antes of about 12.5% of
the big blind from level 4. Stacks start at 50 big blinds.
