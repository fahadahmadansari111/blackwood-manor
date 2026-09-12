import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/game_state.dart';
import '../game/horror_game.dart';
import 'minimap.dart';

const Color _bone = Color(0xFFECEFF1);
const Color _blood = Color(0xFFB71C1C);
const Color _dimGray = Color(0xFF616161);
const Color _amber = Color(0xFFFFC107);
const Color _green = Color(0xFF4CAF50);

class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.gameState, required this.game});

  final GameState gameState;
  final HauntedHouseGame game;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(child: _DangerVignette(gameState: gameState)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HealthPanel(gameState: gameState),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _KeysPanel(gameState: gameState),
                          const SizedBox(height: 8),
                          MinimapWidget(game: game),
                        ],
                      ),
                    ],
                  ),
                  _InteractHint(gameState: gameState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthPanel extends StatefulWidget {
  const _HealthPanel({required this.gameState});

  final GameState gameState;

  @override
  State<_HealthPanel> createState() => _HealthPanelState();
}

class _HealthPanelState extends State<_HealthPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _jitter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _jitter.dispose();
    super.dispose();
  }

  Color _fillColor(double ratio) {
    if (ratio >= 0.5) {
      return Color.lerp(_amber, _green, (ratio - 0.5) * 2)!;
    }
    return Color.lerp(_blood, _amber, ratio * 2)!;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.gameState, _jitter]),
      builder: (context, _) {
        final health = widget.gameState.health;
        final ratio = (health / GameConstants.maxHealth).clamp(0.0, 1.0).toDouble();
        final trembling = health > 0 && health < GameConstants.lowHealthThreshold;
        final v = _jitter.value;
        final offset = trembling
            ? Offset(
                math.sin(v * math.pi * 7) * 1.6,
                math.cos(v * math.pi * 9) * 1.2,
              )
            : Offset.zero;
        return Transform.translate(
          offset: offset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HEALTH',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w600,
                  color: _dimGray,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 180,
                height: 10,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _dimGray.withValues(alpha: 0.35)),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio,
                  child: ColoredBox(color: _fillColor(ratio)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KeysPanel extends StatelessWidget {
  const _KeysPanel({required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: gameState,
      builder: (context, _) {
        final keys = gameState.keysCollected;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < GameConstants.totalKeys; i++)
              Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                child: CustomPaint(
                  size: const Size(18, 18),
                  painter: _KeyGlyphPainter(filled: i < keys),
                ),
              ),
            const SizedBox(width: 10),
            Text(
              'KEYS $keys/${GameConstants.totalKeys}',
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
                color: _dimGray,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KeyGlyphPainter extends CustomPainter {
  const _KeyGlyphPainter({required this.filled});

  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 1;
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r, center.dy)
      ..close();
    if (filled) {
      canvas.drawPath(
        path,
        Paint()
          ..color = _amber.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(path, Paint()..color = _amber);
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _dimGray,
      );
    }
  }

  @override
  bool shouldRepaint(_KeyGlyphPainter oldDelegate) =>
      oldDelegate.filled != filled;
}

class _InteractHint extends StatelessWidget {
  const _InteractHint({required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: gameState.interactHint,
      builder: (context, hint, _) {
        final text = hint.trim();
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: text.isEmpty ? 0 : 1,
          child: Text(
            text.isEmpty ? '' : text.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 3.5,
              fontWeight: FontWeight.w600,
              color: _bone,
              shadows: [
                Shadow(color: _blood.withValues(alpha: 0.85), blurRadius: 16),
                Shadow(color: Colors.black.withValues(alpha: 0.9), blurRadius: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DangerVignette extends StatefulWidget {
  const _DangerVignette({required this.gameState});

  final GameState gameState;

  @override
  State<_DangerVignette> createState() => _DangerVignetteState();
}

class _DangerVignetteState extends State<_DangerVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.gameState.ghostProximity, _pulse]),
      builder: (context, _) {
        final proximity =
            widget.gameState.ghostProximity.value.clamp(0.0, 1.0);
        if (proximity <= 0) return const SizedBox.expand();
        final pulse = 0.82 + 0.18 * math.sin(_pulse.value * math.pi * 2);
        final opacity =
            (math.pow(proximity, 1.4).toDouble() * 0.55 * pulse)
                .clamp(0.0, 1.0)
                .toDouble();
        return Opacity(
          opacity: opacity,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x00B71C1C), Color(0xE6B71C1C)],
                stops: [0.35, 1.0],
              ),
            ),
            child: SizedBox.expand(),
          ),
        );
      },
    );
  }
}
