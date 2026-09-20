import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haunted_house/audio/sound_bank.dart';
import 'package:haunted_house/core/constants.dart';
import 'package:haunted_house/core/difficulty.dart';
import 'package:haunted_house/core/game_state.dart';
import 'package:haunted_house/game/ghost.dart';
import 'package:haunted_house/game/horror_game.dart';
import 'package:haunted_house/ui/expanded_map.dart';
import 'package:haunted_house/ui/hud.dart';
import 'package:haunted_house/ui/menu_screen.dart';
import 'package:haunted_house/ui/minimap.dart';

void main() {
  group('difficulty config', () {
    test('ghost counts and tuning', () {
      expect(DifficultyConfig.ghostCount(Difficulty.easy), 1);
      expect(DifficultyConfig.ghostCount(Difficulty.medium), 1);
      expect(DifficultyConfig.ghostCount(Difficulty.hard), 3);
      expect(DifficultyConfig.tuning(Difficulty.easy).drainPerSecond,
          lessThan(DifficultyConfig.tuning(Difficulty.medium).drainPerSecond));
      expect(DifficultyConfig.tuning(Difficulty.hard).drainPerSecond,
          greaterThan(
              DifficultyConfig.tuning(Difficulty.medium).drainPerSecond));
      expect(DifficultyConfig.useFixedMap(Difficulty.easy), isTrue);
      expect(DifficultyConfig.useFixedMap(Difficulty.medium), isFalse);
      expect(DifficultyConfig.useFixedMap(Difficulty.hard), isFalse);
      expect(DifficultyConfig.radarEnabled(Difficulty.hard), isFalse);
      expect(DifficultyConfig.showKeysOnRadar(Difficulty.easy), isTrue);
    });
  });

  group('mode runs', () {
    test('easy reuses the same fixed map every run', () {
      final gs = GameState();
      final game = HauntedHouseGame(gameState: gs, soundBank: SoundBank());
      gs.startGame(Difficulty.easy);
      final exit1 = game.map.exitDoorCell;
      final keys1 = game.map.keySpawns;
      expect(game.ghosts.length, 1);
      expect(game.ghost.tuning.drainPerSecond,
          DifficultyConfig.tuning(Difficulty.easy).drainPerSecond);
      gs.backToMenu();
      gs.startGame(Difficulty.easy);
      expect(game.map.exitDoorCell, exit1);
      expect(game.map.keySpawns, keys1);
      expect(game.map.seed, 0);
      game.onRemove();
      gs.dispose();
    });

    test('hard spawns three ghosts on walkable cells', () {
      final gs = GameState();
      final game = HauntedHouseGame(gameState: gs, soundBank: SoundBank());
      gs.startGame(Difficulty.hard);
      expect(game.ghosts.length, 3);
      for (final g in game.ghosts) {
        expect(game.map.isSolid(g.x, g.y), isFalse);
        expect(g.tuning.drainPerSecond,
            DifficultyConfig.tuning(Difficulty.hard).drainPerSecond);
      }
      game.onRemove();
      gs.dispose();
    });

    test('medium keeps a single medium ghost on a random manor', () {
      final gs = GameState();
      final game = HauntedHouseGame(gameState: gs, soundBank: SoundBank());
      gs.startGame(Difficulty.medium);
      expect(game.ghosts.length, 1);
      expect(game.ghost.tuning.drainPerSecond,
          GameConstants.ghostDrainPerSecond);
      game.onRemove();
      gs.dispose();
    });

    test('hard drains faster than easy at point blank', () {
      double drainFor(Difficulty d) {
        final gs = GameState();
        final game = HauntedHouseGame(gameState: gs, soundBank: SoundBank());
        gs.startGame(d);
        // Pin player next to the primary ghost.
        game.player.x = game.ghost.x + 0.4;
        game.player.y = game.ghost.y;
        game.ghost.state = GhostState.chase;
        final before = gs.health;
        game.update(0.05);
        final drained = before - gs.health;
        game.onRemove();
        gs.dispose();
        return drained;
      }

      expect(drainFor(Difficulty.hard), greaterThan(drainFor(Difficulty.easy)));
    });

    test('proximity keeps the worst threat across ghosts', () {
      final gs = GameState();
      final game = HauntedHouseGame(gameState: gs, soundBank: SoundBank());
      gs.startGame(Difficulty.hard);
      // Park extra ghosts far away; first ghost on top of the player.
      game.player.x = game.ghosts[0].x + 0.3;
      game.player.y = game.ghosts[0].y;
      game.update(0.05);
      expect(gs.ghostProximity.value, greaterThan(0.9));
      game.onRemove();
      gs.dispose();
    });
  });

  group('mode hud', () {
    testWidgets('hard radar shows blind warning', (tester) async {
      final gs = GameState();
      final game = HauntedHouseGame(gameState: gs, soundBank: SoundBank());
      gs.startGame(Difficulty.hard);
      game.update(0.09);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: HudOverlay(gameState: gs, game: game))),
      );
      await tester.pump();
      expect(find.text("DON'T LOOK HERE"), findsOneWidget);
      game.onRemove();
      gs.dispose();
    });

    testWidgets('easy tap expands and closes the seer map', (tester) async {
      final gs = GameState();
      final game = HauntedHouseGame(gameState: gs, soundBank: SoundBank());
      gs.startGame(Difficulty.easy);
      game.update(0.09);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: HudOverlay(gameState: gs, game: game))),
      );
      await tester.pump();
      expect(find.byType(ExpandedMapOverlay), findsNothing);
      // Tap the radar circle to expand.
      await tester.tap(find.byType(MinimapWidget));
      await tester.pump();
      expect(gs.mapExpanded.value, isTrue);
      expect(find.byType(ExpandedMapOverlay), findsOneWidget);
      // Tap the overlay to close.
      await tester.tap(find.byType(ExpandedMapOverlay));
      await tester.pump();
      expect(gs.mapExpanded.value, isFalse);
      expect(find.byType(ExpandedMapOverlay), findsNothing);
      game.onRemove();
      gs.dispose();
    });

    testWidgets('menu offers all three modes', (tester) async {
      final gs = GameState();
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MenuScreen(gameState: gs))),
      );
      await tester.pump();
      expect(find.text('EASY'), findsOneWidget);
      expect(find.text('MEDIUM'), findsOneWidget);
      expect(find.text('HARD'), findsOneWidget);
      // Invoke directly: tester.tap would fire Material ink splashes whose
      // shader can't compile in the headless test environment.
      tester
          .widget<OutlinedButton>(
              find.ancestor(of: find.text('HARD'), matching: find.byType(OutlinedButton)))
          .onPressed!();
      await tester.pump();
      expect(gs.phase, GamePhase.playing);
      expect(gs.difficulty, Difficulty.hard);
      gs.dispose();
    });
  });
}
