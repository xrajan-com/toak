// lib/game/rng.dart
//
// Deterministic PCG32 random number generator used for shuffling cards.
// Provides reproducible sequences (for certification/audit) while allowing
// cryptographically strong seeding via Random.secure() when desired.

import 'dart:math' as math;

class Pcg32 {
  static final BigInt _multiplier = BigInt.parse('6364136223846793005');
  static final BigInt _mask64 = BigInt.parse('0xFFFFFFFFFFFFFFFF');
  static final BigInt _mask32 = BigInt.parse('0xFFFFFFFF');
  static final BigInt _defaultStream = BigInt.parse('0x9E3779B97F4A7C15');
  static final BigInt _twoPow32 = BigInt.one << 32;

  BigInt _state = BigInt.zero;
  BigInt _increment = BigInt.zero;
  BigInt _seed = BigInt.zero;

  Pcg32({int? seed, BigInt? bigSeed, BigInt? stream}) {
    final BigInt effectiveSeed =
        bigSeed ?? (seed != null ? BigInt.from(seed) : _defaultSeed());
    reseed(seed: effectiveSeed, stream: stream);
  }

  Pcg32._internal(this._state, this._increment, this._seed);

  Pcg32 copy() => Pcg32._internal(_state, _increment, _seed);

  void reseed({required BigInt seed, BigInt? stream}) {
    final BigInt seq = stream ?? _defaultStream;
    _seed = seed & _mask64;
    _increment = ((seq << 1) | BigInt.one) & _mask64;
    _state = BigInt.zero;
    _advance();
    _state = (_state + _seed) & _mask64;
    _advance();
  }

  BigInt get seedBigInt => _seed & _mask64;
  BigInt get streamBigInt => _increment & _mask64;

  int nextUint32() {
    final BigInt oldState = _state;
    _advance();
    final BigInt xorshifted = (((oldState >> 18) ^ oldState) >> 27) & _mask32;
    final int rot = ((oldState >> 59) & BigInt.from(31)).toInt();
    return _rotateRight32(xorshifted.toInt(), rot);
  }

  int nextInt(int bound) {
    if (bound <= 0) {
      throw ArgumentError.value(bound, 'bound', 'Must be > 0');
    }
    final BigInt boundBig = BigInt.from(bound);
    final int threshold = (_twoPow32 % boundBig).toInt();
    while (true) {
      final int r = nextUint32();
      if (r >= threshold) {
        return r % bound;
      }
    }
  }

  double nextDouble() {
    final int r = nextUint32();
    return (r & 0xFFFFFFFF) / 0x100000000;
  }

  void _advance() {
    _state = (_state * _multiplier + _increment) & _mask64;
  }

  static int _rotateRight32(int value, int rot) {
    return ((value >> rot) | (value << ((32 - rot) & 31))) & 0xFFFFFFFF;
  }

  static BigInt _defaultSeed() {
    try {
      final secure = math.Random.secure();
      final int hi = secure.nextInt(0x100000000);
      final int lo = secure.nextInt(0x100000000);
      return ((BigInt.from(hi) << 32) | BigInt.from(lo)) & _mask64;
    } catch (_) {
      // Fallback to clock if secure RNG unavailable (should be rare).
      final int micros = DateTime.now().microsecondsSinceEpoch;
      final int extra = ((micros << 17) ^ micros) & 0xFFFFFFFF;
      return ((BigInt.from(micros) << 32) | BigInt.from(extra)) & _mask64;
    }
  }
}
