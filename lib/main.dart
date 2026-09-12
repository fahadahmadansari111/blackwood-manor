import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/sound_bank.dart';
import 'core/constants.dart';
import 'core/game_state.dart';
import 'game/horror_game.dart';
import 'ui/death_screen.dart';
import 'ui/hud.dart';
import 'ui/menu_screen.dart';
import 'ui/outro_cinematic.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const HauntedHouseApp());
}

class HauntedHouseApp extends StatelessWidget {
  const HauntedHouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: GameConstants.gameTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const GameShell(),
    );
  }
}

class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  final GameState _gameState = GameState();
  final SoundBank _soundBank = SoundBank();
  HauntedHouseGame? _game;

  @override
  void initState() {
    super.initState();
    _soundBank.init();
  }

  @override
  void dispose() {
    unawaited(_soundBank.dispose());
    _game?.onRemove();
    _gameState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game ??=
        HauntedHouseGame(gameState: _gameState, soundBank: _soundBank);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: game),
          AnimatedBuilder(
            animation: _gameState,
            builder: (context, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  GameInputLayer(
                    game: game,
                    enabled: _gameState.isPlaying,
                    child: const SizedBox.expand(),
                  ),
                  if (_gameState.isPlaying) HudOverlay(gameState: _gameState, game: game),
                  if (_gameState.phase == GamePhase.menu)
                    MenuScreen(gameState: _gameState),
                  if (_gameState.phase == GamePhase.dead)
                    DeathScreen(gameState: _gameState),
                  if (_gameState.phase == GamePhase.outro)
                    OutroCinematic(onComplete: _gameState.backToMenu),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class GameInputLayer extends StatefulWidget {
  const GameInputLayer({
    super.key,
    required this.game,
    required this.enabled,
    required this.child,
  });

  final HauntedHouseGame game;
  final bool enabled;
  final Widget child;

  @override
  State<GameInputLayer> createState() => _GameInputLayerState();
}

class _GameInputLayerState extends State<GameInputLayer> {
  static const double _stickRadius = 72;

  int? _stickPointerId;
  Offset _stickOrigin = Offset.zero;
  int? _lookPointerId;
  double _lookLastX = 0;

  void _resetStick() {
    _stickPointerId = null;
    widget.game.moveForwardInput = 0;
    widget.game.moveStrafeInput = 0;
    widget.game.runningInput = false;
  }

  @override
  void didUpdateWidget(GameInputLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _resetStick();
      _lookPointerId = null;
    }
  }

  void _onDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    final halfWidth = MediaQuery.of(context).size.width / 2;
    if (event.localPosition.dx < halfWidth && _stickPointerId == null) {
      _stickPointerId = event.pointer;
      _stickOrigin = event.localPosition;
    } else if (_lookPointerId == null) {
      _lookPointerId = event.pointer;
      _lookLastX = event.localPosition.dx;
    }
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer == _stickPointerId) {
      var vec = (event.localPosition - _stickOrigin) / _stickRadius;
      final len = vec.distance;
      if (len > 1) vec = vec / len;
      widget.game.moveStrafeInput = vec.dx;
      widget.game.moveForwardInput = -vec.dy;
      widget.game.runningInput = len > 0.92;
    } else if (event.pointer == _lookPointerId) {
      widget.game.applyLookDelta(event.localPosition.dx - _lookLastX);
      _lookLastX = event.localPosition.dx;
    }
  }

  void _onUp(PointerEvent event) {
    if (event.pointer == _stickPointerId) {
      _resetStick();
    } else if (event.pointer == _lookPointerId) {
      _lookPointerId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled ? _onDown : null,
      onPointerMove: widget.enabled ? _onMove : null,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
