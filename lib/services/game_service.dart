import 'package:flutter/material.dart';

class GameService extends ChangeNotifier {
  bool _gameStarted = false;
  int _currentRound = 0;
  List<String> _players = [];

  bool get gameStarted => _gameStarted;
  int get currentRound => _currentRound;
  List<String> get players => List.unmodifiable(_players);

  void startGame(List<String> initialPlayers) {
    _players = initialPlayers;
    _gameStarted = true;
    _currentRound = 1;
    notifyListeners();
  }

  void endGame() {
    _gameStarted = false;
    _currentRound = 0;
    _players.clear();
    notifyListeners();
  }

  void nextRound() {
    if (_gameStarted) {
      _currentRound += 1;
      notifyListeners();
    }
  }

  void addPlayer(String playerId) {
    if (!_players.contains(playerId)) {
      _players.add(playerId);
      notifyListeners();
    }
  }

  void removePlayer(String playerId) {
    _players.remove(playerId);
    notifyListeners();
  }
}
