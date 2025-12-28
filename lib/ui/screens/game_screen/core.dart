// lib/game/core.dart
//
// Core, dependency-free types used across the poker engine:
// - Suits, Ranks, Phases, Actions
// - rankValue helper
// - Card model and Deck
//
// Safe to import from anywhere (evaluator, engine, UI).

import 'dart:math' show Random;

/* =============================================================
 * Core Enums & Helpers
 * ============================================================= */

enum Suit { clubs, diamonds, hearts, spades }

enum Rank { two, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace }

/// Hand/round phases for the table flow (kept here so UI can reference safely)
enum GamePhase { predeal, preflop, flop, turn, river, showdown, handOver }

/// Player actions recognized by the engine/UI
enum ActionType { fold, check, call, bet, raise, allIn }

/// Converts Rank to numeric strength (2..14)
int rankValue(Rank r) => r.index + 2;

/* =============================================================
 * Cards & Deck
 * ============================================================= */

class Card {
  final Rank rank;
  final Suit suit;

  const Card(this.rank, this.suit);

  @override
  String toString() {
    const ranks = ['2','3','4','5','6','7','8','9','T','J','Q','K','A'];
    const suits = {
      Suit.clubs: '♣',
      Suit.diamonds: '♦',
      Suit.hearts: '♥',
      Suit.spades: '♠',
    };
    return '${ranks[rank.index]}${suits[suit]}';
  }
}

class Deck {
  final List<Card> _cards = <Card>[];
  final Random _rng;

  Deck({Random? rng}) : _rng = rng ?? Random() {
    for (final s in Suit.values) {
      for (final r in Rank.values) {
        _cards.add(Card(r, s));
      }
    }
  }

  void shuffle() => _cards.shuffle(_rng);

  Card draw() {
    if (_cards.isEmpty) throw StateError('Deck is empty');
    return _cards.removeLast();
    // Note: removeLast() is O(1) and keeps draws efficient.
  }

  bool get isEmpty => _cards.isEmpty;
}