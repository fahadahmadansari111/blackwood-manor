import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../core/constants.dart';
import 'house_map.dart';
import 'player.dart';

enum SpriteKind { key, ghost }

class SpriteBillboard {
  const SpriteBillboard({
    required this.x,
    required this.y,
    required this.kind,
    this.bobPhase = 0,
    this.scale = 1.0,
  });

  final double x;
  final double y;
  final SpriteKind kind;
  final double bobPhase;
  final double scale;
}

class RaycastRenderer {
  const RaycastRenderer();

  static final Float32List _zBuffer = Float32List(GameConstants.rayCount);

  static final Paint _wallPaint = Paint()..isAntiAlias = false;
  static final Paint _ceilingPaint = Paint();
  static final Paint _floorPaint = Paint();
  static Size _gradientSize = Size.zero;

  static final Paint _keyPaint = Paint()..color = const Color(0xFFFFB92E);
  static final Paint _keyCorePaint = Paint()..color = const Color(0xFFFFE9A8);
  static final Paint _keyHaloPaint = Paint()
    ..color = const Color(0x59FFAE1E)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

  static final Paint _ghostPaint = Paint();
  static final Paint _ghostFeaturePaint = Paint()
    ..color = const Color(0xF7000000);
  static final Path _ghostPath = Path();

  static final Paint _hurtPaint = Paint();
  static final List<SpriteBillboard> _drawOrder = <SpriteBillboard>[];

  void render(
    Canvas canvas,
    Size size, {
    required HouseMap map,
    required Player player,
    required List<SpriteBillboard> sprites,
    required double time,
    required double hurtPulse,
  }) {
    _ensureBackgroundShaders(size);

    final halfH = size.height * 0.5;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, halfH + 0.5),
      _ceilingPaint,
    );
    canvas.drawRect(Rect.fromLTWH(0, halfH, size.width, halfH), _floorPaint);

    final dirX = math.cos(player.angle);
    final dirY = math.sin(player.angle);
    final planeScale = math.tan(GameConstants.fov / 2);
    final planeX = -dirY * planeScale;
    final planeY = dirX * planeScale;
    final invDet = 1 / (planeX * dirY - dirX * planeY);

    _castWalls(canvas, size, map, player, dirX, dirY, planeX, planeY, time);
    _drawSprites(canvas, size, player, sprites, dirX, dirY, planeX, planeY,
        invDet, time);

    if (hurtPulse > 0) {
      _hurtPaint.color =
          Color.fromRGBO(150, 12, 12, _clamp(hurtPulse * 0.5, 0.0, 1.0));
      canvas.drawRect(Offset.zero & size, _hurtPaint);
    }
  }

  static void _ensureBackgroundShaders(Size size) {
    if (_gradientSize == size) return;
    _gradientSize = size;
    final halfH = size.height * 0.5;
    _ceilingPaint.shader = Gradient.linear(
      Offset(0, 0),
      Offset(0, halfH),
      const [Color(0xFF05050A), Color(0xFF18151F)],
    );
    _floorPaint.shader = Gradient.linear(
      Offset(0, halfH),
      Offset(0, size.height),
      const [Color(0xFF0A0810), Color(0xFF181420)],
    );
  }

  static void _castWalls(
    Canvas canvas,
    Size size,
    HouseMap map,
    Player player,
    double dirX,
    double dirY,
    double planeX,
    double planeY,
    double time,
  ) {
    final rays = GameConstants.rayCount;
    final w = size.width;
    final h = size.height;
    final colW = w / rays;
    final maxDist = GameConstants.maxRenderDistance;
    final flicker =
        1 + 0.04 * math.sin(time * 13) + 0.02 * math.sin(time * 31);
    final px = player.x;
    final py = player.y;

    for (var i = 0; i < rays; i++) {
      final cameraX = 2 * i / rays - 1;
      final rdX = dirX + planeX * cameraX;
      final rdY = dirY + planeY * cameraX;

      var mapX = px.floor();
      var mapY = py.floor();
      final deltaX = rdX == 0 ? 1e30 : (1 / rdX).abs();
      final deltaY = rdY == 0 ? 1e30 : (1 / rdY).abs();

      int stepX;
      double sideDistX;
      if (rdX < 0) {
        stepX = -1;
        sideDistX = (px - mapX) * deltaX;
      } else {
        stepX = 1;
        sideDistX = (mapX + 1 - px) * deltaX;
      }
      int stepY;
      double sideDistY;
      if (rdY < 0) {
        stepY = -1;
        sideDistY = (py - mapY) * deltaY;
      } else {
        stepY = 1;
        sideDistY = (mapY + 1 - py) * deltaY;
      }

      var cell = CellType.empty;
      var side = 0;
      var travelled = 0.0;
      while (travelled <= maxDist) {
        if (sideDistX < sideDistY) {
          travelled = sideDistX;
          sideDistX += deltaX;
          mapX += stepX;
          side = 0;
        } else {
          travelled = sideDistY;
          sideDistY += deltaY;
          mapY += stepY;
          side = 1;
        }
        cell = map.cellAt(mapX, mapY);
        if (cell != CellType.empty) break;
      }

      var perp = cell != CellType.empty ? travelled : maxDist;
      if (perp < 0.0001) perp = 0.0001;
      _zBuffer[i] = perp;

      final sliceH = h / perp;
      final yTop = (h - sliceH) * 0.5;
      final xLeft = i * colW;
      final xRight = i == rays - 1 ? w : xLeft + colW;
      final rect = Rect.fromLTRB(xLeft, yTop, xRight, yTop + sliceH);

      if (cell == CellType.empty) {
        _wallPaint.color = const Color(0xFF000000);
        canvas.drawRect(rect, _wallPaint);
        continue;
      }

      var wallX = side == 0 ? py + perp * rdY : px + perp * rdX;
      wallX -= wallX.floorToDouble();

      var brightness = 1 - _clamp(perp / maxDist, 0.0, 1.0);
      // side 0 crosses x-gridlines (E/W facing face), side 1 crosses
      // y-gridlines (N/S facing face).
      brightness *= side == 0 ? 0.72 : 1.0;
      brightness *=
          _clamp(1.18 - 0.62 * cameraX * cameraX, 0.25, 1.0) * flicker;

      var base = 0xFF202024;
      switch (cell) {
        case CellType.wallBrick:
          base = 0xFF4A2B25;
          break;
        case CellType.wallWood:
          base = 0xFF4A3620;
          break;
        case CellType.wallStone:
          base = 0xFF394048;
          break;
        case CellType.wallPaper:
          base = 0xFF3E4247;
          break;
        case CellType.exitDoor:
          base = 0xFF23262B;
          if ((wallX * 6) % 1 < 0.15) brightness *= 0.72;
          break;
        default:
          break;
      }
      if ((wallX * 3) % 1 < 0.14) brightness *= 0.75;

      final r = (((base >> 16) & 0xFF) * brightness).round().clamp(0, 255);
      final g = (((base >> 8) & 0xFF) * brightness).round().clamp(0, 255);
      final b = ((base & 0xFF) * brightness).round().clamp(0, 255);
      _wallPaint.color = Color.fromARGB(255, r, g, b);
      canvas.drawRect(rect, _wallPaint);
    }
  }

  static void _drawSprites(
    Canvas canvas,
    Size size,
    Player player,
    List<SpriteBillboard> sprites,
    double dirX,
    double dirY,
    double planeX,
    double planeY,
    double invDet,
    double time,
  ) {
    if (sprites.isEmpty) return;

    _drawOrder.clear();
    _drawOrder.addAll(sprites);
    final px = player.x;
    final py = player.y;
    _drawOrder.sort((a, b) {
      final adx = a.x - px;
      final ady = a.y - py;
      final bdx = b.x - px;
      final bdy = b.y - py;
      return (bdx * bdx + bdy * bdy).compareTo(adx * adx + ady * ady);
    });

    final w = size.width;
    final h = size.height;
    final colW = w / GameConstants.rayCount;
    final z = _zBuffer;

    for (final sprite in _drawOrder) {
      final relX = sprite.x - px;
      final relY = sprite.y - py;
      final transformX = invDet * (dirY * relX - dirX * relY);
      final transformY = invDet * (-planeY * relX + planeX * relY);
      if (transformY <= 0.05) continue;

      final centerX = w * 0.5 * (1 + transformX / transformY);
      final screenH = (h / transformY).abs() * sprite.scale;
      if (screenH < 1 || centerX.isNaN) continue;

      switch (sprite.kind) {
        case SpriteKind.key:
          _drawKey(canvas, size, centerX, transformY, screenH, sprite.bobPhase,
              time, colW, z);
          break;
        case SpriteKind.ghost:
          _drawGhost(
              canvas, size, centerX, transformY, screenH, time, colW, z);
          break;
      }
    }
  }

  static void _drawKey(
    Canvas canvas,
    Size size,
    double centerX,
    double depth,
    double screenH,
    double bobPhase,
    double time,
    double colW,
    Float32List z,
  ) {
    final half = screenH * 0.5;
    final centerY =
        size.height * 0.5 + math.sin(time * 2 + bobPhase) * 0.06 * screenH;
    final top = centerY - half;
    final bottom = centerY + half;

    final rays = GameConstants.rayCount;
    var firstCol = ((centerX - half) / colW).floor();
    var lastCol = ((centerX + half) / colW).ceil();
    if (lastCol < 0 || firstCol >= rays) return;
    if (firstCol < 0) firstCol = 0;
    if (lastCol > rays - 1) lastCol = rays - 1;

    var runStart = -1;
    for (var c = firstCol; c <= lastCol; c++) {
      final visible = z[c] > depth;
      if (visible && runStart < 0) runStart = c;
      if ((!visible || c == lastCol) && runStart >= 0) {
        final runEnd = visible && c == lastCol ? c : c - 1;
        _drawKeyRun(
            canvas, runStart, runEnd, centerX, centerY, top, bottom, half,
            colW);
        runStart = -1;
      }
    }
  }

  static void _drawKeyRun(
    Canvas canvas,
    int colFrom,
    int colTo,
    double centerX,
    double centerY,
    double top,
    double bottom,
    double half,
    double colW,
  ) {
    final xs = colFrom * colW;
    final xe = (colTo + 1) * colW;
    final pad = half * 0.7;
    canvas.drawRect(
      Rect.fromLTRB(xs - pad, top - pad, xe + pad, bottom + pad),
      _keyHaloPaint,
    );

    for (var c = colFrom; c <= colTo; c++) {
      final midX = (c + 0.5) * colW;
      final adx = ((midX - centerX) / half).abs();
      if (adx >= 1) continue;
      final dyMax = half * (1 - adx);
      canvas.drawRect(
        Rect.fromLTRB(c * colW, centerY - dyMax, (c + 1) * colW,
            centerY + dyMax),
        _keyPaint,
      );
      final coreDy = dyMax * 0.5;
      final coreHalfW = colW * 0.25;
      canvas.drawRect(
        Rect.fromLTRB(midX - coreHalfW, centerY - coreDy, midX + coreHalfW,
            centerY + coreDy),
        _keyCorePaint,
      );
    }
  }

  static void _drawGhost(
    Canvas canvas,
    Size size,
    double centerX,
    double depth,
    double screenH,
    double time,
    double colW,
    Float32List z,
  ) {
    final width = screenH * 0.55;
    final cy = size.height * 0.5 + math.sin(time * 2.1) * 0.03 * screenH;
    final cx = centerX + math.sin(time * 1.3) * 0.05 * width;
    final top = cy - screenH * 0.5;
    final bottom = cy + screenH * 0.5;
    final headR = width * 0.30;
    final headCY = top + headR;
    final shoulderY = headCY + headR * 0.55;
    final hw = width * 0.5;

    _ghostPaint.color = Color.fromRGBO(
        214, 222, 232, _clamp(0.8 + 0.1 * math.sin(time * 3), 0.0, 1.0));

    final path = _ghostPath;
    path.reset();
    path.moveTo(cx - hw, shoulderY);
    path.lineTo(cx - headR, headCY);
    path.quadraticBezierTo(cx - headR, top, cx, top);
    path.quadraticBezierTo(cx + headR, top, cx + headR, headCY);
    path.lineTo(cx + hw, shoulderY);
    path.lineTo(cx + hw, bottom);
    const segments = 6;
    for (var k = segments - 1; k >= 1; k--) {
      final fx = cx + hw - 2 * hw * k / segments;
      final amp = width * (k.isEven ? 0.11 : 0.05);
      final fy = bottom - amp * (0.55 + 0.45 * math.sin(time * 4.2 + k * 2.1));
      path.lineTo(fx, fy);
    }
    path.lineTo(cx - hw, bottom);
    path.close();

    final rays = GameConstants.rayCount;
    var firstCol = ((centerX - hw) / colW).floor();
    var lastCol = ((centerX + hw) / colW).ceil();
    if (lastCol < 0 || firstCol >= rays) return;
    if (firstCol < 0) firstCol = 0;
    if (lastCol > rays - 1) lastCol = rays - 1;

    var runStart = -1;
    for (var c = firstCol; c <= lastCol; c++) {
      final visible = z[c] > depth;
      if (visible && runStart < 0) runStart = c;
      if ((!visible || c == lastCol) && runStart >= 0) {
        final runEnd = visible && c == lastCol ? c : c - 1;
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(
            runStart * colW, top - 1, (runEnd + 1) * colW, bottom + 1));
        canvas.drawPath(path, _ghostPaint);
        _drawGhostFeatures(canvas, cx, headCY, headR);
        canvas.restore();
        runStart = -1;
      }
    }
  }

  static void _drawGhostFeatures(
      Canvas canvas, double cx, double headCY, double headR) {
    final eyeDX = headR * 0.38;
    final eyeY = headCY + headR * 0.08;
    final eyeW = headR * 0.34;
    final eyeH = headR * 0.52;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - eyeDX, eyeY), width: eyeW, height: eyeH),
      _ghostFeaturePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx + eyeDX, eyeY), width: eyeW, height: eyeH),
      _ghostFeaturePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, headCY + headR * 0.66),
        width: headR * 0.30,
        height: headR * 0.62,
      ),
      _ghostFeaturePaint,
    );
  }

  static double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);
}
