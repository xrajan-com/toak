# Experimental Poker AI

## What Is Implemented

This branch now supports the full experimental split:

- Fisher-Yates shuffle in the live Dart engine
- Eval7 as an offline Hold'em equity/oracle tool
- RLCard as an offline reinforcement-learning lab
- learned policy weights loaded by the Flutter app at startup

Important boundary:

- the app runtime is still Dart
- Python stays offline for research, validation, and training

That is deliberate. RLCard and Eval7 should not sit in the live Flutter hand loop.

## Why The Split Matters

### Fisher-Yates

This is already the correct live shuffle algorithm and is already in the game engine.

### Eval7

Use Eval7 for:

- external equity calculations
- validating draw/call spots
- sanity-checking the Dart win-prob path

Do not use Eval7 directly inside Flutter gameplay.

### RLCard

Use RLCard for:

- offline DQN/NFSP experiments
- self-play research
- policy benchmarking

Do not treat RLCard as your hand evaluator. That was the wrong role for it.

## Files

### Dart runtime / distillation path

- [lib/game/bot/policy_model.dart](/Users/kapilpoonia/Desktop/toak/lib/game/bot/policy_model.dart)
- [lib/game/bot/memory.dart](/Users/kapilpoonia/Desktop/toak/lib/game/bot/memory.dart)
- [lib/game/bot/safety.dart](/Users/kapilpoonia/Desktop/toak/lib/game/bot/safety.dart)
- [assets/ml/bot_policy_weights.json](/Users/kapilpoonia/Desktop/toak/assets/ml/bot_policy_weights.json)

### Dataset export

- [tools/export_bot_dataset.dart](/Users/kapilpoonia/Desktop/toak/tools/export_bot_dataset.dart)

### Python lab

- [tools/ml/requirements.txt](/Users/kapilpoonia/Desktop/toak/tools/ml/requirements.txt)
- [tools/ml/eval7_equity.py](/Users/kapilpoonia/Desktop/toak/tools/ml/eval7_equity.py)
- [tools/ml/rlcard_train.py](/Users/kapilpoonia/Desktop/toak/tools/ml/rlcard_train.py)
- [tools/train_bot_policy.py](/Users/kapilpoonia/Desktop/toak/tools/train_bot_policy.py)

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r tools/ml/requirements.txt
```

Verified package targets:

- `rlcard==1.2.0`
- `eval7==0.1.10`

## Workflow

### 1. Export a bot dataset from the Dart engine

```bash
dart run tools/export_bot_dataset.dart --hands 2000 --players 6 --output tmp/bot_logs.json
```

This simulates bot-only hands using the current Dart engine and writes decision logs.

### 2. Train lightweight runtime weights

```bash
python tools/train_bot_policy.py tmp/bot_logs.json --output assets/ml/bot_policy_weights.json
```

The app reads [bot_policy_weights.json](/Users/kapilpoonia/Desktop/toak/assets/ml/bot_policy_weights.json) on startup.

### 3. Evaluate a spot with Eval7

```bash
python tools/ml/eval7_equity.py --hero AhKh --villain "QQ+,AKs,AQo+" --board QhJh2c --iters 25000
```

### 4. Run RLCard training

```bash
python tools/ml/rlcard_train.py --env no-limit-holdem --algorithm dqn --num-episodes 5000
```

Outputs:

- PyTorch model checkpoint
- evaluation metrics JSON

## Current Limitation

RLCard training and Dart runtime are not automatically bridged yet.

Right now you have two complementary paths:

- `train_bot_policy.py` -> produces runtime weights the app can load now
- `rlcard_train.py` -> produces research models for offline comparison

If you later want RLCard output inside the app, the next step is policy distillation:

1. export RLCard policy decisions into a flat feature/action dataset
2. fit the lightweight runtime weights format against that dataset
3. keep the Dart safety layer in front of those learned deltas
