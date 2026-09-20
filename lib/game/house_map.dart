import 'dart:math' show sqrt;

import '../core/constants.dart';
import 'map_generator.dart';

/// Single floor of Blackwood Manor: 32x32 tiles,
/// `grid[y][x]`, y = 0 is the north wall, x = 0 is the west wall.
///
/// `HouseMap()` / `HouseMap.classic()` return the hand-authored layout
/// (regression fallback). `HouseMap.generate()` returns a new hybrid
/// randomized manor every call — same theme, new rooms/doors/spawns.
class HouseMap {
  HouseMap() : this.classic();

  HouseMap.classic() {
    _buildClassic();
    _keySpawns = _classicKeys;
    _patrolRoutes = _classicPatrols;
    _playerSpawn =
        (GameConstants.playerStartX, GameConstants.playerStartY);
    _ghostSpawn = (GameConstants.ghostSpawnX, GameConstants.ghostSpawnY);
    _extraGhostSpawns = _classicExtraGhosts;
    seed = 0;
  }

  HouseMap._generated({
    required List<List<int>> grid,
    required List<(double, double)> keySpawns,
    required List<List<(double, double)>> patrolRoutes,
    required (double, double) playerSpawn,
    required (double, double) ghostSpawn,
    required List<(double, double)> extraGhostSpawns,
    required (int, int) exitCell,
    required this.seed,
  })  : _keySpawns = keySpawns,
        _patrolRoutes = patrolRoutes,
        _playerSpawn = playerSpawn,
        _ghostSpawn = ghostSpawn,
        _extraGhostSpawns = extraGhostSpawns,
        _exitCell = exitCell {
    this.grid.addAll(grid);
  }

  /// Returns a new random manor. `seed` is exposed for tests/debugging;
  /// omit it for a fresh random layout every run.
  factory HouseMap.generate({int? seed}) {
    final manor = MapGenerator.generate(seed: seed);
    return HouseMap._generated(
      grid: manor.grid,
      keySpawns: manor.keySpawns,
      patrolRoutes: manor.patrolRoutes,
      playerSpawn: manor.playerSpawn,
      ghostSpawn: manor.ghostSpawn,
      extraGhostSpawns: manor.extraGhostSpawns,
      exitCell: manor.exitCell,
      seed: manor.seed,
    );
  }

  final List<List<int>> grid = [];

  bool exitOpen = false;

  late final (int, int) _exitCell;
  late final List<(double, double)> _keySpawns;
  late final List<List<(double, double)>> _patrolRoutes;
  late final (double, double) _playerSpawn;
  late final (double, double) _ghostSpawn;
  late final List<(double, double)> _extraGhostSpawns;

  /// Seed used for generation (0 = hand-authored classic).
  late final int seed;

  static const List<(double, double)> _classicKeys = [
    (3.5, 19.5), // kitchen, south-west corner
    (28.5, 19.5), // library, south-east corner
    (29.5, 3.5), // cellar, east dead-end gallery
  ];

  static const List<List<(double, double)>> _classicPatrols = [
    // West wing kitchen circuit.
    [(5.5, 9.5), (5.5, 18.5), (8.5, 18.5), (8.5, 12.5), (5.5, 12.5)],
    // East wing library loop via the north corridor.
    [(24.5, 6.5), (24.5, 13.5), (28.5, 18.5), (21.5, 18.5), (24.5, 18.5)],
    // Great hall north-south crossing.
    [(15.5, 6.5), (15.5, 20.5), (13.5, 20.5), (13.5, 10.5), (15.5, 10.5)],
  ];

  /// Hard-mode reinforcements on the classic map (unused on easy, which
  /// only ever spawns one ghost, but kept valid for completeness).
  static const List<(double, double)> _classicExtraGhosts = [
    (5.5, 6.5),
    (27.5, 6.5),
  ];

  void openExit() => exitOpen = true;

  int cellAt(int cx, int cy) {
    if (cy < 0 || cy >= grid.length) return CellType.wallStone;
    final row = grid[cy];
    if (cx < 0 || cx >= row.length) return CellType.wallStone;
    return row[cx];
  }

  bool isSolid(double wx, double wy) {
    final type = cellAt(wx.floor(), wy.floor());
    if (type == CellType.empty) return false;
    if (type == CellType.exitDoor) return !exitOpen;
    return true;
  }

  (int, int) get exitDoorCell => _exitCell;

  (double, double) get playerSpawn => _playerSpawn;

  (double, double) get ghostSpawn => _ghostSpawn;

  List<(double, double)> get extraGhostSpawns => _extraGhostSpawns;

  List<(double, double)> get keySpawns => _keySpawns;

  List<List<(double, double)>> get patrolRoutes => _patrolRoutes;

  bool hasLineOfSight(double ax, double ay, double bx, double by) {
    final dx = bx - ax;
    final dy = by - ay;
    final length = sqrt(dx * dx + dy * dy);
    var steps = (length / 0.2).ceil();
    if (steps < 1) steps = 1;
    final sx = dx / steps;
    final sy = dy / steps;
    var px = ax;
    var py = ay;
    for (var i = 0; i <= steps; i++) {
      if (isSolid(px, py)) return false;
      px += sx;
      py += sy;
    }
    return true;
  }

  void _buildClassic() {
    grid
      ..clear()
      ..addAll(
          List.generate(32, (_) => List<int>.filled(32, CellType.wallStone)));

    void paint(int x1, int y1, int x2, int y2, int type) {
      for (var y = y1; y <= y2; y++) {
        final row = grid[y];
        for (var x = x1; x <= x2; x++) {
          row[x] = type;
        }
      }
    }

    void carveRect(int x1, int y1, int x2, int y2) =>
        paint(x1, y1, x2, y2, CellType.empty);

    void carveCells(List<(int, int)> cells) {
      for (final c in cells) {
        grid[c.$2][c.$1] = CellType.empty;
      }
    }

    // Room shells.
    paint(1, 1, 11, 8, CellType.wallPaper); // master bedroom
    paint(2, 11, 11, 20, CellType.wallWood); // kitchen
    paint(20, 11, 29, 20, CellType.wallBrick); // library
    paint(12, 9, 19, 23, CellType.wallBrick); // great hall
    paint(13, 24, 19, 30, CellType.wallBrick); // foyer

    // Room interiors.
    carveRect(2, 2, 10, 7);
    carveRect(3, 12, 10, 19);
    carveRect(21, 12, 28, 19);
    carveRect(13, 10, 18, 22);
    carveRect(14, 25, 18, 29);

    // Connecting corridors and escape loops.
    carveRect(1, 9, 11, 10); // west link between bedroom and kitchen
    carveRect(1, 11, 1, 21); // west gallery along the border
    carveRect(1, 21, 12, 22); // south-west link into the hall
    carveRect(12, 5, 30, 7); // north corridor
    carveRect(30, 5, 30, 22); // east gallery along the border
    carveRect(20, 21, 29, 22); // south-east link into the hall

    // Doorways and passages.
    carveCells(const [
      (5, 8), (6, 8), (11, 6), // bedroom exits
      (5, 11), (6, 11), (2, 15), (2, 16), (11, 17), // kitchen doors
      (12, 10), (12, 17), // hall west doors
      (19, 15), (19, 16), (20, 15), (20, 16), // hall <-> library
      (24, 8), (24, 9), (24, 10), (24, 11), // library north passage
      (29, 15), (29, 16), // library east doors
      (15, 8), (16, 8), (15, 9), (16, 9), // north corridor into hall
      (19, 21), (19, 22), // hall south-east mouth
      (15, 23), (16, 23), (15, 24), (16, 24), // hall down to foyer
      (15, 30), (16, 30), // exit vestibule
    ]);

    // Hall pillars.
    for (final c in const [(14, 13), (17, 13), (14, 18), (17, 18)]) {
      grid[c.$2][c.$1] = CellType.wallBrick;
    }

    // Cellar: dead-end corridor warren in the north-east.
    carveCells(const [
      (22, 1), (24, 1), (25, 1),
      (21, 2), (22, 2), (23, 2), (24, 2), (25, 2), (26, 2), (27, 2),
      (24, 3), (25, 3), (26, 3), (27, 3), (28, 3), (29, 3),
      (27, 4), // entrance from the north corridor
    ]);

    // Outer walls and the front door in the south border.
    paint(0, 0, 31, 0, CellType.wallStone);
    paint(0, 31, 31, 31, CellType.wallStone);
    paint(0, 0, 0, 31, CellType.wallStone);
    paint(31, 0, 31, 31, CellType.wallStone);
    _exitCell = (16, 31);
    grid[31][16] = CellType.exitDoor;
  }
}
