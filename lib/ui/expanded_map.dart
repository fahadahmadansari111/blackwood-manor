import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/game_state.dart';
import '../game/horror_game.dart';
import '../game/house_map.dart';

/// Easy-mode fullscreen seer map: the whole manor, translucent so the game
/// stays visible (and dangerous) behind it. Tap anywhere to close.
class ExpandedMapOverlay extends StatelessWidget {
  const ExpandedMapOverlay(
      {super.key, required this.game, required this.gameState});

  final HauntedHouseGame game;
  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([game.minimapTick, gameState]),
      builder: (context, _) {
        return GestureDetector(
          onTap: gameState.toggleMapExpanded,
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
            child: SafeArea(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(18),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF616161).withValues(alpha: 0.8),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'BLACKWOOD MANOR — TAP TO CLOSE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: CustomPaint(
                            painter: FullMapPainter(
                              map: game.map,
                              playerX: game.player.x,
                              playerY: game.player.y,
                              playerAngle: game.player.angle,
                              ghosts: [
                                for (final g in game.ghosts) (g.x, g.y),
                              ],
                              keys: [
                                for (final k in game.entities.keys)
                                  if (!k.collected) (k.x, k.y),
                              ],
                              exitOpen: game.map.exitOpen,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// North-up full-grid painter. Draws every cell so the whole manor reads
/// at a glance: walls gray per type, exit amber/green, keys amber diamonds,
/// ghosts red pips, player white triangle.
class FullMapPainter extends CustomPainter {
  FullMapPainter({
    required this.map,
    required this.playerX,
    required this.playerY,
    required this.playerAngle,
    required this.ghosts,
    required this.keys,
    required this.exitOpen,
  });

  final HouseMap map;
  final double playerX;
  final double playerY;
  final double playerAngle;
  final List<(double, double)> ghosts;
  final List<(double, double)> keys;
  final bool exitOpen;

  Color _wallColor(int cell) {
    switch (cell) {
      case CellType.wallBrick:
        return const Color(0xFF6B4A42);
      case CellType.wallWood:
        return const Color(0xFF6B5133);
      case CellType.wallStone:
        return const Color(0xFF565E68);
      case CellType.wallPaper:
        return const Color(0xFF5E6369);
      default:
        return const Color(0xFF616161);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rows = map.grid.length;
    if (rows == 0) return;
    final cols = map.grid[0].length;
    if (cols == 0) return;
    final cell = (size.width / cols) < (size.height / rows)
        ? size.width / cols
        : size.height / rows;
    final ox = (size.width - cell * cols) / 2;
    final oy = (size.height - cell * rows) / 2;

    Offset toPx(double wx, double wy) =>
        Offset(ox + wx * cell, oy + wy * cell);

    // Floor.
    canvas.drawRect(
      Rect.fromLTWH(ox, oy, cols * cell, rows * cell),
      Paint()..color = const Color(0xFF141414),
    );
    // Walls + exit door.
    for (var cy = 0; cy < rows; cy++) {
      for (var cx = 0; cx < cols; cx++) {
        final type = map.grid[cy][cx];
        if (type == CellType.empty) continue;
        final rect = Rect.fromLTWH(
            ox + cx * cell, oy + cy * cell, cell + 0.5, cell + 0.5);
        if (type == CellType.exitDoor) {
          canvas.drawRect(
            rect,
            Paint()
              ..color = exitOpen
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFFC107),
          );
        } else {
          canvas.drawRect(rect, Paint()..color = _wallColor(type));
        }
      }
    }

    // Keys.
    final keyPaint = Paint()..color = const Color(0xFFFFC107);
    for (final key in keys) {
      final p = toPx(key.$1, key.$2);
      final kr = cell * 0.42;
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - kr)
          ..lineTo(p.dx + kr, p.dy)
          ..lineTo(p.dx, p.dy + kr)
          ..lineTo(p.dx - kr, p.dy)
          ..close(),
        keyPaint,
      );
    }

    // Ghosts.
    final ghostPaint = Paint()..color = const Color(0xFFB71C1C);
    final ghostRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85);
    for (final g in ghosts) {
      final p = toPx(g.$1, g.$2);
      canvas.drawCircle(p, cell * 0.5, ghostPaint);
      canvas.drawCircle(p, cell * 0.5, ghostRing);
    }

    // Player triangle rotated by angle (0 = east, -pi/2 = north).
    canvas.save();
    final pp = toPx(playerX, playerY);
    canvas.translate(pp.dx, pp.dy);
    canvas.rotate(playerAngle + 3.141592653589793 / 2);
    final triSize = cell * 0.9;
    canvas.drawPath(
      Path()
        ..moveTo(0, -triSize)
        ..lineTo(-triSize * 0.7, triSize * 0.55)
        ..lineTo(triSize * 0.7, triSize * 0.55)
        ..close(),
      Paint()..color = Colors.white,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(FullMapPainter oldDelegate) => true;
}
