#!/usr/bin/env python3
"""
eval7_equity.py
---------------

Monte Carlo equity calculator using Eval7.

Examples:
  python tools/ml/eval7_equity.py --hero AhKh --villain "QQ+,AKs,AQo+" --board QhJh2c
  python tools/ml/eval7_equity.py --hero 7h6h --villain "22+,A2s+,KTs+,QJs,JTs,ATo+,KQo" --iters 25000
"""

from __future__ import annotations

import argparse
import random
from typing import List, Sequence, Tuple

import eval7


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hero", required=True, help="Two-card hero hand, e.g. AhKh")
    parser.add_argument(
        "--villain",
        required=True,
        help='Villain range string, e.g. "QQ+,AKs,AQo+"',
    )
    parser.add_argument(
        "--board",
        default="",
        help="Board cards as a flat string, e.g. QhJh2c or QhJh2c9dTs",
    )
    parser.add_argument("--iters", type=int, default=20000)
    parser.add_argument("--seed", type=int, default=42)
    return parser.parse_args()


def parse_cards(flat: str) -> List[eval7.Card]:
    flat = flat.strip()
    if not flat:
        return []
    if len(flat) % 2 != 0:
        raise ValueError(f"Invalid card string length: {flat}")
    return [eval7.Card(flat[i : i + 2]) for i in range(0, len(flat), 2)]


def sample_weighted_hand(
    range_obj: eval7.HandRange,
    dead_cards: Sequence[eval7.Card],
    rng: random.Random,
) -> Tuple[eval7.Card, eval7.Card]:
    dead = {str(card) for card in dead_cards}
    options = []
    for hand, weight in range_obj.hands:
        if weight <= 0:
            continue
        c1, c2 = hand
        if str(c1) in dead or str(c2) in dead:
            continue
        options.append(((c1, c2), float(weight)))

    if not options:
        raise RuntimeError("No valid villain combos remain after removing dead cards.")

    total = sum(weight for _, weight in options)
    roll = rng.random() * total
    cursor = 0.0
    for hand, weight in options:
        cursor += weight
        if roll <= cursor:
            return hand
    return options[-1][0]


def remaining_deck(dead_cards: Sequence[eval7.Card]) -> List[eval7.Card]:
    dead = {str(card) for card in dead_cards}
    deck = eval7.Deck()
    return [card for card in deck.cards if str(card) not in dead]


def main() -> int:
    args = parse_args()
    hero = parse_cards(args.hero)
    board = parse_cards(args.board)
    if len(hero) != 2:
        raise SystemExit("--hero must contain exactly two cards")
    if len(board) > 5:
        raise SystemExit("--board may contain at most five cards")

    villain_range = eval7.HandRange(args.villain)
    rng = random.Random(args.seed)

    hero_score = 0.0
    trials = max(1, args.iters)
    board_missing = 5 - len(board)

    for _ in range(trials):
        villain = sample_weighted_hand(villain_range, hero + board, rng)
        deck = remaining_deck(hero + board + list(villain))
        rng.shuffle(deck)
        runout = board + deck[:board_missing]

        hero_value = eval7.evaluate(hero + runout)
        villain_value = eval7.evaluate(list(villain) + runout)

        if hero_value > villain_value:
            hero_score += 1.0
        elif hero_value == villain_value:
            hero_score += 0.5

    equity = hero_score / trials
    print(f"hero={args.hero} villain={args.villain}")
    print(f"board={args.board or '-'} trials={trials}")
    print(f"equity={equity:.6f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
