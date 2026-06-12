#!/usr/bin/env python3
"""
rlcard_train.py
---------------

Offline RL trainer using RLCard's official DQN/NFSP agents.

This is an experiment harness, not the Flutter runtime bot.

Examples:
  python tools/ml/rlcard_train.py --env no-limit-holdem --algorithm dqn --num-episodes 5000
  python tools/ml/rlcard_train.py --env leduc-holdem --algorithm nfsp --num-episodes 10000
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import torch

import rlcard
from rlcard.agents import RandomAgent
from rlcard.utils import get_device, reorganize, set_seed, tournament


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--env",
        default="no-limit-holdem",
        choices=[
            "blackjack",
            "leduc-holdem",
            "limit-holdem",
            "no-limit-holdem",
            "uno",
        ],
    )
    parser.add_argument(
        "--algorithm",
        default="dqn",
        choices=["dqn", "nfsp"],
    )
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--num-episodes", type=int, default=5000)
    parser.add_argument("--evaluate-every", type=int, default=250)
    parser.add_argument("--num-eval-games", type=int, default=1000)
    parser.add_argument(
        "--output-dir",
        default="tmp/rlcard_experiments/no_limit_holdem_dqn",
    )
    parser.add_argument("--cuda", default="")
    return parser.parse_args()


def build_agent(env, algorithm: str, device: str, save_path: str):
    if algorithm == "dqn":
        from rlcard.agents import DQNAgent

        return DQNAgent(
            num_actions=env.num_actions,
            state_shape=env.state_shape[0],
            mlp_layers=[128, 128],
            device=device,
            save_path=save_path,
            save_every=-1,
        )

    from rlcard.agents import NFSPAgent

    return NFSPAgent(
        num_actions=env.num_actions,
        state_shape=env.state_shape[0],
        hidden_layers_sizes=[128, 128],
        q_mlp_layers=[128, 128],
        device=device,
        save_path=save_path,
        save_every=-1,
    )


def main() -> int:
    args = parse_args()
    os.environ["CUDA_VISIBLE_DEVICES"] = args.cuda
    set_seed(args.seed)
    device = get_device()

    env = rlcard.make(
        args.env,
        config={"seed": args.seed},
    )

    agent = build_agent(
        env=env,
        algorithm=args.algorithm,
        device=device,
        save_path=args.output_dir,
    )
    agents = [agent]
    for _ in range(1, env.num_players):
        agents.append(RandomAgent(num_actions=env.num_actions))
    env.set_agents(agents)

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    history = []
    for episode in range(args.num_episodes):
        if args.algorithm == "nfsp":
            agent.sample_episode_policy()

        trajectories, payoffs = env.run(is_training=True)
        for ts in reorganize(trajectories, payoffs)[0]:
            agent.feed(ts)

        if episode % args.evaluate_every == 0:
            score = tournament(env, args.num_eval_games)[0]
            history.append({"episode": episode, "score": score})
            print(f"episode={episode} score={score:.6f}")

    model_path = out_dir / "model.pth"
    metrics_path = out_dir / "metrics.json"
    torch.save(agent, model_path)
    metrics_path.write_text(json.dumps(history, indent=2), encoding="utf-8")
    print(f"model -> {model_path}")
    print(f"metrics -> {metrics_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
