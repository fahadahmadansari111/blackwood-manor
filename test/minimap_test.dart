import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haunted_house/audio/sound_bank.dart';
import 'package:haunted_house/core/game_state.dart';
import 'package:haunted_house/game/horror_game.dart';
import 'package:haunted_house/ui/hud.dart';
import 'package:haunted_house/ui/minimap.dart';

void main() {
  group('MinimapMath.project (player faces up)', () {
    test('entity straight ahead maps to up', () {
      final off = MinimapMath.project(
        playerX: 16.5,
        playerY: 26.5,
        playerAngle: -math.pi / 2,
        entityX: 16.5,
        entityY: 20.5,
        range: 9,
        radius: 60,
      );
      expect(off.dx, closeTo(0, 1e-9));
      expect(off.dy, lessThan(0));
      expect(off.distance, closeTo(60 / 9 * 6, 1e-6));
    });

    test('entity behind maps to down', () {
      final off = MinimapMath.project(
        playerX: 16.5,
        playerY: 26.5,
        playerAngle: -math.pi / 2,
        entityX: 16.5,
        entityY: 28.5,
        range: 9,
        radius: 60,
      );
      expect(off.dx, closeTo(0, 1e-9));
      expect(off.dy, greaterThan(0));
    });

    test('rotates with player: east is right when facing north', () {
      final off = MinimapMath.project(
        playerX: 10,
        playerY: 10,
        playerAngle: -math.pi / 2,
        entityX: 12,
        entityY: 10,
        range: 9,
        radius: 90,
      );
      expect(off.dx, greaterThan(0));
      expect(off.dy, closeTo(0, 1e-9));
    });

    test('ahead stays up after 90deg turn', () {
      final off = MinimapMath.project(
        playerX: 10,
        playerY: 10,
        playerAngle: 0,
        entityX: 12,
        entityY: 10,
        range: 9,
        radius: 90,
      );
      expect(off.dx, closeTo(0, 1e-9));
      expect(off.dy, lessThan(0));
    });

    test('far entities clamp to edge radius', () {
      final off = MinimapMath.project(
        playerX: 16.5,
        playerY: 26.5,
        playerAngle: -math.pi / 2,
        entityX: 16.5,
        entityY: 6.5,
        range: 9,
        radius: 60,
      );
      expect(off.distance, closeTo(60, 1e-6));
      expect(off.dy, lessThan(0));
    });

    test('zero distance returns center', () {
      final off = MinimapMath.project(
        playerX: 5,
        playerY: 5,
        playerAngle: 0.7,
        entityX: 5,
        entityY: 5,
        range: 9,
        radius: 60,
      );
      expect(off, Offset.zero);
    });
  });

  group('MinimapMath.isGhostVisible (proximity only)', () {
    test('hidden beyond range', () {
      expect(
        MinimapMath.isGhostVisible(dist: 12, range: 9, hasLineOfSight: true),
        isFalse,
      );
    });

    test('hidden without line of sight inside range', () {
      expect(
        MinimapMath.isGhostVisible(dist: 5, range: 9, hasLineOfSight: false),
        isFalse,
      );
    });

    test('visible with line of sight inside range', () {
      expect(
        MinimapMath.isGhostVisible(dist: 5, range: 9, hasLineOfSight: true),
        isTrue,
      );
    });

    test('point-blank visible even without LOS', () {
      expect(
        MinimapMath.isGhostVisible(dist: 0.5, range: 9, hasLineOfSight: false),
        isTrue,
      );
    });
  });

  group('minimap tick', () {
    test('game update advances throttled tick', () {
      final gs = GameState();
      final game = HauntedHouseGame(gameState: gs, soundBank: SoundBank());
      final before = game.minimapTick.value;
      game.update(0.09);
      expect(game.minimapTick.value, before + 1);
      game.onRemove();
      gs.dispose();
    });
  });

  group('minimap widget', () {
    testWidgets('hud shows radar top-right with player, ghost, exit',
        (tester) async {
      final gs = GameState()..startGame();
      final game = HauntedHouseGame(gameState: gs, soundBank: SoundBank());
      game.update(0.09);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: HudOverlay(gameState: gs, game: game))),
      );
      await tester.pump();
      expect(find.byType(MinimapWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      game.onRemove();
      gs.dispose();
    });
  });
}
