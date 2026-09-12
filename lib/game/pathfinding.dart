import 'dart:math';

import 'house_map.dart';

abstract final class Pathfinding {
  static const int _nodeBudget = 2500;

  /// Breadth-first 4-directional search over cells whose centre is not solid.
  /// Returns the steps from [start] to [target] excluding the start cell and
  /// including the target cell, or null when no route exists.
  static List<Point>? findPath(HouseMap map, Point start, Point target) {
    final grid = map.grid;
    final height = grid.length;
    if (height == 0) return null;
    final width = grid[0].length;
    if (width == 0) return null;

    final startX = start.x.floor();
    final startY = start.y.floor();
    final targetX = target.x.floor();
    final targetY = target.y.floor();
    if (_outside(startX, startY, width, height) ||
        _outside(targetX, targetY, width, height)) {
      return null;
    }
    // Agents occupy cell centres; reject cells whose centre is solid.
    if (map.isSolid(startX + 0.5, startY + 0.5) ||
        map.isSolid(targetX + 0.5, targetY + 0.5)) {
      return null;
    }

    final startIndex = startY * width + startX;
    final targetIndex = targetY * width + targetX;
    if (startIndex == targetIndex) return <Point>[];

    final cameFrom = List<int?>.filled(width * height, null);
    final seen = List<bool>.filled(width * height, false);
    final queue = <int>[startIndex];
    seen[startIndex] = true;

    var head = 0;
    var dequeued = 0;
    while (head < queue.length) {
      if (++dequeued > _nodeBudget) return null;
      final current = queue[head++];
      if (current == targetIndex) {
        return _reconstruct(cameFrom, current, startIndex, width);
      }
      final cx = current % width;
      final cy = current ~/ width;
      _visit(queue, seen, cameFrom, map, width, height, cx + 1, cy, current);
      _visit(queue, seen, cameFrom, map, width, height, cx - 1, cy, current);
      _visit(queue, seen, cameFrom, map, width, height, cx, cy + 1, current);
      _visit(queue, seen, cameFrom, map, width, height, cx, cy - 1, current);
    }
    return null;
  }

  static void _visit(List<int> queue, List<bool> seen, List<int?> cameFrom,
      HouseMap map, int width, int height, int nx, int ny, int parent) {
    if (_outside(nx, ny, width, height)) return;
    final index = ny * width + nx;
    if (seen[index]) return;
    if (map.isSolid(nx + 0.5, ny + 0.5)) return;
    seen[index] = true;
    cameFrom[index] = parent;
    queue.add(index);
  }

  static bool _outside(int x, int y, int width, int height) =>
      x < 0 || y < 0 || x >= width || y >= height;

  static List<Point> _reconstruct(
      List<int?> cameFrom, int current, int startIndex, int width) {
    final path = <Point>[];
    var node = current;
    while (node != startIndex) {
      path.add(Point(node % width, node ~/ width));
      node = cameFrom[node]!;
    }
    return path.reversed.toList(growable: false);
  }
}
