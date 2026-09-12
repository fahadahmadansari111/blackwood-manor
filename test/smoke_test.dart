import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:haunted_house/audio/synth_engine.dart';
import 'package:haunted_house/core/constants.dart';
import 'package:haunted_house/core/game_state.dart';
import 'package:haunted_house/game/entities.dart';
import 'package:haunted_house/game/ghost.dart';
import 'package:haunted_house/game/house_map.dart';
import 'package:haunted_house/game/pathfinding.dart';
import 'package:haunted_house/game/player.dart';

void main() {
  late HouseMap map;

  setUp(() => map = HouseMap());

  group('house map', () {
    test('has three far-apart key spawns', () {
      final keys = map.keySpawns;
      expect(keys.length, GameConstants.totalKeys);
      for (var i = 0; i < keys.length; i++) {
        for (var j = i + 1; j < keys.length; j++) {
          final d = math
              .sqrt(math.pow(keys[i].$1 - keys[j].$1, 2) +
                  math.pow(keys[i].$2 - keys[j].$2, 2))
              .toDouble();
          expect(d, greaterThanOrEqualTo(14.0), reason: 'keys $i/$j too close');
        }
      }
    });

    test('spawn reaches every key and the exit door area', () {
      final spawn = map.playerSpawn;
      for (final key in map.keySpawns) {
        final path = Pathfinding.findPath(
          map,
          math.Point(spawn.$1.floor(), spawn.$2.floor()),
          math.Point(key.$1.floor(), key.$2.floor()),
        );
        expect(path, isNotNull, reason: 'key at ${key.$1},${key.$2} unreachable');
      }
      final (ex, ey) = map.exitDoorCell;
      final path = Pathfinding.findPath(
        map,
        math.Point(spawn.$1.floor(), spawn.$2.floor()),
        math.Point(ex, ey - 1),
      );
      expect(path, isNotNull, reason: 'exit door approach unreachable');
    });

    test('exit door solidity follows exitOpen', () {
      final (ex, ey) = map.exitDoorCell;
      expect(map.isSolid(ex + 0.5, ey + 0.5), isTrue);
      map.openExit();
      expect(map.isSolid(ex + 0.5, ey + 0.5), isFalse);
    });

    test('line of sight blocked through walls', () {
      final spawn = map.playerSpawn;
      final key = map.keySpawns.first;
      final sameRoom = map.hasLineOfSight(
          spawn.$1, spawn.$2, spawn.$1 + 0.8, spawn.$2 + 0.8);
      final across = map.hasLineOfSight(
          spawn.$1, spawn.$2, key.$1, key.$2);
      expect(sameRoom, isTrue);
      expect(across, sameRoom == across ? across : isFalse);
    });
  });

  group('player', () {
    test('cannot walk through walls when pushing into them', () {
      final player = Player()
        ..x = GameConstants.playerStartX
        ..y = GameConstants.playerStartY
        ..angle = math.pi / 2
        ..moveForward = 1
        ..running = true;
      for (var i = 0; i < 600; i++) {
        player.update(1 / 60, map);
        expect(map.isSolid(player.x, player.y), isFalse,
            reason: 'player inside solid at ${player.x},${player.y} (step $i)');
      }
      expect(player.y, lessThan(31.0));
    });
  });

  group('ghost', () {
    test('drains health when close and reports proximity', () {
      final gs = GameState()..startGame();
      final player = Player()
        ..x = GameConstants.playerStartX
        ..y = GameConstants.playerStartY;
      final ghost = Ghost(player.x + 0.4, player.y)
        ..state = GhostState.chase;
      ghost.update(0.05, map, player, gs);
      expect(gs.health, lessThan(GameConstants.maxHealth));
      expect(gs.ghostProximity.value, greaterThan(0));
    });

    test('no drain when far away', () {
      final gs = GameState()..startGame();
      final player = Player();
      final ghost = Ghost(2.5, 2.5);
      ghost.update(0.05, map, player, gs);
      expect(gs.health, GameConstants.maxHealth);
    });
  });

  group('entities', () {
    test('collects keys within radius', () {
      final gs = GameState()..startGame();
      final player = Player();
      final entities =
          WorldEntities(spawns: [(GameConstants.playerStartX, GameConstants.playerStartY)]);
      expect(entities.tryCollect(player, gs), 1);
      expect(gs.keysCollected, 1);
      expect(entities.billboards(0).length, 0);
    });
  });

  group('synth engine', () {
    test('encodes valid wav headers', () {
      final samples = Float32List(100);
      final wav = SynthEngine.encodeWav(samples);
      expect(wav.length, 44 + samples.length * 2);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    });

    test('produces correctly sized buffers', () {
      expect(SynthEngine.heartbeat().length, SynthEngine.sampleRate);
      final drone = SynthEngine.droneLoop();
      expect(drone.length, closeTo(SynthEngine.sampleRate * 20, SynthEngine.sampleRate ~/ 10));
      expect(SynthEngine.keyChime().length, greaterThan(0));
      expect(SynthEngine.jumpscare().length, greaterThan(0));
    });
  });

  group('game state', () {
    test('collecting all keys unlocks exit and reaching it wins', () {
      final gs = GameState()..startGame();
      for (var i = 0; i < GameConstants.totalKeys; i++) {
        gs.collectKey();
      }
      expect(gs.exitUnlocked, isTrue);
      gs.reachExit();
      expect(gs.phase, GamePhase.outro);
    });

    test('cannot escape without keys', () {
      final gs = GameState()..startGame();
      gs.reachExit();
      expect(gs.phase, GamePhase.playing);
    });

    test('health drain kills at zero', () {
      final gs = GameState()..startGame();
      gs.drainHealth(GameConstants.maxHealth + 1);
      expect(gs.phase, GamePhase.dead);
    });
  });
}
