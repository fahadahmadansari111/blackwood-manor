import 'package:flutter/foundation.dart';

import 'constants.dart';

enum GamePhase { menu, playing, dead, outro }

class GameState extends ChangeNotifier {
  GamePhase _phase = GamePhase.menu;
  double _health = GameConstants.maxHealth;
  int _keysCollected = 0;
  bool _exitUnlocked = false;

  final ValueNotifier<double> ghostProximity = ValueNotifier<double>(0);
  final ValueNotifier<String> interactHint = ValueNotifier<String>('');

  GamePhase get phase => _phase;
  double get health => _health;
  int get keysCollected => _keysCollected;
  bool get exitUnlocked => _exitUnlocked;
  bool get isPlaying => _phase == GamePhase.playing;

  void startGame() {
    if (_phase == GamePhase.playing) return;
    _phase = GamePhase.playing;
    _health = GameConstants.maxHealth;
    _keysCollected = 0;
    _exitUnlocked = false;
    ghostProximity.value = 0;
    interactHint.value = '';
    notifyListeners();
  }

  void collectKey() {
    if (_phase != GamePhase.playing) return;
    if (_keysCollected >= GameConstants.totalKeys) return;
    _keysCollected++;
    if (_keysCollected >= GameConstants.totalKeys) {
      _exitUnlocked = true;
    }
    notifyListeners();
  }

  void drainHealth(double amount) {
    if (_phase != GamePhase.playing || amount <= 0) return;
    final before = _health.ceil();
    _health = (_health - amount).clamp(0.0, GameConstants.maxHealth);
    if (_health <= 0) {
      die();
    } else if (_health.ceil() != before) {
      notifyListeners();
    }
  }

  void die() {
    if (_phase != GamePhase.playing) return;
    _phase = GamePhase.dead;
    ghostProximity.value = 0;
    interactHint.value = '';
    notifyListeners();
  }

  void reachExit() {
    if (!_isEscapable) return;
    _phase = GamePhase.outro;
    ghostProximity.value = 0;
    interactHint.value = '';
    notifyListeners();
  }

  void backToMenu() {
    _phase = GamePhase.menu;
    _health = GameConstants.maxHealth;
    _keysCollected = 0;
    _exitUnlocked = false;
    ghostProximity.value = 0;
    interactHint.value = '';
    notifyListeners();
  }

  bool get _isEscapable => _phase == GamePhase.playing && _exitUnlocked;

  @override
  void dispose() {
    ghostProximity.dispose();
    interactHint.dispose();
    super.dispose();
  }
}
