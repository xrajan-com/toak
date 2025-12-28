import 'package:flutter/material.dart';

class ProfileService extends ChangeNotifier {
  String? _displayName;
  String? _email;
  String? _avatarUrl;
  String? _userId;
  String? _rank;

  // Getters
  String? get displayName => _displayName;
  String? get email => _email;
  String? get avatarUrl => _avatarUrl;
  String? get userId => _userId;
  String? get rank => _rank;

  // Load profile from a data source (e.g., Firebase, REST API)
  Future<void> loadProfile(Map<String, dynamic> data) async {
    _displayName = data['displayName'];
    _email = data['email'];
    _avatarUrl = data['avatarUrl'];
    _userId = data['userId'];
    _rank = data['rank'];
    notifyListeners();
  }

  // Update display name
  void updateDisplayName(String newName) {
    _displayName = newName;
    notifyListeners();
    // TODO: Persist to backend
  }

  // Update avatar URL
  void updateAvatar(String newUrl) {
    _avatarUrl = newUrl;
    notifyListeners();
    // TODO: Persist to backend
  }

  // Clear profile on logout
  void clearProfile() {
    _displayName = null;
    _email = null;
    _avatarUrl = null;
    _userId = null;
    _rank = null;
    notifyListeners();
  }
}
