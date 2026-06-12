#!/usr/bin/env python3
"""
train_bot_policy.py
-------------------

Trains a tiny linear policy-delta model from exported bot decision logs.

Input:
- JSON array from GameEngine.exportBotDecisionLogJson()
- or JSONL from GameEngine.exportBotDecisionLogJsonLines()

Output:
- a weights file compatible with assets/ml/bot_policy_weights.json

This is intentionally small and dependency-light. It is not a poker solver.
It just learns lightweight deltas on top of the hard Dart safety layer.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List


ACTION_AGGRESSIVE = {"bet", "raise", "allIn"}
ACTION_CONTINUE = {"call", "raise", "allIn"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", help="Path to exported bot log JSON or JSONL")
    parser.add_argument(
        "--output",
        default="assets/ml/bot_policy_weights.json",
        help="Output weights path",
    )
    parser.add_argument("--epochs", type=int, default=600)
    parser.add_argument("--lr", type=float, default=0.03)
    parser.add_argument("--l2", type=float, default=0.0008)
    return parser.parse_args()


def load_rows(path: Path) -> List[dict]:
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        raise SystemExit("Input file is empty.")
    if text.startswith("["):
        rows = json.loads(text)
        if not isinstance(rows, list):
            raise SystemExit("JSON input must be an array.")
        return [dict(row) for row in rows]
    rows = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        rows.append(dict(json.loads(line)))
    return rows


def clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))


def feature_row(row: dict) -> Dict[str, float]:
    phase = str(row.get("phase") or "")
    temperament = str(row.get("temperament") or "")
    skill = str(row.get("skill") or "")
    pot = max(0, int(row.get("pot", 0)))
    to_call = max(0, int(row.get("toCall", 0)))
    stack = max(0, int(row.get("stack", 0)))
    denom = max(1, pot + to_call)
    stack_frac = 0.0 if stack <= 0 else clamp(to_call / stack, 0.0, 1.0)

    return {
        "bias": 1.0,
        "aura_skill": clamp(float(row.get("aura", 60)) / 100.0, 0.0, 1.0),
        "confidence": clamp(float(row.get("confidence", 0.5)), 0.0, 1.0),
        "strength": clamp(float(row.get("strength", 0.5)), 0.0, 1.0),
        "style_aggression": clamp(float(row.get("aggressionHeat", 0.5)) - 0.5, -0.5, 0.5),
        "style_bluff": clamp(float(row.get("bluffAppetite", 0.5)) - 0.5, -0.5, 0.5),
        "style_caution": clamp(float(row.get("caution", 0.5)) - 0.5, -0.5, 0.5),
        "style_confidence": clamp(float(row.get("styleConfidence", 0.5)) - 0.5, -0.5, 0.5),
        "field_fold_rate": clamp(float(row.get("fieldFoldRate", 0.5)) - 0.5, -0.5, 0.5),
        "field_aggression": clamp(float(row.get("fieldAggression", 0.5)) - 0.5, -0.5, 0.5),
        "aggressor_aggression": clamp(float(row.get("aggressorAggression", 0.5)) - 0.5, -0.5, 0.5),
        "aggressor_solidity": clamp(float(row.get("aggressorSolidity", 0.5)) - 0.5, -0.5, 0.5),
        "pot_odds": clamp(to_call / denom, 0.0, 1.0),
        "stack_frac": stack_frac,
        "live_opponents": clamp(float(row.get("liveOpponents", 0)) / 8.0, 0.0, 1.0),
        "has_to_call": 1.0 if row.get("hasToCall") else 0.0,
        "multiway": 1.0 if row.get("multiway") else 0.0,
        "facing_all_in": 1.0 if row.get("facingAllIn") else 0.0,
        "revenge_spot": 1.0 if row.get("revengeSpot") else 0.0,
        "phase_preflop": 1.0 if phase == "preflop" else 0.0,
        "phase_flop": 1.0 if phase == "flop" else 0.0,
        "phase_turn": 1.0 if phase == "turn" else 0.0,
        "phase_river": 1.0 if phase == "river" else 0.0,
        "temper_aggressive": 1.0 if temperament == "aggressive" else 0.0,
        "temper_stoic": 1.0 if temperament == "stoic" else 0.0,
        "temper_worldchamp": 1.0 if temperament == "worldChamp" else 0.0,
        "skill_killer": 1.0 if skill == "killer" else 0.0,
        "skill_fluke": 1.0 if skill == "fluke" else 0.0,
    }


def target_call_bias(row: dict) -> float:
    if not row.get("hasToCall"):
        return 0.0
    action = str(row.get("action") or "")
    if action == "fold":
        return -1.0
    if action in ACTION_CONTINUE:
        return 1.0
    return 0.2


def target_raise_bias(row: dict) -> float:
    action = str(row.get("action") or "")
    if action in ACTION_AGGRESSIVE:
        return 1.0
    if action in {"call", "check"}:
        return -0.35
    return -0.6


def target_bluff_bias(row: dict) -> float:
    action = str(row.get("action") or "")
    strength = float(row.get("strength", 0.5))
    confidence = float(row.get("confidence", 0.5))
    weak = strength < 0.46 and confidence < 0.76
    if not weak:
        return 0.0
    if action in ACTION_AGGRESSIVE:
        return 1.0
    if action in {"check", "fold"}:
        return -1.0
    return -0.4


def target_value_bias(row: dict) -> float:
    action = str(row.get("action") or "")
    strength = float(row.get("strength", 0.5))
    strong = strength >= 0.60
    if not strong:
        return 0.0
    if action in ACTION_AGGRESSIVE:
        return 1.0
    if action in {"call", "check"}:
        return -0.6
    return -1.0


def target_size_factor(row: dict) -> float:
    action = str(row.get("action") or "")
    if action not in ACTION_AGGRESSIVE:
        return 1.0
    pot = max(1, int(row.get("pot", 0)))
    to_amount = max(0, int(row.get("toAmount", 0)))
    if to_amount <= 0:
        return 1.0
    raw = to_amount / pot
    return clamp(raw, 0.75, 1.30)


def train_linear(
    features: List[Dict[str, float]],
    targets: List[float],
    epochs: int,
    lr: float,
    l2: float,
) -> Dict[str, float]:
    names = sorted(features[0].keys())
    weights = {name: 0.0 for name in names}

    for _ in range(epochs):
        grads = {name: 0.0 for name in names}
        count = max(1, len(features))
        for row, target in zip(features, targets):
            pred = sum(weights[name] * row[name] for name in names)
            error = pred - target
            for name in names:
                grads[name] += error * row[name]
        for name in names:
            grad = grads[name] / count + (weights[name] * l2)
            weights[name] -= lr * grad

    return weights


def flatten_weights(
    call_weights: Dict[str, float],
    raise_weights: Dict[str, float],
    bluff_weights: Dict[str, float],
    value_weights: Dict[str, float],
    size_weights: Dict[str, float],
) -> dict:
    feature_names = sorted(
        set(call_weights)
        | set(raise_weights)
        | set(bluff_weights)
        | set(value_weights)
        | set(size_weights)
    )

    feature_weights = {}
    for name in feature_names:
        if name == "bias":
            continue
        feature_weights[name] = {
            "callBias": round(call_weights.get(name, 0.0), 6),
            "raiseBias": round(raise_weights.get(name, 0.0), 6),
            "bluffBias": round(bluff_weights.get(name, 0.0), 6),
            "valueBias": round(value_weights.get(name, 0.0), 6),
            "sizeFactor": round(1.0 + size_weights.get(name, 0.0), 6),
        }

    return {
        "version": 1,
        "intercept": {
            "callBias": round(call_weights.get("bias", 0.0), 6),
            "raiseBias": round(raise_weights.get("bias", 0.0), 6),
            "bluffBias": round(bluff_weights.get("bias", 0.0), 6),
            "valueBias": round(value_weights.get("bias", 0.0), 6),
            "sizeFactor": round(1.0 + size_weights.get("bias", 0.0), 6),
        },
        "featureWeights": feature_weights,
    }


def summarize(rows: List[dict]) -> None:
    aggressive = sum(1 for row in rows if str(row.get("action")) in ACTION_AGGRESSIVE)
    continue_count = sum(1 for row in rows if str(row.get("action")) in ACTION_CONTINUE)
    print(f"rows: {len(rows)}")
    print(f"aggressive actions: {aggressive}")
    print(f"continue actions: {continue_count}")


def main() -> int:
    args = parse_args()
    rows = load_rows(Path(args.input))
    if len(rows) < 20:
        raise SystemExit("Need at least 20 log rows to train a useful experimental model.")

    features = [feature_row(row) for row in rows]
    call_targets = [target_call_bias(row) for row in rows]
    raise_targets = [target_raise_bias(row) for row in rows]
    bluff_targets = [target_bluff_bias(row) for row in rows]
    value_targets = [target_value_bias(row) for row in rows]
    size_targets = [target_size_factor(row) - 1.0 for row in rows]

    call_weights = train_linear(features, call_targets, args.epochs, args.lr, args.l2)
    raise_weights = train_linear(features, raise_targets, args.epochs, args.lr, args.l2)
    bluff_weights = train_linear(features, bluff_targets, args.epochs, args.lr, args.l2)
    value_weights = train_linear(features, value_targets, args.epochs, args.lr, args.l2)
    size_weights = train_linear(features, size_targets, args.epochs, args.lr, args.l2)

    payload = flatten_weights(
        call_weights=call_weights,
        raise_weights=raise_weights,
        bluff_weights=bluff_weights,
        value_weights=value_weights,
        size_weights=size_weights,
    )

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    summarize(rows)
    print(f"wrote weights -> {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
