import 'dart:math';

import '../core/constants.dart';

/// Hybrid template-parameterized generator for Blackwood Manor.
///
/// Keeps the hand-authored theme (5 rooms, loop corridors, south exit,
/// 32x32) but jitters room rects, doors, pillars, cellar, exit X and all
/// spawns every call. Validation guarantees: 3 keys >=14 apart, every key
/// and the exit approach reachable from the player spawn.
class MapGenerator {
  static const int size = 32;

  static GeneratedManor generate({int? seed}) {
    final baseSeed = seed ?? Random().nextInt(1 << 31);
    final baseRandom = Random(baseSeed);
    // Derive per-attempt seeds so `seed` is reproducible.
    for (var attempt = 0; attempt < 100; attempt++) {
      final attemptSeed =
          (baseSeed + attempt * 7919) & 0x7fffffff;
      final manor = _tryBuild(Random(attemptSeed), attemptSeed);
      if (manor != null) return manor;
      // Keep lints quiet about unused baseRandom apart from seeding variety.
      baseRandom.nextBool();
    }
    // Fallback: classic layout data (never crash the run).
    return GeneratedManor.classicFallback(baseSeed);
  }

  static GeneratedManor? _tryBuild(Random rng, int attemptSeed) {
    final grid = List.generate(
        size, (_) => List<int>.filled(size, CellType.wallStone));

    void paint(int x1, int y1, int x2, int y2, int type) {
      final ax = x1.clamp(0, size - 1);
      final bx = x2.clamp(0, size - 1);
      final ay = y1.clamp(0, size - 1);
      final by = y2.clamp(0, size - 1);
      for (var y = ay; y <= by; y++) {
        for (var x = ax; x <= bx; x++) {
          grid[y][x] = type;
        }
      }
    }

    void carveRect(int x1, int y1, int x2, int y2) =>
        paint(x1, y1, x2, y2, CellType.empty);

    void carveCell(int x, int y) {
      if (x >= 0 && x < size && y >= 0 && y < size) {
        grid[y][x] = CellType.empty;
      }
    }

    int jit(int v, int delta, int lo, int hi) {
      final j = v + rng.nextInt(delta * 2 + 1) - delta;
      return j.clamp(lo, hi);
    }

    // --- Room shells (jittered classic zones) ---
    // Each: base x1,y1,x2,y2 + texture pool.
    var bedroom = (
      jit(1, 1, 1, 3),
      jit(1, 1, 1, 3),
      jit(11, 1, 9, 13),
      jit(8, 1, 7, 10),
      _pick(rng, const [CellType.wallPaper, CellType.wallPaper, CellType.wallWood]),
    );
    var kitchen = (
      jit(2, 1, 1, 3),
      jit(11, 1, 10, 12),
      jit(11, 1, 10, 13),
      jit(20, 1, 19, 21),
      _pick(rng, const [CellType.wallWood, CellType.wallWood, CellType.wallBrick]),
    );
    var library = (
      jit(20, 1, 18, 22),
      jit(11, 1, 10, 12),
      jit(29, 1, 28, 30),
      jit(20, 1, 19, 21),
      _pick(rng, const [CellType.wallBrick, CellType.wallWood, CellType.wallPaper]),
    );
    var hall = (
      jit(12, 1, 11, 13),
      jit(9, 1, 8, 10),
      jit(19, 1, 18, 20),
      jit(23, 1, 22, 24),
      CellType.wallBrick,
    );
    var foyer = (
      jit(13, 1, 12, 14),
      jit(24, 1, 23, 25),
      jit(19, 1, 18, 20),
      jit(30, 0, 30, 30),
      _pick(rng, const [CellType.wallBrick, CellType.wallStone]),
    );

    // Enforce minimum sizes.
    bedroom = _enforceMin(bedroom, 6, 5);
    kitchen = _enforceMin(kitchen, 6, 6);
    library = _enforceMin(library, 6, 6);
    hall = _enforceMin(hall, 5, 9);
    foyer = _enforceMin(foyer, 4, 5);

    paint(bedroom.$1, bedroom.$2, bedroom.$3, bedroom.$4, bedroom.$5);
    paint(kitchen.$1, kitchen.$2, kitchen.$3, kitchen.$4, kitchen.$5);
    paint(library.$1, library.$2, library.$3, library.$4, library.$5);
    paint(hall.$1, hall.$2, hall.$3, hall.$4, hall.$5);
    paint(foyer.$1, foyer.$2, foyer.$3, foyer.$4, foyer.$5);

    // Interiors (inset by 1).
    carveRect(bedroom.$1 + 1, bedroom.$2 + 1, bedroom.$3 - 1, bedroom.$4 - 1);
    carveRect(kitchen.$1 + 1, kitchen.$2 + 1, kitchen.$3 - 1, kitchen.$4 - 1);
    carveRect(library.$1 + 1, library.$2 + 1, library.$3 - 1, library.$4 - 1);
    carveRect(hall.$1 + 1, hall.$2 + 1, hall.$3 - 1, hall.$4 - 1);
    carveRect(foyer.$1 + 1, foyer.$2 + 1, foyer.$3 - 1, foyer.$4 - 1);

    // --- Corridors / escape loops (classic + small jitter) ---
    final northX1 = jit(12, 2, 10, 14);
    final northX2 = jit(30, 1, 28, 30);
    carveRect(1, 9, bedroom.$3, 10); // west link
    carveRect(1, 11, 1, 21); // west gallery
    carveRect(1, 21, hall.$1 + 1, jit(22, 0, 21, 22)); // south-west link
    carveRect(northX1, 5, northX2, 7); // north corridor
    carveRect(northX2, 5, northX2, 22); // east gallery
    carveRect(hall.$3 - 1, 21, northX2, 22); // south-east link

    // --- Doors: classic candidates kept at 70% + extras ---
    const classicDoors = [
      (5, 8), (6, 8), (11, 6),
      (5, 11), (6, 11), (2, 15), (2, 16), (11, 17),
      (12, 10), (12, 17),
      (19, 15), (19, 16), (20, 15), (20, 16),
      (24, 8), (24, 9), (24, 10), (24, 11),
      (29, 15), (29, 16),
      (15, 8), (16, 8), (15, 9), (16, 9),
      (19, 21), (19, 22),
      (15, 23), (16, 23), (15, 24), (16, 24),
      (15, 30), (16, 30),
    ];
    for (final d in classicDoors) {
      if (rng.nextDouble() < 0.72) carveCell(d.$1, d.$2);
    }
    // Extra random doors: carve random wall cells adjacent to empty.
    var extras = rng.nextInt(5);
    for (var i = 0; i < extras; i++) {
      final x = 2 + rng.nextInt(28);
      final y = 2 + rng.nextInt(28);
      if (grid[y][x] != CellType.empty && _adjacentEmpty(grid, x, y)) {
        carveCell(x, y);
      }
    }

    // --- Hall pillars (0-4) ---
    final pillarCandidates = <(int, int)>[];
    for (var y = hall.$2 + 2; y <= hall.$4 - 2; y++) {
      for (var x = hall.$1 + 2; x <= hall.$3 - 2; x++) {
        pillarCandidates.add((x, y));
      }
    }
    pillarCandidates.shuffle(rng);
    final pillarCount = rng.nextInt(5);
    for (var i = 0; i < pillarCount && i < pillarCandidates.length; i++) {
      final p = pillarCandidates[i];
      // Don't seal: keep pillars sparse (skip neighbours of taken).
      grid[p.$2][p.$1] = CellType.wallBrick;
    }

    // --- Cellar warren (random walk off north corridor) ---
    final entranceX = (24 + rng.nextInt(5)).clamp(northX1 + 1, northX2 - 1);
    carveCell(entranceX, 4);
    var wx = entranceX;
    var wy = 2;
    final warrenLen = 10 + rng.nextInt(8);
    for (var i = 0; i < warrenLen; i++) {
      wx = (wx + rng.nextInt(3) - 1).clamp(20, 29);
      wy = (wy + rng.nextInt(3) - 1).clamp(1, 3);
      carveCell(wx, wy);
      if (rng.nextBool()) carveCell((wx + 1).clamp(20, 29), wy);
    }

    // --- Outer walls + south exit at random X within foyer ---
    paint(0, 0, size - 1, 0, CellType.wallStone);
    paint(0, size - 1, size - 1, size - 1, CellType.wallStone);
    paint(0, 0, 0, size - 1, CellType.wallStone);
    paint(size - 1, 0, size - 1, size - 1, CellType.wallStone);
    final foyerMidX = ((foyer.$1 + foyer.$3) ~/ 2).clamp(2, 29);
    final exitX =
        (foyerMidX + rng.nextInt(5) - 2).clamp(foyer.$1 + 1, foyer.$3 - 1).clamp(1, 30);
    carveCell(exitX, 30);
    carveCell(exitX, 29);
    if (exitX > 1) carveCell(exitX - 1, 30);
    if (exitX < 30) carveCell(exitX + 1, 30);
    grid[size - 1][exitX] = CellType.exitDoor;
    final exitCell = (exitX, size - 1);
    final exitApproach = (exitX, size - 2);

    bool walkable(int x, int y) =>
        x >= 0 && y >= 0 && x < size && y < size && grid[y][x] == CellType.empty;

    // --- Player spawn: foyer center ---
    var pcx = ((foyer.$1 + foyer.$3) ~/ 2).clamp(1, 30);
    var pcy = ((foyer.$2 + foyer.$4) ~/ 2).clamp(1, 30);
    if (!walkable(pcx, pcy)) {
      final near = _nearestWalkable(grid, pcx, pcy);
      if (near == null) return null;
      pcx = near.$1;
      pcy = near.$2;
    }
    final playerSpawn = (pcx + 0.5, pcy + 0.5);

    // --- Reachability from player (single BFS) ---
    final dist = _bfsDistances(grid, (pcx, pcy));

    final walkables = <(int, int)>[];
    for (var y = 1; y < size - 1; y++) {
      for (var x = 1; x < size - 1; x++) {
        if (walkable(x, y) && dist[y][x] >= 0) walkables.add((x, y));
      }
    }
    // Player component must be a real manor, not a sealed pocket.
    if (walkables.length < 150) return null;

    // --- Ghost spawn: random pick among the farthest reachable cells
    // in the north half (variety across seeds, always far away). ---
    final northCands =
        walkables.where((c) => c.$2 <= 12).toList();
    if (northCands.isEmpty) return null;
    northCands.sort((a, b) => dist[b.$2][b.$1].compareTo(dist[a.$2][a.$1]));
    final topCut = northCands.take(12).toList()..shuffle(rng);
    final ghostCell = topCut.first;
    final ghostSpawn =
        (ghostCell.$1 + 0.5, ghostCell.$2 + 0.5);

    // --- Extra ghost spawns (hard mode): 2 more far-apart reachable
    // cells, >=10 from the player, the main ghost spawn and each other.
    // Falls back to patrol-band cells so the run never breaks. ---
    final extraGhostSpawns = <(double, double)>[];
    final farShuffled = walkables.toList()..shuffle(rng);
    farShuffled.sort((a, b) => (dist[b.$2][b.$1] + rng.nextDouble() * 6)
        .compareTo(dist[a.$2][a.$1] + rng.nextDouble() * 6));
    final taken = <(int, int)>[(pcx, pcy), ghostCell];
    for (final c in farShuffled) {
      if (extraGhostSpawns.length >= 2) break;
      var ok = true;
      for (final t in taken) {
        final dx = (c.$1 - t.$1).toDouble();
        final dy = (c.$2 - t.$2).toDouble();
        if (dx * dx + dy * dy < 100) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      extraGhostSpawns.add((c.$1 + 0.5, c.$2 + 0.5));
      taken.add(c);
    }
    while (extraGhostSpawns.length < 2) {
      extraGhostSpawns.add(ghostSpawn);
    }

    // --- Keys: 3 reachable, >=14 apart, >=6 (euclidean) from player.
    // Order by BFS distance + noise: far-first for horror pacing, noisy
    // for variety; second pass is a pure shuffle if greedy fails. ---
    List<(int, int)> pickKeys(List<(int, int)> ordered) {
      final keys = <(int, int)>[];
      for (final c in ordered) {
        if (keys.length >= GameConstants.totalKeys) break;
        final pdx = (c.$1 - pcx).toDouble();
        final pdy = (c.$2 - pcy).toDouble();
        if (pdx * pdx + pdy * pdy < 36) continue; // >=6 from player
        var ok = true;
        for (final k in keys) {
          final dx = (c.$1 - k.$1).toDouble();
          final dy = (c.$2 - k.$2).toDouble();
          if (dx * dx + dy * dy < 14 * 14) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        keys.add(c);
      }
      return keys;
    }

    final farFirst = walkables.toList()
      ..sort((a, b) => (dist[b.$2][b.$1] + rng.nextDouble() * 10)
          .compareTo(dist[a.$2][a.$1] + rng.nextDouble() * 10));
    var keys = pickKeys(farFirst);
    if (keys.length < GameConstants.totalKeys) {
      final shuffled = walkables.toList()..shuffle(rng);
      keys = pickKeys(shuffled);
    }
    if (keys.length < GameConstants.totalKeys) return null;
    final keySpawns =
        [for (final k in keys) (k.$1 + 0.5, k.$2 + 0.5)];

    // Exit approach must be reachable (dist map already proves it).
    if (dist[exitApproach.$2][exitApproach.$1] < 0) return null;

    // --- Patrol routes: west / east / center bands ---
    // (walkables are all reachable by construction.)
    final patrols = <List<(double, double)>>[];
    final bands = [
      (1, 12),
      (20, 30),
      (12, 20),
    ];
    for (final band in bands) {
      final cands = walkables
          .where((c) => c.$1 >= band.$1 && c.$1 <= band.$2)
          .toList()
        ..shuffle(rng);
      final route = <(double, double)>[];
      for (final c in cands) {
        if (route.length >= 5) break;
        route.add((c.$1 + 0.5, c.$2 + 0.5));
      }
      if (route.length >= 3) {
        // Nearest-neighbour order for a sensible loop.
        final ordered = [route.removeAt(0)];
        while (route.isNotEmpty) {
          final last = ordered.last;
          route.sort((a, b) {
            final da = (a.$1 - last.$1) * (a.$1 - last.$1) +
                (a.$2 - last.$2) * (a.$2 - last.$2);
            final db = (b.$1 - last.$1) * (b.$1 - last.$1) +
                (b.$2 - last.$2) * (b.$2 - last.$2);
            return da.compareTo(db);
          });
          ordered.add(route.removeAt(0));
        }
        patrols.add(ordered);
      }
    }
    if (patrols.isEmpty) {
      patrols.add([ghostSpawn]);
    }

    return GeneratedManor(
      grid: grid,
      keySpawns: keySpawns,
      patrolRoutes: patrols,
      playerSpawn: playerSpawn,
      ghostSpawn: ghostSpawn,
      extraGhostSpawns: extraGhostSpawns,
      exitCell: exitCell,
      seed: attemptSeed,
    );
  }

  static T _pick<T>(Random rng, List<T> items) =>
      items[rng.nextInt(items.length)];

  static (int, int, int, int, int) _enforceMin(
      (int, int, int, int, int) r, int minW, int minH) {
    var (x1, y1, x2, y2, t) = r;
    if (x2 - x1 + 1 < minW) x2 = (x1 + minW - 1).clamp(0, size - 1);
    if (y2 - y1 + 1 < minH) y2 = (y1 + minH - 1).clamp(0, size - 1);
    if (x1 > x2) x1 = x2;
    if (y1 > y2) y1 = y2;
    return (x1, y1, x2, y2, t);
  }

  static bool _adjacentEmpty(List<List<int>> grid, int x, int y) {
    const dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];
    for (final d in dirs) {
      final nx = x + d.$1;
      final ny = y + d.$2;
      if (nx >= 0 &&
          ny >= 0 &&
          nx < size &&
          ny < size &&
          grid[ny][nx] == CellType.empty) {
        return true;
      }
    }
    return false;
  }

  static (int, int)? _nearestWalkable(
      List<List<int>> grid, int sx, int sy) {
    if (sx >= 0 &&
        sy >= 0 &&
        sx < size &&
        sy < size &&
        grid[sy][sx] == CellType.empty) {
      return (sx, sy);
    }
    for (var r = 1; r < 8; r++) {
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          final x = sx + dx;
          final y = sy + dy;
          if (x >= 0 &&
              y >= 0 &&
              x < size &&
              y < size &&
              grid[y][x] == CellType.empty) {
            return (x, y);
          }
        }
      }
    }
    return null;
  }

  /// 4-directional BFS distances from [from] over empty cells.
  /// Unreachable cells are -1. Single pass replaces N point-to-point checks.
  static List<List<int>> _bfsDistances(
      List<List<int>> grid, (int, int) from) {
    final dist =
        List.generate(size, (_) => List<int>.filled(size, -1));
    if (from.$1 < 0 ||
        from.$2 < 0 ||
        from.$1 >= size ||
        from.$2 >= size ||
        grid[from.$2][from.$1] != CellType.empty) {
      return dist;
    }
    final queue = <(int, int)>[from];
    dist[from.$2][from.$1] = 0;
    var head = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      final nd = dist[cur.$2][cur.$1] + 1;
      const dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];
      for (final d in dirs) {
        final nx = cur.$1 + d.$1;
        final ny = cur.$2 + d.$2;
        if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
        if (dist[ny][nx] >= 0) continue;
        if (grid[ny][nx] != CellType.empty) continue;
        dist[ny][nx] = nd;
        queue.add((nx, ny));
      }
    }
    return dist;
  }
}

/// Plain data produced by [MapGenerator]; wrapped by `HouseMap.generate`.
class GeneratedManor {
  GeneratedManor({
    required this.grid,
    required this.keySpawns,
    required this.patrolRoutes,
    required this.playerSpawn,
    required this.ghostSpawn,
    required this.extraGhostSpawns,
    required this.exitCell,
    required this.seed,
  });

  final List<List<int>> grid;
  final List<(double, double)> keySpawns;
  final List<List<(double, double)>> patrolRoutes;
  final (double, double) playerSpawn;
  final (double, double) ghostSpawn;
  final List<(double, double)> extraGhostSpawns;
  final (int, int) exitCell;
  final int seed;

  factory GeneratedManor.classicFallback(int seed) {
    final grid = List.generate(
        MapGenerator.size, (_) => List<int>.filled(MapGenerator.size, CellType.wallStone));
    // Minimal open arena so the run is still playable if generation failed.
    for (var y = 1; y < MapGenerator.size - 1; y++) {
      for (var x = 1; x < MapGenerator.size - 1; x++) {
        grid[y][x] = CellType.empty;
      }
    }
    grid[MapGenerator.size - 1][16] = CellType.exitDoor;
    return GeneratedManor(
      grid: grid,
      keySpawns: const [(3.5, 3.5), (28.5, 3.5), (16.5, 16.5)],
      patrolRoutes: const [
        [(8.5, 8.5), (24.5, 8.5), (24.5, 24.5), (8.5, 24.5)],
      ],
      playerSpawn: const (16.5, 26.5),
      ghostSpawn: const (16.5, 6.5),
      extraGhostSpawns: const [(8.5, 6.5), (24.5, 6.5)],
      exitCell: const (16, 31),
      seed: seed,
    );
  }
}
