import 'dart:math' as math;
import 'dart:typed_data';

const double _twoPi = math.pi * 2;

/// Fully procedural horror SFX synthesis. Pure Dart DSP.
/// Mono 44100 Hz; all buffers are Float32 samples in -1..1.
abstract final class SynthEngine {
  static const int sampleRate = 44100;

  static final math.Random _rng = math.Random(0x0CCA7);

  /// ~20 s dark-ambient bed, seamless loop (last 2 s crossfaded into first 2 s).
  static Float32List droneLoop() {
    const double loopSecs = 20.0;
    const double fadeSecs = 2.0;
    final int n = (loopSecs * sampleRate).round();
    final int m = n + (fadeSecs * sampleRate).round();
    final int fade = m - n;
    final double dt = 1.0 / sampleRate;

    final buf = Float32List(m);
    final lpFizzA = _OnePole()..setCutoff(420);
    final lpFizzB = _OnePole()..setCutoff(330);
    final lpWind = _OnePole()..setCutoff(300);

    const double fA = 55.0; // A1 sub drone
    const double fB = 82.41; // E2 sub drone
    const double pingF = 1479.98;
    const double pingF2 = pingF * 2.756; // inharmonic metallic partial
    const double pingTau = 0.85;
    const List<double> pingTimes = [1.3, 7.8, 14.3];

    double phA = 0, phB = 0, phPing = 0, phPing2 = 0, brown = 0;
    for (int i = 0; i < m; i++) {
      final double t = i * dt;

      phA += fA * dt;
      phA -= phA.floorToDouble();
      phB += fB * dt;
      phB -= phB.floorToDouble();
      phPing += pingF * dt;
      phPing -= phPing.floorToDouble();
      phPing2 += pingF2 * dt;
      phPing2 -= phPing2.floorToDouble();

      // Slow LFO amplitude swells on the two drones.
      final double swellA = 0.55 + 0.45 * math.sin(_twoPi * t / 11.0);
      final double swellB = 0.55 + 0.45 * math.sin(_twoPi * t / 17.0 + 1.2);

      // Blended sine + saw gives the drones body without harsh top end.
      final double voiceA =
          (math.sin(_twoPi * phA) + 0.55 * (2 * phA - 1)) / 1.55;
      final double voiceB =
          (math.sin(_twoPi * phB) + 0.40 * (2 * phB - 1)) / 1.40;
      final double drone =
          lpFizzA.process(voiceA * swellA * 0.5) +
          lpFizzB.process(voiceB * swellB * 0.42);

      // Brown-noise wind through a breathing one-pole lowpass.
      brown = (brown + 0.02 * _white()) * 0.997;
      lpWind.setCutoff(
        260 + 150 * math.sin(_twoPi * t / 23.0) + 45 * math.sin(_twoPi * t / 7.9 + 1.7),
      );
      final double gust = 0.45 + 0.35 * math.sin(_twoPi * t / 17.0 + 0.9);
      final double wind = lpWind.process(brown * 6.0) * gust;

      // Distant metallic pings with exponential decay.
      double ping = 0;
      for (final double t0 in pingTimes) {
        if (t >= t0) {
          final double a = math.exp(-(t - t0) / pingTau);
          ping += a *
              (math.sin(_twoPi * phPing) + 0.35 * math.sin(_twoPi * phPing2)) /
              1.35;
        }
      }

      buf[i] = drone + wind * 0.9 + ping * 0.14;
    }

    // Remove DC, then equal-power crossfade the tail into the head.
    double mean = 0;
    for (int i = 0; i < m; i++) {
      mean += buf[i];
    }
    mean /= m;
    for (int i = 0; i < m; i++) {
      buf[i] -= mean;
    }

    final out = Float32List(n);
    // Equal-power crossfade: the rendered tail buf[n..m) melts into the head,
    // so the seam lands on the natural continuation buf[n-1] -> buf[n].
    for (int i = 0; i < fade; i++) {
      final double w = i / fade;
      final double aw = math.sqrt(w);
      final double bw = math.sqrt(1 - w);
      out[i] = buf[i] * aw + buf[n + i] * bw;
    }
    out.setRange(fade, n, buf, fade);
    return _normalized(out, 0.55);
  }

  /// Exactly 1.0 s: one lub-dub pair, silence elsewhere. Clean loop points.
  static Float32List heartbeat() {
    final out = Float32List(sampleRate);
    final lp = _OnePole()..setCutoff(160);
    _thump(out, 0, 0.060, 65, 57, 0.022, 1.0, lp);
    _thump(out, (0.18 * sampleRate).round(), 0.052, 82, 72, 0.018, 0.68, lp);
    return _normalized(out, 0.9);
  }

  static void _thump(
    Float32List out,
    int start,
    double dur,
    double f0,
    double f1,
    double tau,
    double amp,
    _OnePole lp,
  ) {
    final int len = (dur * sampleRate).round();
    final int atk = (0.003 * sampleRate).round();
    final double logRatio = math.log(f1 / f0);
    double ph = 0;
    for (int i = 0; i < len; i++) {
      final int j = start + i;
      if (j >= out.length) break;
      final double f = f0 * math.exp(logRatio * i / len);
      ph += f / sampleRate;
      ph -= ph.floorToDouble();
      final double env =
          (i / atk).clamp(0.0, 1.0).toDouble() * math.exp(-i / (tau * sampleRate));
      out[j] += lp.process(math.sin(_twoPi * ph) * env * amp);
    }
  }

  /// ~0.9 s bright bell arpeggio E5-G5-B5-E6, notes staggered 90 ms.
  static Float32List keyChime() {
    final int n = (0.9 * sampleRate).round();
    final out = Float32List(n);
    const List<(double, double, double)> notes = [
      (659.255, 0.00, 0.30),
      (783.991, 0.09, 0.28),
      (987.767, 0.18, 0.26),
      (1318.510, 0.27, 0.22),
    ];
    final int atk = (0.003 * sampleRate).round();
    for (final (double f, double t0, double tau) in notes) {
      final int start = (t0 * sampleRate).round();
      double ph = 0;
      for (int j = start; j < n; j++) {
        final int i = j - start;
        ph += f / sampleRate;
        ph -= ph.floorToDouble();
        final double env = (i / atk).clamp(0.0, 1.0).toDouble() *
            math.exp(-i / (tau * sampleRate));
        final double bell = math.sin(_twoPi * ph) + 0.38 * math.sin(2 * _twoPi * ph);
        out[j] += 0.55 * env * bell;
      }
    }
    return _normalized(out, 0.75);
  }

  /// ~1.2 s rusty hinge: sawtooth sweep 95->58 Hz, irregular vibrato,
  /// plus band-passed noise burst "stick-slip" chatter.
  static Float32List unlockCreak() {
    final int n = (1.2 * sampleRate).round();
    final out = Float32List(n);
    final double dt = 1.0 / sampleRate;
    final bp = _Svf(0.35)..setCutoff(880);
    const List<(double, double, double)> bursts = [
      (0.08, 0.05, 0.9),
      (0.33, 0.045, 0.7),
      (0.55, 0.07, 1.0),
      (0.84, 0.05, 0.6),
      (1.03, 0.065, 0.8),
    ];
    final double logRatio = math.log(58 / 95);
    final int atk = (0.05 * sampleRate).round();
    final int rel = (0.95 * sampleRate).round();
    double ph = 0;
    double walk = 0;
    for (int i = 0; i < n; i++) {
      final double t = i * dt;
      // Slow smoothed random walk = irregular pitch jitter.
      walk = ((walk + _white() * 0.004).clamp(-0.06, 0.06)).toDouble() * 0.9985;
      final double f = 95 * math.exp(logRatio * t / 1.2) *
          (1 + 0.06 * math.sin(_twoPi * 6.7 * t) +
              0.045 * math.sin(_twoPi * 11.3 * t + 1.1) +
              walk);
      ph += f * dt;
      ph -= ph.floorToDouble();
      final double stick = 0.62 + 0.38 * math.sin(_twoPi * 3.3 * t + 0.4);
      double env = i < atk ? i / atk : 1.0;
      if (i > rel) env *= math.exp(-(i - rel) / (0.12 * sampleRate));

      double burst = 0;
      for (final (double t0, double d, double a) in bursts) {
        if (t >= t0 && t < t0 + d) {
          burst += _white() * math.sin(math.pi * (t - t0) / d) * a;
        }
      }

      out[i] = (2 * ph - 1) * stick * env * 0.8 + bp.band(burst) * 2.0;
    }
    return _normalized(out, 0.8);
  }

  /// ~1.4 s breathy shriek: noise through a resonant band sweeping
  /// 400->1400 Hz, layered with dissonant detuned sines.
  static Float32List ghostAggro() {
    final int n = (1.4 * sampleRate).round();
    final out = Float32List(n);
    final double dt = 1.0 / sampleRate;
    final bp = _Svf(0.07);
    final int atk = (0.012 * sampleRate).round();
    final int hold = (0.85 * sampleRate).round();
    final double tailTau = 0.38 * sampleRate;
    final double logSweep = math.log(1400 / 400);
    double ph1 = 0, ph2 = 0;
    for (int i = 0; i < n; i++) {
      final double u = (i / (0.45 * sampleRate)).clamp(0.0, 1.0).toDouble();
      final double fc = 400 * math.exp(logSweep * u);
      bp.setCutoff(fc);
      final double breath = bp.band(_white()) * 2.2;
      final double f1 = fc * 1.31;
      final double f2 = fc * 1.355;
      ph1 += f1 * dt;
      ph1 -= ph1.floorToDouble();
      ph2 += f2 * dt;
      ph2 -= ph2.floorToDouble();
      final double tone = math.sin(_twoPi * ph1) + math.sin(_twoPi * ph2);
      final double env = (i / atk).clamp(0.0, 1.0).toDouble() *
          (i < hold ? 1.0 : math.exp(-(i - hold) / tailTau));
      out[i] = (breath + tone * 0.42) * env;
    }
    return _normalized(out, 0.92);
  }

  /// ~1.5 s violent sting: minor-second clusters pitch-slammed down,
  /// white-noise burst, tanh saturation, hard attack.
  static Float32List jumpscare() {
    final int n = (1.5 * sampleRate).round();
    final out = Float32List(n);
    final double dt = 1.0 / sampleRate;
    const double slamSecs = 0.13;
    const List<(double, double)> pairs = [
      (880.0, 110.0),
      (932.33, 116.54),
      (659.26, 82.41),
      (698.46, 87.31),
    ];
    final List<double> logRatios =
        pairs.map(((double, double) p) => math.log(p.$2 / p.$1)).toList();
    final phases = Float64List(pairs.length);
    final lp = _OnePole()..setCutoff(2800);
    final int atk = (0.001 * sampleRate).round();
    final double normClip = _tanh(1.7);
    for (int i = 0; i < n; i++) {
      final double t = i * dt;
      final double cu = (t / slamSecs).clamp(0.0, 1.0).toDouble();
      final double curve = cu * cu; // accelerating downward slam
      double sawSum = 0;
      for (int k = 0; k < pairs.length; k++) {
        final double f = pairs[k].$1 * math.exp(logRatios[k] * curve);
        phases[k] += f * dt;
        phases[k] -= phases[k].floorToDouble();
        sawSum += 2 * phases[k] - 1;
      }
      final double noise = _white() * math.exp(-t / 0.045) * 1.1;
      final double clipped = _tanh(1.7 * lp.process(sawSum * 0.5 + noise)) / normClip;
      final double env = (i / atk).clamp(0.0, 1.0).toDouble() * math.exp(-t / 0.5);
      out[i] = clipped * env;
    }
    return _normalized(out, 0.98);
  }

  /// ~0.35 s muffled 70 Hz thud + short band-passed rattle.
  static Float32List doorLocked() {
    final int n = (0.35 * sampleRate).round();
    final out = Float32List(n);
    final double dt = 1.0 / sampleRate;
    final lp = _OnePole()..setCutoff(160);
    final bp = _Svf(0.3)..setCutoff(1750);
    const double f0 = 72.0, f1 = 48.0;
    final double logRatio = math.log(f1 / f0);
    final int atk = (0.002 * sampleRate).round();
    final int tau = (0.05 * sampleRate).round();
    const List<(double, double, double)> rattles = [
      (0.02, 0.018, 1.0),
      (0.065, 0.016, 0.85),
      (0.105, 0.02, 0.7),
      (0.155, 0.02, 0.5),
    ];
    double ph = 0;
    for (int i = 0; i < n; i++) {
      final double t = i * dt;
      final double f = f0 * math.exp(logRatio * (t / 0.1).clamp(0.0, 1.0));
      ph += f * dt;
      ph -= ph.floorToDouble();
      final double env = (i / atk).clamp(0.0, 1.0).toDouble() * math.exp(-i / tau);
      out[i] = lp.process(math.sin(_twoPi * ph) * env);

      double rattle = 0;
      for (final (double t0, double d, double a) in rattles) {
        if (t >= t0 && t < t0 + d) {
          rattle += _white() * math.sin(math.pi * (t - t0) / d) * a;
        }
      }
      out[i] += bp.band(rattle) * 1.6;
    }
    return _normalized(out, 0.85);
  }

  /// 16-bit PCM mono RIFF/WAVE, ready for audioplayers BytesSource.
  static Uint8List encodeWav(Float32List samples, {int sampleRate = sampleRate}) {
    final int dataLen = samples.length * 2;
    final bytes = Uint8List(44 + dataLen);
    final view = ByteData.sublistView(bytes);

    void tag(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        bytes[offset + i] = s.codeUnitAt(i);
      }
    }

    tag(0, 'RIFF');
    view.setUint32(4, 36 + dataLen, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little); // PCM
    view.setUint16(22, 1, Endian.little); // mono
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    view.setUint16(32, 2, Endian.little); // block align
    view.setUint16(34, 16, Endian.little); // bits per sample
    tag(36, 'data');
    view.setUint32(40, dataLen, Endian.little);
    for (int i = 0; i < samples.length; i++) {
      final int s = (samples[i].clamp(-1.0, 1.0) * 32767).roundToDouble().toInt();
      view.setInt16(44 + i * 2, s, Endian.little);
    }
    return bytes;
  }

  static double _white() => _rng.nextDouble() * 2.0 - 1.0;

  // Hyperbolic tangent (not in dart:math); saturator for the jumpscare.
  static double _tanh(double x) {
    final double ax = x.abs();
    if (ax > 20) return x.sign.toDouble();
    final double e2 = math.exp(-2 * ax);
    return x.sign.toDouble() * (1 - e2) / (1 + e2);
  }

  static Float32List _normalized(Float32List buf, double peak) {
    double maxAmp = 0;
    for (int i = 0; i < buf.length; i++) {
      final double a = buf[i].abs();
      if (a > maxAmp) maxAmp = a;
    }
    if (maxAmp > 0) {
      final double g = peak / maxAmp;
      for (int i = 0; i < buf.length; i++) {
        buf[i] *= g;
      }
    }
    return buf;
  }
}

/// One-pole lowpass: y[n] = y[n-1] + g * (x - y[n-1]).
final class _OnePole {
  double _y = 0;
  double _g = 0;

  void setCutoff(double hz) {
    _g = 1 - math.exp(-_twoPi * hz / SynthEngine.sampleRate);
  }

  double process(double x) {
    _y += _g * (x - _y);
    return _y;
  }
}

/// Chamberlin state-variable filter; [damping] low = more resonance.
/// `band()` returns the resonant band-pass output.
final class _Svf {
  final double damping;
  double _low = 0;
  double _band = 0;
  double _f = 0;

  _Svf(this.damping);

  void setCutoff(double hz) {
    _f = 2 * math.sin(math.pi * hz / SynthEngine.sampleRate);
  }

  double band(double x) {
    _low += _f * _band;
    _band += _f * (x - _low - damping * _band);
    return _band;
  }
}
