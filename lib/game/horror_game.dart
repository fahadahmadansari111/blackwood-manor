import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../audio/sound_bank.dart';
import '../core/constants.dart';
import '../core/game_state.dart';
import 'entities.dart';
import 'ghost.dart';
import 'house_map.dart';
import 'player.dart';
import 'raycast_renderer.dart';

class HauntedHouseGame extends Game {
  HauntedHouseGame({required this.gameState, required this.soundBank}) {
    ghost.onAggro = () => soundBank.play(Sfx.ghostAggro);
    ghost.onDrainTick = () {
      _hurtPulse = math.min(1.0, _hurtPulse + 0.55);
      HapticFeedback.heavyImpact();
    };
    gameState.addListener(_onPhaseChanged);
  }

  final GameState gameState;
  final SoundBank soundBank;

  final HouseMap map = HouseMap();
  final Ghost ghost =
      Ghost(GameConstants.ghostSpawnX, GameConstants.ghostSpawnY);
  final RaycastRenderer renderer = const RaycastRenderer();

  Player player = Player();
  WorldEntities entities = WorldEntities(spawns: const []);

  double moveForwardInput = 0;
  double moveStrafeInput = 0;
  bool runningInput = false;

  double _time = 0;
  double _hurtPulse = 0;
  double _lockedThudCooldown = 0;
  double _minimapAccum = 0;
  bool _nearLockedDoor = false;
  bool _exitWasOpen = false;
  GamePhase _prevPhase = GamePhase.menu;

  /// Throttled tick (~12Hz) driving the Flutter minimap repaint.
  /// Avoids rebuilding Flutter widgets at the full 60fps game rate.
  final ValueNotifier<int> minimapTick = ValueNotifier<int>(0);
  static const double minimapTickInterval = 0.08;

  void applyLookDelta(double dxPixels) {
    player.angle += dxPixels * 0.0045;
    if (player.angle > math.pi) player.angle -= 2 * math.pi;
    if (player.angle < -math.pi) player.angle += 2 * math.pi;
  }

  void _startRun() {
    map.exitOpen = false;
    player = Player();
    entities = WorldEntities(spawns: map.keySpawns);
    ghost.reset();
    _hurtPulse = 0;
    _lockedThudCooldown = 0;
    _nearLockedDoor = false;
    _exitWasOpen = false;
    _minimapAccum = 0;
    minimapTick.value = 0;
    moveForwardInput = 0;
    moveStrafeInput = 0;
    runningInput = false;
    soundBank.startAmbient();
  }

  void _onPhaseChanged() {
    final phase = gameState.phase;
    if (phase == GamePhase.playing && _prevPhase != GamePhase.playing) {
      _startRun();
    } else if (phase == GamePhase.dead && _prevPhase == GamePhase.playing) {
      soundBank.play(Sfx.jumpscare);
      soundBank.stopAmbient();
    } else if (phase == GamePhase.outro) {
      soundBank.stopAmbient();
      gameState.interactHint.value = '';
    }
    _prevPhase = phase;
  }

  @override
  void update(double dt) {
    if (dt.isNaN) return;
    _time += dt;
    _hurtPulse = math.max(0, _hurtPulse - dt * 1.5);
    _lockedThudCooldown = math.max(0, _lockedThudCooldown - dt);
    _minimapAccum += dt;
    if (_minimapAccum >= minimapTickInterval) {
      _minimapAccum = 0;
      minimapTick.value++;
    }
    if (!gameState.isPlaying) return;

    final clampedDt = dt.clamp(0.0, 0.05).toDouble();
    player.moveForward = moveForwardInput;
    player.moveStrafe = moveStrafeInput;
    player.running = runningInput;
    player.update(clampedDt, map);
    ghost.update(clampedDt, map, player, gameState);

    final collected = entities.tryCollect(player, gameState);
    if (collected > 0) {
      soundBank.play(Sfx.keyPickup);
    }
    if (!_exitWasOpen && gameState.exitUnlocked) {
      map.openExit();
      soundBank.play(Sfx.unlockCreak);
    }
    _exitWasOpen = map.exitOpen;

    soundBank.setTension(gameState.ghostProximity.value);
    _handleExitDoor();
  }

  void _setHint(String hint) {
    if (gameState.interactHint.value != hint) {
      gameState.interactHint.value = hint;
    }
  }

  void _handleExitDoor() {
    final (cx, cy) = map.exitDoorCell;
    final dx = player.x - (cx + 0.5);
    final dy = player.y - (cy + 0.5);
    final dist = math.sqrt(dx * dx + dy * dy);

    if (!map.exitOpen) {
      if (dist < GameConstants.exitInteractDistance) {
        _setHint(
            'THE MAIN DOOR IS LOCKED — KEYS ${gameState.keysCollected}/${GameConstants.totalKeys}');
        if (!_nearLockedDoor && _lockedThudCooldown <= 0) {
          soundBank.play(Sfx.doorLocked);
          _lockedThudCooldown = 1.8;
          HapticFeedback.mediumImpact();
        }
        _nearLockedDoor = true;
      } else {
        _setHint('');
        _nearLockedDoor = false;
      }
    } else {
      if (dist < GameConstants.exitInteractDistance) {
        _setHint('THE WAY IS OPEN — ESCAPE NOW');
      } else {
        _setHint('');
      }
      if (player.x.floor() == cx && player.y.floor() == cy || dist < 0.6) {
        gameState.reachExit();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) return;
    final sprites = entities.billboards(_time);
    sprites.add(SpriteBillboard(
      x: ghost.x,
      y: ghost.y,
      kind: SpriteKind.ghost,
      scale: GameConstants.ghostBillboardScale,
    ));
    renderer.render(
      canvas,
      size.toSize(),
      map: map,
      player: player,
      sprites: sprites,
      time: _time,
      hurtPulse: _hurtPulse,
    );
  }

  @override
  void onRemove() {
    gameState.removeListener(_onPhaseChanged);
    minimapTick.dispose();
    super.onRemove();
  }
}
