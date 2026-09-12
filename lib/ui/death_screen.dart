import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/game_state.dart';

const Color _bone = Color(0xFFECEFF1);
const Color _blood = Color(0xFFB71C1C);
const Color _dimGray = Color(0xFF616161);
const Color _void = Color(0xFF050505);

class DeathScreen extends StatefulWidget {
  const DeathScreen({super.key, required this.gameState});

  final GameState gameState;

  @override
  State<DeathScreen> createState() => _DeathScreenState();
}

class _DeathScreenState extends State<DeathScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _seq = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _seq.dispose();
    super.dispose();
  }

  Widget _buildFlash({required bool second}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final face =
            constraints.biggest.shortestSide * (second ? 0.74 : 0.60);
        return ColoredBox(
          color: const Color(0xFFF4F4F2),
          child: Center(
            child: Transform.rotate(
              angle: second ? -0.05 : 0.04,
              child: CustomPaint(
                size: Size(face, face),
                painter: const _GhostFacePainter(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'YOU DIED',
            style: TextStyle(
              fontSize: 54,
              fontWeight: FontWeight.w900,
              letterSpacing: 12,
              color: _blood,
              shadows: [
                Shadow(color: _blood.withValues(alpha: 0.80), blurRadius: 30),
                Shadow(color: Colors.black, blurRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 42),
          OutlinedButton(
            onPressed: widget.gameState.startGame,
            style: OutlinedButton.styleFrom(
              foregroundColor: _bone,
              backgroundColor: Colors.black,
              side: const BorderSide(color: _blood, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              minimumSize: const Size(230, 52),
            ),
            child: const Text(
              'RETRY',
              style: TextStyle(
                fontSize: 16,
                letterSpacing: 6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: widget.gameState.backToMenu,
            style: OutlinedButton.styleFrom(
              foregroundColor: _bone.withValues(alpha: 0.75),
              backgroundColor: Colors.black,
              side: const BorderSide(color: _dimGray, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              minimumSize: const Size(230, 52),
            ),
            child: const Text(
              'MAIN MENU',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _seq,
      builder: (context, _) {
        final t = _seq.value;
        final flashing = t < 0.16 || (t >= 0.26 && t < 0.46);
        final uiAlpha =
            ((t - 0.60) / 0.38).clamp(0.0, 1.0).toDouble();
        final residual = (!flashing && t < 0.76)
            ? (1 - (t - 0.46) / 0.30).clamp(0.0, 1.0).toDouble()
            : 0.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: _void),
            if (flashing) _buildFlash(second: t >= 0.26),
            if (residual > 0)
              ColoredBox(
                color: const Color(0xFFF4F4F2).withValues(alpha: residual),
              ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: uiAlpha < 0.99,
                child: Opacity(opacity: uiAlpha, child: _buildContent()),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GhostFacePainter extends CustomPainter {
  const _GhostFacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    final rx = w * 0.34;
    final ry = w * 0.46;
    final cy = size.height * 0.40;

    final head = Path()
      ..moveTo(cx - rx, cy)
      ..cubicTo(cx - rx, cy - ry * 1.35, cx + rx, cy - ry * 1.35, cx + rx, cy)
      ..cubicTo(
          cx + rx, cy + ry * 0.55, cx + rx * 0.70, cy + ry * 0.98, cx + rx * 0.46, cy + ry * 1.06);

    const segments = 5;
    final xR = cx + rx * 0.46;
    final xL = cx - rx * 0.46;
    for (var i = 0; i < segments; i++) {
      final x0 = xR + (xL - xR) * (i / segments);
      final x1 = xR + (xL - xR) * ((i + 1) / segments);
      final deep = i.isEven;
      head.quadraticBezierTo(
        (x0 + x1) / 2,
        cy + ry * (deep ? 1.32 : 1.02),
        x1,
        cy + ry * (deep ? 1.06 : 1.18),
      );
    }
    head.cubicTo(
        cx - rx * 0.70, cy + ry * 0.98, cx - rx, cy + ry * 0.55, cx - rx, cy);
    head.close();

    canvas.drawPath(
      head,
      Paint()
        ..color = const Color(0x66F4F6F8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );
    canvas.drawPath(head, Paint()..color = const Color(0xFFE7EBEF));
    canvas.drawPath(
      head,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, w * 0.006)
        ..color = const Color(0xFF8B949C),
    );

    final dark = Paint()..color = Colors.black;
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(cx + side * rx * 0.42, cy - ry * 0.18);
      canvas.rotate(side * 0.14);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: rx * 0.34,
          height: rx * 0.50,
        ),
        dark,
      );
      canvas.restore();
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + ry * 0.44),
        width: rx * 0.42,
        height: ry * 0.62,
      ),
      dark,
    );
  }

  @override
  bool shouldRepaint(_GhostFacePainter oldDelegate) => false;
}
