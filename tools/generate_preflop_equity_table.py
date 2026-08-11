#!/usr/bin/env python3
"""Generate the bundled 169-class Hold'em preflop equity table.

Each hand class is sampled once per trial against nine random opponents. That
single deal supplies results for every table size from heads-up through
10-handed, making the generated table both high quality and reproducible.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import random
from pathlib import Path

import eval7


RANKS = "AKQJT98765432"
SUITS = "shdc"


def representative_cards(hand_class: str) -> tuple[eval7.Card, eval7.Card]:
    high = hand_class[0]
    low = hand_class[1]
    if high == low:
        return eval7.Card(high + "s"), eval7.Card(low + "h")
    if hand_class.endswith("s"):
        return eval7.Card(high + "s"), eval7.Card(low + "s")
    return eval7.Card(high + "s"), eval7.Card(low + "h")


def hand_classes() -> list[str]:
    result: list[str] = []
    for high_index, high in enumerate(RANKS):
        result.append(high + high)
        for low in RANKS[high_index + 1 :]:
            result.append(high + low + "s")
            result.append(high + low + "o")
    return result


def generate_class(
    task: tuple[int, str, int, int],
) -> tuple[int, str, list[float]]:
    class_index, hand_class, samples, seed = task
    full_deck = [eval7.Card(rank + suit) for rank in RANKS for suit in SUITS]
    hero = representative_cards(hand_class)
    dead = {str(card) for card in hero}
    deck = [card for card in full_deck if str(card) not in dead]
    rng = random.Random(seed + class_index * 104729)
    wins = [0.0] * 9
    ties = [0.0] * 9
    equities = [0.0] * 9

    for _ in range(samples):
        rng.shuffle(deck)
        board = deck[:5]
        hero_value = eval7.evaluate(list(hero) + board)
        hero_best = True
        tie_count = 1
        for opponent_index in range(9):
            start = 5 + opponent_index * 2
            opponent_value = eval7.evaluate(deck[start : start + 2] + board)
            if opponent_value > hero_value:
                hero_best = False
            elif opponent_value == hero_value:
                tie_count += 1
            if hero_best:
                if tie_count == 1:
                    wins[opponent_index] += 1
                else:
                    ties[opponent_index] += 1
                equities[opponent_index] += 1 / tie_count

    flattened: list[float] = []
    for index in range(9):
        flattened.extend(
            (
                wins[index] / samples,
                ties[index] / samples,
                equities[index] / samples,
            )
        )
    return class_index, hand_class, flattened


def generate(samples: int, seed: int, workers: int) -> dict[str, list[float]]:
    classes = hand_classes()
    tasks = [
        (class_index, hand_class, samples, seed)
        for class_index, hand_class in enumerate(classes)
    ]
    completed: dict[int, tuple[str, list[float]]] = {}
    with concurrent.futures.ProcessPoolExecutor(max_workers=workers) as pool:
        for class_index, hand_class, values in pool.map(generate_class, tasks):
            completed[class_index] = (hand_class, values)
            print(f"{len(completed):3d}/169 {hand_class}", flush=True)
    return {
        completed[index][0]: completed[index][1]
        for index in range(len(classes))
    }


def render(values: dict[str, list[float]], samples: int) -> str:
    rows = []
    for key, row in values.items():
        formatted = ", ".join(f"{value:.6f}" for value in row)
        rows.append(f"  '{key}': <double>[{formatted}],")
    body = "\n".join(rows)
    return f"""// GENERATED FILE. Run tools/generate_preflop_equity_table.py to refresh.
// {samples:,} deterministic deals per hand class and table size.

import 'dart:math' as math;

import '../core.dart' show Card, rankValue;

const int preflopEquitySamplesPerClass = {samples};

class PreflopEquityValue {{
  final double winProbability;
  final double tieProbability;
  final double equity;
  final int samples;

  const PreflopEquityValue({{
    required this.winProbability,
    required this.tieProbability,
    required this.equity,
    required this.samples,
  }});

  double get marginOfError95 {{
    final variance = equity * (1 - equity);
    return 1.96 * math.sqrt(variance / samples);
  }}
}}

PreflopEquityValue? lookupPreflopEquity(
  List<Card> hole,
  int livePlayers,
) {{
  if (hole.length < 2 || livePlayers < 2 || livePlayers > 10) return null;
  final String key = canonicalPreflopClass(hole[0], hole[1]);
  final List<double>? row = _preflopEquities[key];
  if (row == null) return null;
  final int offset = (livePlayers - 2) * 3;
  return PreflopEquityValue(
    winProbability: row[offset],
    tieProbability: row[offset + 1],
    equity: row[offset + 2],
    samples: preflopEquitySamplesPerClass,
  );
}}

String canonicalPreflopClass(Card first, Card second) {{
  const symbols = <String>[
    '2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A',
  ];
  final int firstValue = rankValue(first.rank);
  final int secondValue = rankValue(second.rank);
  final int high = firstValue >= secondValue ? firstValue : secondValue;
  final int low = firstValue >= secondValue ? secondValue : firstValue;
  final String ranks = '${{symbols[high - 2]}}${{symbols[low - 2]}}';
  if (high == low) return ranks;
  return '$ranks${{first.suit == second.suit ? 's' : 'o'}}';
}}

const Map<String, List<double>> _preflopEquities = <String, List<double>>{{
{body}
}};
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", type=int, default=50_000)
    parser.add_argument("--seed", type=int, default=20260718)
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("lib/game/equity/preflop_equity_table.dart"),
    )
    args = parser.parse_args()
    values = generate(max(1, args.samples), args.seed, max(1, args.workers))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render(values, max(1, args.samples)), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
