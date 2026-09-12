import 'dart:math' as math;

import '../core/constants.dart';
import 'house_map.dart';

class Player {
  Player()
      : x = GameConstants.playerStartX,
        y = GameConstants.playerStartY,
        angle = GameConstants.playerStartAngle;

  double x;
  double y;
  double angle;

  double moveForward = 0;
  double moveStrafe = 0;
  bool running = false;

  void update(double dt, HouseMap map) {
    if (dt <= 0) return;

    var fwd = moveForward;
    var strafe = moveStrafe;
    final len = math.sqrt(fwd * fwd + strafe * strafe);
    if (len > 1) {
      fwd /= len;
      strafe /= len;
    }

    final speed =
        (running ? GameConstants.playerRunSpeed : GameConstants.playerWalkSpeed) *
            dt;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    // dir = (cosA, sinA); strafeRight = (-sinA, cosA)
    final dx = (cosA * fwd - sinA * strafe) * speed;
    final dy = (sinA * fwd + cosA * strafe) * speed;

    _tryMove(dx, 0, map);
    _tryMove(0, dy, map);
    _clampToGrid(map);
  }

  void _tryMove(double dx, double dy, HouseMap map) {
    if (dx == 0 && dy == 0) return;
    final nx = x + dx;
    final ny = y + dy;
    if (_circleHitsSolid(map, nx, ny)) return;
    x = nx;
    y = ny;
  }

  bool _circleHitsSolid(HouseMap map, double px, double py) {
    final r = GameConstants.playerRadius;
    return map.isSolid(px - r, py - r) ||
        map.isSolid(px + r, py - r) ||
        map.isSolid(px - r, py + r) ||
        map.isSolid(px + r, py + r);
  }

  void _clampToGrid(HouseMap map) {
    final grid = map.grid;
    if (grid.isEmpty || grid[0].isEmpty) return;
    final maxX = grid[0].length.toDouble() * GameConstants.mapTileSize;
    final maxY = grid.length.toDouble() * GameConstants.mapTileSize;
    x = x < 0 ? 0 : (x > maxX ? maxX : x);
    y = y < 0 ? 0 : (y > maxY ? maxY : y);
  }
}
