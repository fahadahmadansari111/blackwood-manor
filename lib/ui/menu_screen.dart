import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/difficulty.dart';
import '../core/game_state.dart';

const Color _bone = Color(0xFFECEFF1);
const Color _blood = Color(0xFFB71C1C);
const Color _dimGray = Color(0xFF616161);

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 5),
            const _FlickeringTitle(),
            const SizedBox(height: 16),
            Text(
              'find the three keys · escape alive',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 3,
                color: _bone.withValues(alpha: 0.55),
              ),
            ),
            const Spacer(flex: 4),
            for (final difficulty in Difficulty.values) ...[
              _ModeButton(gameState: gameState, difficulty: difficulty),
              const SizedBox(height: 12),
            ],
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                'left thumb: move · right thumb: look',
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: _dimGray,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.gameState, required this.difficulty});

  final GameState gameState;
  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final isHard = difficulty == Difficulty.hard;
    final border = isHard ? _blood : _dimGray;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              if (isHard)
                BoxShadow(
                  color: _blood.withValues(alpha: 0.40),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              if (isHard)
                BoxShadow(
                  color: _blood.withValues(alpha: 0.18),
                  blurRadius: 64,
                  spreadRadius: 10,
                ),
            ],
          ),
          child: OutlinedButton(
            onPressed: () => gameState.startGame(difficulty),
            style: OutlinedButton.styleFrom(
              foregroundColor: _bone,
              backgroundColor: Colors.black,
              side: BorderSide(color: border, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 48,
                vertical: 12,
              ),
            ),
            child: Text(
              DifficultyConfig.label(difficulty),
              style: const TextStyle(
                fontSize: 20,
                letterSpacing: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DifficultyConfig.tagline(difficulty),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            color: _bone.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

class _FlickeringTitle extends StatefulWidget {
  const _FlickeringTitle();

  @override
  State<_FlickeringTitle> createState() => _FlickeringTitleState();
}

class _FlickeringTitleState extends State<_FlickeringTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flicker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4300),
  )..repeat();

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  double _titleAlpha(double t) {
    final base = 0.88 + 0.07 * math.sin(t * math.pi * 2);
    var dips = math.pow(math.sin(t * math.pi * 2 * 3.3 + 0.6), 30).toDouble() *
            0.50 +
        math.pow(math.sin(t * math.pi * 2 * 8.1), 60).toDouble() * 0.55;
    final phase = t % 1.0;
    if (phase > 0.63 && phase < 0.70) {
      dips += 0.30 * math.sin((phase - 0.63) / 0.07 * math.pi);
    }
    return (base - dips).clamp(0.12, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flicker,
      builder: (context, _) {
        return Opacity(
          opacity: _titleAlpha(_flicker.value),
          child: Text(
            GameConstants.gameTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              letterSpacing: 7,
              height: 1.1,
              color: _bone,
              shadows: [
                Shadow(color: _blood.withValues(alpha: 0.90), blurRadius: 28),
                Shadow(color: _blood.withValues(alpha: 0.45), blurRadius: 64),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.80),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
