import 'package:flutter/material.dart';

class StatService extends ChangeNotifier {
  int _gamesPlayed = 0;
  int _wins = 0;
  int _losses = 0;
  double _winRate = 0;

  // Never invent rankings. A caller without an authoritative source sees an
  // honest empty state.
  final List<Map<String, dynamic>> _leaderboard = const [];

  // Getters
  int get gamesPlayed => _gamesPlayed;
  int get wins => _wins;
  int get losses => _losses;
  double get winRate => _winRate;

  // Get leaderboard
  List<Map<String, dynamic>> getLeaderboard() {
    return _leaderboard;
  }

  // Load stats (e.g. from backend or Firestore)
  Future<void> loadStats(Map<String, dynamic> data) async {
    _gamesPlayed = data['gamesPlayed'] ?? 0;
    _wins = data['wins'] ?? 0;
    _losses = data['losses'] ?? 0;
    _calculateWinRate();
    notifyListeners();
  }

  void _calculateWinRate() {
    if (_gamesPlayed > 0) {
      _winRate = (_wins / _gamesPlayed) * 100;
    } else {
      _winRate = 0;
    }
  }

  void incrementGamesPlayed() {
    _gamesPlayed++;
    _calculateWinRate();
    notifyListeners();
  }

  void incrementWins() {
    _wins++;
    _gamesPlayed++;
    _calculateWinRate();
    notifyListeners();
  }

  void incrementLosses() {
    _losses++;
    _gamesPlayed++;
    _calculateWinRate();
    notifyListeners();
  }

  void clearStats() {
    _gamesPlayed = 0;
    _wins = 0;
    _losses = 0;
    _winRate = 0;
    notifyListeners();
  }
}
