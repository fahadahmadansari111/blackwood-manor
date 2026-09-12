import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../game/horror_game.dart';
import '../game/house_map.dart';

/// Player-relative rotating radar shown top-right.
///
/// Player is always fixed at the center facing up; ghost, exit and nearby
/// walls are plotted as offset vectors rotated by `-player.angle`.
class MinimapWidget extends StatelessWidget {
  const MinimapWidget({super.key, required this.game, this.size = 124});

  final HauntedHouseGame game;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game.minimapTick,
      builder: (context, _) {
        final px = game.player.x;
        final py = game.player.y;
        final pa = game.player.angle;
        final (ex, ey) = game.map.exitDoorCell;
        final exitX = ex + 0.5;
        final exitY = ey + 0.5;
        final gdx = game.ghost.x - px;
        final gdy = game.ghost.y - py;
        final gdist = math.sqrt(gdx * gdx + gdy * gdy);
        final ghostVisible = MinimapMath.isGhostVisible(
          dist: gdist,
          range: MinimapMath.radarRange,
          hasLineOfSight:
              game.map.hasLineOfSight(px, py, game.ghost.x, game.ghost.y),
        );
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.62),
            border: Border.all(
              color: const Color(0xFF616161).withValues(alpha: 0.7),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 8),
            ],
          ),
          child: ClipOval(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: MinimapPainter(
                  map: game.map,
                  playerX: px,
                  playerY: py,
                  playerAngle: pa,
                  ghostX: game.ghost.x,
                  ghostY: game.ghost.y,
                  ghostVisible: ghostVisible,
                  exitX: exitX,
                  exitY: exitY,
                  exitOpen: game.map.exitOpen,
                  tick: game.minimapTick.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MinimapMath {
  MinimapMath._();

  static const double radarRange = 9.0;
  static const double pointBlankRadius = 1.0;

  /// Projects a world entity into radar space centered on [center].
  /// Ahead of the player maps to up (0,-1). Clamps to [range].
  static Offset project({
    required double playerX,
    required double playerY,
    required double playerAngle,
    required double entityX,
    required double entityY,
    required double range,
    required double radius,
  }) {
    final dx = entityX - playerX;
    final dy = entityY - playerY;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1e-9) return Offset.zero;
    final worldAngle = math.atan2(dy, dx);
    final screenAngle = worldAngle - playerAngle - math.pi / 2;
    final clamped = dist > range ? range : dist;
    final k = radius / range * clamped;
    return Offset(math.cos(screenAngle) * k, math.sin(screenAngle) * k);
  }

  static double clampedDistance(double dist, double range) =>
      dist > range ? range : dist;

  /// Ghost shows only when close enough; point-blank bypasses LOS so a
  /// through-wall camper at 1m still pings (mirrors drain logic).
  static bool isGhostVisible({
    required double dist,
    required double range,
    required bool hasLineOfSight,
  }) {
    if (dist > range) return false;
    if (dist < pointBlankRadius) return true;
    return hasLineOfSight;
  }
}

class MinimapPainter extends CustomPainter {
  MinimapPainter({
    required this.map,
    required this.playerX,
    required this.playerY,
    required this.playerAngle,
    required this.ghostX,
    required this.ghostY,
    required this.ghostVisible,
    required this.exitX,
    required this.exitY,
    required this.exitOpen,
    required this.tick,
  });

  final HouseMap map;
  final double playerX;
  final double playerY;
  final double playerAngle;
  final double ghostX;
  final double ghostY;
  final bool ghostVisible;
  final double exitX;
  final double exitY;
  final bool exitOpen;
  final int tick;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final range = MinimapMath.radarRange;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF0A0A0A).withValues(alpha: 0.9),
    );

    final wallPaint = Paint()..color = const Color(0xFF616161);
    final minCx = (playerX - range).floor();
    final maxCx = (playerX + range).ceil();
    final minCy = (playerY - range).floor();
    final maxCy = (playerY + range).ceil();
    for (var cy = minCy; cy <= maxCy; cy++) {
      for (var cx = minCx; cx <= maxCx; cx++) {
        final int cell = map.cellAt(cx, cy);
        if (cell == CellType.empty) continue;
        if (cell == CellType.exitDoor) continue;
        final off = MinimapMath.project(
          playerX: playerX,
          playerY: playerY,
          playerAngle: playerAngle,
          entityX: cx + 0.5,
          entityY: cy + 0.5,
          range: range,
          radius: radius - 6,
        );
        if (off.distance > radius - 5) continue;
        canvas.drawCircle(center + off, 1.6, wallPaint);
      }
    }

    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF9E9E9E).withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      center,
      (radius - 6) * 0.55,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = Colors.white.withValues(alpha: 0.12),
    );

    final northOff = MinimapMath.project(
      playerX: 0,
      playerY: 0,
      playerAngle: playerAngle,
      entityX: math.cos(-math.pi / 2),
      entityY: math.sin(-math.pi / 2),
      range: 1,
      radius: radius - 10,
    );
    final nPos = center + northOff;
    final tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
            color: Color(0xFF9E9E9E), fontSize: 9, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, nPos - Offset(tp.width / 2, tp.height / 2));

    final exitOff = MinimapMath.project(
      playerX: playerX,
      playerY: playerY,
      playerAngle: playerAngle,
      entityX: exitX,
      entityY: exitY,
      range: range,
      radius: radius - 10,
    );
    final exitPos = center + exitOff;
    final exitColor =
        exitOpen ? const Color(0xFF4CAF50) : const Color(0xFFFFC107);
    canvas.drawRect(
      Rect.fromCenter(center: exitPos, width: 7, height: 7),
      Paint()..color = exitColor,
    );
    canvas.drawRect(
      Rect.fromCenter(center: exitPos, width: 9, height: 9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = exitColor.withValues(alpha: 0.7),
    );

    if (ghostVisible) {
      final ghostOff = MinimapMath.project(
        playerX: playerX,
        playerY: playerY,
        playerAngle: playerAngle,
        entityX: ghostX,
        entityY: ghostY,
        range: range,
        radius: radius - 10,
      );
      final gPos = center + ghostOff;
      final pulse = 0.5 + 0.5 * math.sin(tick * 0.9);
      canvas.drawCircle(
        gPos,
        6.5 + pulse * 2,
        Paint()..color = const Color(0xFFB71C1C).withValues(alpha: 0.35),
      );
      canvas.drawCircle(gPos, 4, Paint()..color = const Color(0xFFB71C1C));
      canvas.drawCircle(
        gPos,
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    const triSize = 7.0;
    final tri = Path()
      ..moveTo(center.dx, center.dy - triSize)
      ..lineTo(center.dx - triSize * 0.7, center.dy + triSize * 0.55)
      ..lineTo(center.dx + triSize * 0.7, center.dy + triSize * 0.55)
      ..close();
    canvas.drawPath(tri, Paint()..color = Colors.white);
    canvas.drawCircle(center, 2, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(MinimapPainter oldDelegate) {
    return oldDelegate.playerX != playerX ||
        oldDelegate.playerY != playerY ||
        oldDelegate.playerAngle != playerAngle ||
        oldDelegate.ghostX != ghostX ||
        oldDelegate.ghostY != ghostY ||
        oldDelegate.ghostVisible != ghostVisible ||
        oldDelegate.exitOpen != exitOpen ||
        oldDelegate.tick != tick;
  }
}
