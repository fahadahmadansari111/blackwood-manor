import '../core/constants.dart';
import '../core/game_state.dart';
import 'player.dart';
import 'raycast_renderer.dart';

class KeyEntity {
  KeyEntity(this.x, this.y);

  final double x;
  final double y;
  bool collected = false;
}

class WorldEntities {
  WorldEntities({required List<(double, double)> spawns})
      : keys = [for (final s in spawns) KeyEntity(s.$1, s.$2)];

  final List<KeyEntity> keys;

  void reset(List<(double, double)> spawns) {
    keys
      ..clear()
      ..addAll([for (final s in spawns) KeyEntity(s.$1, s.$2)]);
  }

  List<SpriteBillboard> billboards(double time) {
    final result = <SpriteBillboard>[];
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      if (key.collected) continue;
      result.add(SpriteBillboard(
        x: key.x,
        y: key.y,
        kind: SpriteKind.key,
        bobPhase: i * 1.7,
        scale: GameConstants.keyBillboardScale,
      ));
    }
    return result;
  }

  int tryCollect(Player player, GameState gs) {
    var collected = 0;
    final radiusSq =
        GameConstants.keyPickupRadius * GameConstants.keyPickupRadius;
    for (final key in keys) {
      if (key.collected) continue;
      final dx = key.x - player.x;
      final dy = key.y - player.y;
      if (dx * dx + dy * dy <= radiusSq) {
        key.collected = true;
        gs.collectKey();
        collected++;
      }
    }
    return collected;
  }
}
