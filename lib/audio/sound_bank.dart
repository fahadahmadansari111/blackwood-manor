import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'synth_engine.dart';

abstract final class SfxIds {
  static const String ambient = 'ambient';
  static const String heartbeat = 'heartbeat';
  static const String keyPickup = 'keyPickup';
  static const String unlockCreak = 'unlockCreak';
  static const String ghostAggro = 'ghostAggro';
  static const String jumpscare = 'jumpscare';
  static const String doorLocked = 'doorLocked';
}

enum Sfx { keyPickup, unlockCreak, ghostAggro, jumpscare, doorLocked }

/// Owns every synthesized buffer and AudioPlayer. All synthesis happens once
/// in [init]; gameplay only triggers playback.
class SoundBank {
  static const String _wavMime = 'audio/wav';
  static const int _poolSize = 4;

  static const Map<Sfx, String> _ids = {
    Sfx.keyPickup: SfxIds.keyPickup,
    Sfx.unlockCreak: SfxIds.unlockCreak,
    Sfx.ghostAggro: SfxIds.ghostAggro,
    Sfx.jumpscare: SfxIds.jumpscare,
    Sfx.doorLocked: SfxIds.doorLocked,
  };

  static const Map<Sfx, double> _volumes = {
    Sfx.keyPickup: 0.7,
    Sfx.unlockCreak: 0.7,
    Sfx.ghostAggro: 0.85,
    Sfx.jumpscare: 1.0,
    Sfx.doorLocked: 0.7,
  };

  final Map<String, Uint8List> _bytes = {};
  final List<AudioPlayer> _pool = [];
  AudioPlayer? _ambient;
  AudioPlayer? _heartbeat;
  bool _ready = false;
  Future<void>? _initFuture;
  int _nextPoolIndex = 0;
  double _appliedTension = -1;

  /// Synthesizes all buffers and creates players. Idempotent; safe to await
  /// multiple times. All other methods no-op until this completes.
  Future<void> init() {
    final existing = _initFuture;
    if (existing != null) return existing;
    final future = _init();
    _initFuture = future;
    return future;
  }

  Future<void> _init() async {
    if (_ready) return;

    _bytes[SfxIds.ambient] = SynthEngine.encodeWav(SynthEngine.droneLoop());
    _bytes[SfxIds.heartbeat] = SynthEngine.encodeWav(SynthEngine.heartbeat());
    _bytes[SfxIds.keyPickup] = SynthEngine.encodeWav(SynthEngine.keyChime());
    _bytes[SfxIds.unlockCreak] = SynthEngine.encodeWav(SynthEngine.unlockCreak());
    _bytes[SfxIds.ghostAggro] = SynthEngine.encodeWav(SynthEngine.ghostAggro());
    _bytes[SfxIds.jumpscare] = SynthEngine.encodeWav(SynthEngine.jumpscare());
    _bytes[SfxIds.doorLocked] = SynthEngine.encodeWav(SynthEngine.doorLocked());

    _ambient = AudioPlayer();
    await _ambient!.setReleaseMode(ReleaseMode.loop);
    _heartbeat = AudioPlayer();
    await _heartbeat!.setReleaseMode(ReleaseMode.loop);
    for (var i = 0; i < _poolSize; i++) {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.release);
      _pool.add(player);
    }
    _ready = true;
  }

  Future<void> startAmbient() async {
    if (!_ready) return;
    final ambBytes = _bytes[SfxIds.ambient];
    if (ambBytes != null && _ambient != null) {
      await _ambient!.stop();
      await _ambient!.setVolume(0.6);
      unawaited(_ambient!.play(BytesSource(ambBytes, mimeType: _wavMime)));
    }
    final beatBytes = _bytes[SfxIds.heartbeat];
    if (beatBytes != null && _heartbeat != null) {
      await _heartbeat!.stop();
      await _heartbeat!.setPlaybackRate(_heartRate(0));
      await _heartbeat!.setVolume(_heartVolume(0));
      unawaited(_heartbeat!.play(BytesSource(beatBytes, mimeType: _wavMime)));
    }
  }

  Future<void> stopAmbient() async {
    if (!_ready) return;
    await _ambient?.stop();
    await _heartbeat?.stop();
  }

  void play(Sfx sfx) {
    if (!_ready || _pool.isEmpty) return;
    final data = _bytes[_ids[sfx]];
    if (data == null) return;
    final player = _pool[_nextPoolIndex];
    _nextPoolIndex = (_nextPoolIndex + 1) % _pool.length;
    unawaited(_fireOneShot(player, data, _volumes[sfx] ?? 0.7));
  }

  void setTension(double t) {
    final v = t.clamp(0.0, 1.0).toDouble();
    if (!_ready || (_appliedTension - v).abs() <= 0.02) return;
    _appliedTension = v;
    final hb = _heartbeat;
    if (hb == null) return;
    unawaited(hb.setVolume(_heartVolume(v)));
    unawaited(hb.setPlaybackRate(_heartRate(v)));
  }

  Future<void> dispose() async {
    _ready = false;
    _initFuture = null;
    for (final player in [_ambient, _heartbeat, ..._pool]) {
      if (player == null) continue;
      try {
        await player.stop();
        await player.dispose();
      } on Exception {
        // Player already released; nothing to recover.
      }
    }
    _pool.clear();
    _ambient = null;
    _heartbeat = null;
    _bytes.clear();
  }

  static Future<void> _fireOneShot(
    AudioPlayer player,
    Uint8List bytes,
    double volume,
  ) async {
    await player.stop();
    await player.setVolume(volume);
    await player.play(BytesSource(bytes, mimeType: _wavMime));
  }

  // Heart races faster and louder as tension rises.
  static double _heartVolume(double t) =>
      0.05 + 0.95 * math.pow(t, 1.2).toDouble();

  static double _heartRate(double t) => 0.9 + t * 1.3;
}
