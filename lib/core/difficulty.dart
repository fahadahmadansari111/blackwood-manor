import 'constants.dart';

/// Playable difficulty modes.
enum Difficulty { easy, medium, hard }

/// Per-ghost behavior tuning. Medium matches the [GameConstants] baseline.
class GhostTuning {
  const GhostTuning({
    required this.patrolSpeed,
    required this.chaseSpeed,
    required this.sightRange,
    required this.drainPerSecond,
  });

  final double patrolSpeed;
  final double chaseSpeed;
  final double sightRange;
  final double drainPerSecond;

  static const GhostTuning medium = GhostTuning(
    patrolSpeed: GameConstants.ghostPatrolSpeed,
    chaseSpeed: GameConstants.ghostChaseSpeed,
    sightRange: GameConstants.ghostSightRange,
    drainPerSecond: GameConstants.ghostDrainPerSecond,
  );

  static const GhostTuning easy = GhostTuning(
    patrolSpeed: 1.2,
    chaseSpeed: 2.4,
    sightRange: 6.0,
    drainPerSecond: 6.0,
  );

  static const GhostTuning hard = GhostTuning(
    patrolSpeed: 1.9,
    chaseSpeed: 3.3,
    sightRange: 9.5,
    drainPerSecond: 16.0,
  );
}

/// Static per-mode configuration.
class DifficultyConfig {
  const DifficultyConfig._();

  /// Fixed simple map on easy, fresh random manor otherwise.
  static int ghostCount(Difficulty d) => switch (d) {
        Difficulty.easy => 1,
        Difficulty.medium => 1,
        Difficulty.hard => 3,
      };

  static GhostTuning tuning(Difficulty d) => switch (d) {
        Difficulty.easy => GhostTuning.easy,
        Difficulty.medium => GhostTuning.medium,
        Difficulty.hard => GhostTuning.hard,
      };

  static bool useFixedMap(Difficulty d) => d == Difficulty.easy;

  /// Easy radar shows uncollected key positions.
  static bool showKeysOnRadar(Difficulty d) => d == Difficulty.easy;

  /// Easy radar always shows the ghost; medium uses proximity + line of
  /// sight; hard shows no radar at all.
  static bool alwaysShowGhost(Difficulty d) => d == Difficulty.easy;

  static bool radarEnabled(Difficulty d) => d != Difficulty.hard;

  static String label(Difficulty d) => switch (d) {
        Difficulty.easy => 'EASY',
        Difficulty.medium => 'MEDIUM',
        Difficulty.hard => 'HARD',
      };

  static String tagline(Difficulty d) => switch (d) {
        Difficulty.easy => 'fixed manor · seer map · 1 weak ghost',
        Difficulty.medium => 'random manor · 1 ghost',
        Difficulty.hard => 'random manor · 3 hungry ghosts · no map',
      };
}
