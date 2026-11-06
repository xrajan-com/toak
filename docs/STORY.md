# The story of X Poker

**Here, kingdoms don't go to war. They play poker.**

## The world

- Fifty kingdoms on five circuits, 500 forts. Every fort hosts a table.
- Every kingdom crowns its ruler at a **title match**: a table of ten,
  played down to heads-up. The crown is a real rank of history: Patel of
  Baroda, Jarl of Scandinavia, Prospector of the Western USA
  (`lib/config/kingdom_titles.dart`).
- No armies and no blood: the duel is at the felt, and chips are play money.

## The characters

- **You.** One seat, 10,000 chips, no title, no name in the books. The goal:
  all fifty crowns.
- **Renoir.** The cheetah in the white turban and tuxedo
  (`assets/images/renoir_tux.png`). He deals the title matches, and has for
  longer than anyone remembers. He speaks rarely and briefly; every story
  line is his. *The wild doesn't fold.*
- **The title holders.** Each kingdom's crown is held by one of its
  strongest players, the same one every time, who waits at the title match.
- **Rivals.** Regulars who remember you: your head-to-head record follows
  you from table to table (`lib/services/rival_service.dart`).
- **The Hundred.** 100 named players, each with a home and a day job
  (`docs/bot_roster.csv`).

## The beats, and where they live

| Beat | Moment | Where |
|---|---|---|
| Prologue | First launch: the fort at dusk, Renoir in the gate, the premise | Welcome screen |
| Arrival | Renoir's line as every table starts, over the players | `StoryLines.openingLine` |
| The title holder | Named in Renoir's line at the title match, and "Patel of Baroda · holds the crown" over their seat at the first hand | `StoryLines.pickTitleHolder`, `titleHolderNote` |
| Rivals | "Rival · leads you 3-2" over their seat at the first hand | `RivalService` (existing) |
| Coronation | TITLE WON… CROWNED | `lib/ui/widgets/win_card.dart` (existing) |

Renoir's lines (`lib/config/story.dart`):

- First table: *Welcome to Baroda. Every crown in the world starts at a
  table like this one.*
- Quick Game: *Welcome to Japan. No crown at this table, only practice.
  Make it count.*
- Career fort: *Lakhota Fort, Baroda. Every fort you take brings the crown
  of Patel closer.*
- Title match: *Title match, Baroda. (holder) is Patel. Take the table
  and the crown is yours.*

## Voice

Short, dry, second person. No exclamation marks. No gambling talk: no
money, no jackpots, no "bet big". Poker words are fine.

## Next

1. A face-off card before the title match: the holder's portrait, home and
   day job, and one line from Renoir.
2. One rival who follows you circuit to circuit, with a running record and
   lines that change as it swings.
3. The journey map: the world with your crowns on it.
4. The last crown: what happens when all fifty are yours (the Ten of a
   Kind table).
