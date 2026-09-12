import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

const Color _bone = Color(0xFFECEFF1);

const int _totalMs = 14000;
const double _sceneOverscan = 2.8;
const double _endScale = 0.42;
const double _endTilt = -0.05;

class _Star {
  const _Star(this.x, this.y, this.radius, this.phase, this.speed);

  final double x;
  final double y;
  final double radius;
  final double phase;
  final double speed;
}

class OutroCinematic extends StatefulWidget {
  const OutroCinematic({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OutroCinematic> createState() => _OutroCinematicState();
}

class _OutroCinematicState extends State<OutroCinematic>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick)..start();
  late final List<_Star> _stars;

  Duration _elapsed = Duration.zero;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(11);
    _stars = List.generate(120, (_) {
      return _Star(
        rng.nextDouble(),
        rng.nextDouble() * 0.62,
        0.0009 + rng.nextDouble() * 0.0016,
        rng.nextDouble() * math.pi * 2,
        0.4 + rng.nextDouble() * 1.1,
      );
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_finished || !mounted) return;
    setState(() => _elapsed = elapsed);
    if (elapsed.inMilliseconds >= _totalMs) _complete();
  }

  void _complete() {
    if (_finished) return;
    _finished = true;
    _ticker.stop();
    widget.onComplete();
  }

  static double _easeInOutSine(double t) => 0.5 - math.cos(math.pi * t) / 2;

  double _flashAt(double sec) {
    var sum = 0.0;
    for (final start in const [4.0, 7.0, 9.5]) {
      final local = sec - start;
      if (local < 0 || local > 0.55) continue;
      sum = math.max(sum, _spike(local, 0.00, 0.055, 1.00));
      sum = math.max(sum, _spike(local, 0.12, 0.045, 0.55));
      sum = math.max(sum, _spike(local, 0.27, 0.075, 0.90));
    }
    return sum.clamp(0.0, 1.0).toDouble();
  }

  double _spike(double local, double at, double dur, double peak) {
    final x = (local - at) / dur;
    if (x < 0 || x > 1) return 0;
    return peak * (1.0 - x) * (x < 0.15 ? x / 0.15 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vw = constraints.biggest.width;
        final vh = constraints.biggest.height;
        final sw = vw * _sceneOverscan;
        final sh = vh * _sceneOverscan;

        final sec = _elapsed.inMilliseconds / 1000.0;
        final progress =
            (_elapsed.inMilliseconds / _totalMs).clamp(0.0, 1.0).toDouble();
        final ease = _easeInOutSine(progress);
        final scale = 1.0 + (_endScale - 1.0) * ease;
        final tilt = _endTilt * ease;
        final flash = _flashAt(sec);
        final ghost = progress >= 0.4 ? flash : 0.0;
        final textAlpha = _easeInOutSine(
            ((sec - 7.5) / 2.2).clamp(0.0, 1.0).toDouble());

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _complete,
          child: Stack(
            children: [
              OverflowBox(
                maxWidth: sw,
                maxHeight: sh,
                alignment: Alignment.center,
                child: SizedBox(
                  width: sw,
                  height: sh,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..translateByDouble(sw / 2, sh / 2, 0, 1)
                      ..rotateZ(tilt)
                      ..scaleByDouble(scale, scale, 1, 1)
                      ..translateByDouble(-sw / 2, -sh / 2, 0, 1),
                    child: CustomPaint(
                      size: Size(sw, sh),
                      painter: _NightPainter(
                        stars: _stars,
                        time: sec,
                        flash: flash,
                        ghost: ghost,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: vh * 0.10,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: textAlpha,
                    child: Column(
                      children: [
                        Text(
                          'You escaped...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            letterSpacing: 5,
                            fontWeight: FontWeight.w600,
                            color: _bone,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'but something followed you.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            letterSpacing: 3.5,
                            color: _bone.withValues(alpha: 0.85),
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NightPainter extends CustomPainter {
  const _NightPainter({
    required this.stars,
    required this.time,
    required this.flash,
    required this.ghost,
  });

  final List<_Star> stars;
  final double time;
  final double flash;
  final double ghost;

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width;
    final sh = size.height;
    final full = Offset.zero & size;

    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF020208), Color(0xFF0A1024)],
        ).createShader(full),
    );

    for (final star in stars) {
      final a = 0.22 +
          0.55 * (0.5 + 0.5 * math.sin(math.pi * 2 * time * star.speed + star.phase));
      canvas.drawCircle(
        Offset(star.x * sw, star.y * sh),
        star.radius * sh,
        Paint()..color = const Color(0xFFDDE4F2).withValues(alpha: a),
      );
    }

    _paintMoon(canvas, sw, sh);
    _paintFarHills(canvas, sw, sh);
    _paintHouse(canvas, sw, sh);
    _paintFrontHill(canvas, sw, sh);
    _paintFog(canvas, sw, sh);

    if (flash > 0) {
      canvas.drawRect(
        full,
        Paint()..color = Colors.white.withValues(alpha: flash * 0.85),
      );
    }

    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          radius: 0.85,
          colors: [
            const Color(0x00000000),
            Colors.black.withValues(alpha: 0.45),
          ],
          stops: const [0.60, 1.0],
        ).createShader(full),
    );
  }

  void _paintMoon(Canvas canvas, double sw, double sh) {
    final center = Offset(sw * 0.435, sh * 0.425);
    final r = sh * 0.042;

    canvas.drawCircle(
      center,
      r * 2.6,
      Paint()
        ..color = const Color(0xFFE8ECF4).withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
    );
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFFEAEDF4));
    final crater = Paint()..color = const Color(0xFFCBD2DE);
    canvas.drawCircle(
        center + Offset(-r * 0.30, -r * 0.20), r * 0.22, crater);
    canvas.drawCircle(
        center + Offset(r * 0.25, r * 0.30), r * 0.16, crater);
    canvas.drawCircle(
        center + Offset(r * 0.10, -r * 0.42), r * 0.12, crater);
  }

  void _paintFarHills(Canvas canvas, double sw, double sh) {
    final path = Path()
      ..moveTo(-4, sh * 0.545)
      ..quadraticBezierTo(sw * 0.12, sh * 0.505, sw * 0.26, sh * 0.532)
      ..quadraticBezierTo(sw * 0.40, sh * 0.558, sw * 0.55, sh * 0.528)
      ..quadraticBezierTo(sw * 0.72, sh * 0.498, sw * 0.86, sh * 0.535)
      ..quadraticBezierTo(sw * 0.94, sh * 0.552, sw + 4, sh * 0.540)
      ..lineTo(sw + 4, sh + 4)
      ..lineTo(-4, sh + 4)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF0B0F1D));
  }

  void _paintFrontHill(Canvas canvas, double sw, double sh) {
    final path = Path()
      ..moveTo(-4, sh * 0.592)
      ..quadraticBezierTo(sw * 0.15, sh * 0.552, sw * 0.32, sh * 0.576)
      ..quadraticBezierTo(sw * 0.45, sh * 0.549, sw * 0.58, sh * 0.573)
      ..quadraticBezierTo(sw * 0.75, sh * 0.550, sw * 0.92, sh * 0.579)
      ..quadraticBezierTo(sw * 0.97, sh * 0.586, sw + 4, sh * 0.588)
      ..lineTo(sw + 4, sh + 4)
      ..lineTo(-4, sh + 4)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF040407));
  }

  double _windowFlicker(double phase) {
    final slow = 0.72 + 0.20 * math.sin(time * 2.4 + phase);
    final fast = 0.85 + 0.15 * math.sin(time * 7.3 + phase * 2.7);
    final dip = math.pow(math.sin(time * 1.7 + phase), 24).toDouble() * 0.35;
    return (slow * fast - dip).clamp(0.18, 1.0).toDouble();
  }

  void _drawLitWindow(Canvas canvas, Path shape, double sh, double phase,
      {double strength = 1.0}) {
    final a = _windowFlicker(phase) * strength;
    canvas.drawPath(
      shape,
      Paint()
        ..color = const Color(0xFFB87A28).withValues(alpha: a * 0.50)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sh * 0.006),
    );
    canvas.drawPath(
      shape,
      Paint()..color = const Color(0xFFB87A28).withValues(alpha: a),
    );
  }

  void _paintHouse(Canvas canvas, double sw, double sh) {
    final cx = sw / 2;
    final u = sh;
    final gy = u * 0.560;

    final silhouette = Path()
      ..addRect(Rect.fromLTRB(
          cx - 0.085 * u, gy - 0.070 * u, cx + 0.085 * u, gy))
      ..moveTo(cx - 0.095 * u, gy - 0.070 * u)
      ..lineTo(cx, gy - 0.125 * u)
      ..lineTo(cx + 0.095 * u, gy - 0.070 * u)
      ..close()
      ..addRect(Rect.fromLTRB(
          cx + 0.040 * u, gy - 0.120 * u, cx + 0.058 * u, gy - 0.070 * u))
      ..addRect(Rect.fromLTRB(cx - 0.150 * u, gy - 0.042 * u, cx - 0.085 * u, gy))
      ..moveTo(cx - 0.158 * u, gy - 0.042 * u)
      ..lineTo(cx - 0.117 * u, gy - 0.072 * u)
      ..lineTo(cx - 0.077 * u, gy - 0.042 * u)
      ..close()
      ..moveTo(cx - 0.052 * u, gy - 0.040 * u)
      ..lineTo(cx, gy - 0.052 * u)
      ..lineTo(cx + 0.052 * u, gy - 0.040 * u)
      ..close()
      ..addRect(Rect.fromLTRB(cx - 0.045 * u, gy - 0.040 * u, cx - 0.038 * u, gy))
      ..addRect(Rect.fromLTRB(cx + 0.038 * u, gy - 0.040 * u, cx + 0.045 * u, gy));
    canvas.drawPath(silhouette, Paint()..color = const Color(0xFF07070B));

    final atticWindow = Path()
      ..moveTo(cx, gy - 0.118 * u)
      ..lineTo(cx + 0.014 * u, gy - 0.098 * u)
      ..lineTo(cx + 0.014 * u, gy - 0.088 * u)
      ..lineTo(cx - 0.014 * u, gy - 0.088 * u)
      ..lineTo(cx - 0.014 * u, gy - 0.098 * u)
      ..close();
    _drawLitWindow(canvas, atticWindow, sh, 0.0, strength: 0.9);

    if (ghost > 0) {
      canvas.save();
      canvas.clipPath(atticWindow);
      final fc = Offset(cx, gy - 0.101 * u);
      canvas.drawOval(
        Rect.fromCenter(
          center: fc,
          width: 0.020 * u,
          height: 0.026 * u,
        ),
        Paint()
          ..color = _bone.withValues(alpha: ghost.clamp(0.0, 1.0).toDouble()),
      );
      final dark = Paint()..color = Colors.black.withValues(alpha: ghost);
      canvas.drawCircle(fc + const Offset(-0.004, 0) * u, 0.0022 * u, dark);
      canvas.drawCircle(fc + const Offset(0.004, 0) * u, 0.0022 * u, dark);
      canvas.drawOval(
        Rect.fromCenter(
          center: fc + const Offset(0, 0.007) * u,
          width: 0.007 * u,
          height: 0.010 * u,
        ),
        dark,
      );
      canvas.restore();
    }

    _drawLitWindow(
      canvas,
      Path()
        ..addRect(Rect.fromCenter(
          center: Offset(cx - 0.048 * u, gy - 0.055 * u),
          width: 0.020 * u,
          height: 0.026 * u,
        )),
      sh,
      1.9,
    );
    _drawLitWindow(
      canvas,
      Path()
        ..addRect(Rect.fromCenter(
          center: Offset(cx + 0.048 * u, gy - 0.055 * u),
          width: 0.020 * u,
          height: 0.026 * u,
        )),
      sh,
      4.1,
      strength: 0.8,
    );
    _drawLitWindow(
      canvas,
      Path()
        ..addRect(Rect.fromCenter(
          center: Offset(cx - 0.117 * u, gy - 0.028 * u),
          width: 0.018 * u,
          height: 0.020 * u,
        )),
      sh,
      2.8,
      strength: 0.6,
    );

    canvas.drawRect(
      Rect.fromLTRB(cx - 0.014 * u, gy - 0.034 * u, cx + 0.014 * u, gy),
      Paint()..color = const Color(0xFF020204),
    );
  }

  void _paintFog(Canvas canvas, double sw, double sh) {
    const baseX = [0.30, 0.62, 0.46];
    const baseY = [0.578, 0.548, 0.610];
    const radiiX = [0.16, 0.22, 0.13];
    const radiiY = [0.018, 0.024, 0.015];
    const amps = [0.05, 0.08, 0.06];
    const speeds = [0.10, 0.07, 0.13];
    const phases = [0.0, 2.1, 4.2];
    const alphas = [0.11, 0.09, 0.12];

    for (var i = 0; i < 3; i++) {
      final x = (baseX[i] + amps[i] * math.sin(math.pi * 2 * time * speeds[i] + phases[i])) * sw;
      final rect = Rect.fromCenter(
        center: Offset(x, baseY[i] * sh),
        width: radiiX[i] * sw * 2,
        height: radiiY[i] * sh * 2,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..color = const Color(0xFF9AA6B8).withValues(alpha: alphas[i])
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radiiY[i] * sh),
      );
    }
  }

  @override
  bool shouldRepaint(_NightPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.flash != flash ||
      oldDelegate.ghost != ghost;
}
