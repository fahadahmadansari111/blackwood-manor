import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:haunted_house/audio/sound_bank.dart';
import 'package:haunted_house/core/constants.dart';
import 'package:haunted_house/core/game_state.dart';
import 'package:haunted_house/game/horror_game.dart';
import 'package:haunted_house/game/house_map.dart';
import 'package:haunted_house/game/pathfinding.dart';

void main() {
  group('generated manor', () {
    test('meets gameplay constraints across seeds', () {
      for (var seed = 1; seed <= 20; seed++) {
        final map = HouseMap.generate(seed: seed);
        expect(map.grid.length, 32, reason: 'seed $seed rows');
        expect(map.grid[0].length, 32, reason: 'seed $seed cols');

        // 3 keys, far apart, away from player.
        expect(map.keySpawns.length, GameConstants.totalKeys,
            reason: 'seed $seed key count');
        final spawn = map.playerSpawn;
        for (var i = 0; i < map.keySpawns.length; i++) {
          for (var j = i + 1; j < map.keySpawns.length; j++) {
            final d = math.sqrt(
                math.pow(map.keySpawns[i].$1 - map.keySpawns[j].$1, 2) +
                    math.pow(map.keySpawns[i].$2 - map.keySpawns[j].$2, 2));
            expect(d, greaterThanOrEqualTo(14.0),
                reason: 'seed $seed keys $i/$j too close ($d)');
          }
        }

        // Every key + exit approach reachable from player spawn.
        for (final key in map.keySpawns) {
          expect(
              Pathfinding.findPath(
                map,
                math.Point(spawn.$1.floor(), spawn.$2.floor()),
                math.Point(key.$1.floor(), key.$2.floor()),
              ),
              isNotNull,
              reason: 'seed $seed key at ${key.$1},${key.$2} unreachable');
          expect(map.isSolid(key.$1, key.$2), isFalse,
              reason: 'seed $seed key inside wall');
        }
        final (ex, ey) = map.exitDoorCell;
        expect(ey, 31, reason: 'seed $seed exit must stay on south wall');
        expect(
            Pathfinding.findPath(
              map,
              math.Point(spawn.$1.floor(), spawn.$2.floor()),
              math.Point(ex, ey - 1),
            ),
            isNotNull,
            reason: 'seed $seed exit approach unreachable');

        // Spawns walkable, ghost far from player.
        expect(map.isSolid(spawn.$1, spawn.$2), isFalse);
        expect(map.isSolid(map.ghostSpawn.$1, map.ghostSpawn.$2), isFalse);
        expect(map.patrolRoutes, isNotEmpty, reason: 'seed $seed patrols');
        for (final route in map.patrolRoutes) {
          expect(route.length, greaterThanOrEqualTo(1));
          for (final w in route) {
            expect(map.isSolid(w.$1, w.$2), isFalse,
                reason: 'seed $seed waypoint in wall');
          }
        }
      }
    });

    test('produces different layouts for different seeds', () {
      String fingerprint(HouseMap m) =>
          '${m.exitDoorCell}|${m.playerSpawn}|${m.keySpawns}|${m.grid[15].join()}';
      final a = fingerprint(HouseMap.generate(seed: 1));
      final b = fingerprint(HouseMap.generate(seed: 2));
      final c = fingerprint(HouseMap.generate(seed: 3));
      expect({a, b, c}.length, greaterThan(1),
          reason: 'expected layout variety across seeds');
    });

    test('same seed reproduces the same manor', () {
      final a = HouseMap.generate(seed: 42);
      final b = HouseMap.generate(seed: 42);
      expect(a.exitDoorCell, b.exitDoorCell);
      expect(a.playerSpawn, b.playerSpawn);
      expect(a.keySpawns, b.keySpawns);
    });
  });

  group('new manor each run', () {
    test('starting a new game regenerates the map', () {
      final gs = GameState();
      final game = HauntedHouseGame(gameState: gs, soundBank: SoundBank());
      gs.startGame();
      final firstSeed = game.map.seed;
      final firstExit = game.map.exitDoorCell;
      final firstPlayer = (game.player.x, game.player.y);
      gs.backToMenu();
      gs.startGame();
      final secondSeed = game.map.seed;
      // Player/ghost/entities follow the new map spawns.
      expect((game.player.x, game.player.y), game.map.playerSpawn);
      expect((game.ghost.x, game.ghost.y), game.map.ghostSpawn);
      expect(game.entities.keys.length, GameConstants.totalKeys);
      // Seeds are random per run; layouts should differ across two runs
      // (exit X and/or player spawn move). Seeds differing proves regen.
      expect(
          firstSeed != secondSeed ||
              firstExit != game.map.exitDoorCell ||
              firstPlayer != (game.player.x, game.player.y),
          isTrue,
          reason: 'map was not regenerated on restart');
      game.onRemove();
      gs.dispose();
    });
  });
}
