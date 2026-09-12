import 'dart:math';

import '../core/constants.dart';
import '../core/game_state.dart';
import 'house_map.dart';
import 'pathfinding.dart';
import 'player.dart';

enum GhostState { patrol, chase, search }

class Ghost {
  Ghost(this.x, this.y)
      : spawnX = x,
        spawnY = y;

  final double spawnX;
  final double spawnY;

  double x;
  double y;
  double angle = 0;

  GhostState state = GhostState.patrol;

  void Function()? onAggro;
  void Function()? onDrainTick;

  static const double _bodyRadius = 0.35;
  static const double _lungeRange = 2.2;
  static const double _turnRate = 6.0;
  static const double _drainPulseEvery = 0.45;

  List<(double, double)>? _route;
  int _waypointIndex = 0;
  List<Point>? _path;
  int _nodeIndex = 0;
  double _repathTimer = 0;
  double _lostSightTimer = 0;
  double _searchTimer = 0;
  double _drainPulseTimer = 0;
  double _lastSeenX = 0;
  double _lastSeenY = 0;

  void reset() {
    x = spawnX;
    y = spawnY;
    angle = 0;
    state = GhostState.patrol;
    _route = null;
    _waypointIndex = 0;
    _path = null;
    _nodeIndex = 0;
    _repathTimer = 0;
    _lostSightTimer = 0;
    _searchTimer = 0;
    _drainPulseTimer = 0;
    _lastSeenX = spawnX;
    _lastSeenY = spawnY;
  }

  void update(double dt, HouseMap map, Player player, GameState gs) {
    if (dt.isNaN || dt <= 0) return;
    if (dt > 0.1) dt = 0.1;

    final pdx = player.x - x;
    final pdy = player.y - y;
    final dist = sqrt(pdx * pdx + pdy * pdy);

    switch (state) {
      case GhostState.patrol:
        _patrol(dt, map, player, dist);
      case GhostState.chase:
        _chase(dt, map, player, dist);
      case GhostState.search:
        _search(dt, map, player, dist);
    }

    if (dist <= GameConstants.ghostDrainRange &&
        (dist < 0.9 || map.hasLineOfSight(x, y, player.x, player.y))) {
      gs.drainHealth(GameConstants.ghostDrainPerSecond * dt);
      _drainPulseTimer += dt;
      if (_drainPulseTimer >= _drainPulseEvery) {
        _drainPulseTimer -= _drainPulseEvery;
        onDrainTick?.call();
      }
    } else {
      _drainPulseTimer = 0;
    }

    final closeness = (GameConstants.proximityZero - dist) /
        (GameConstants.proximityZero - GameConstants.proximityFull);
    gs.ghostProximity.value = closeness < 0 ? 0 : (closeness > 1 ? 1 : closeness);
  }

  void _patrol(double dt, HouseMap map, Player player, double dist) {
    if (_spotted(map, player, dist)) {
      _beginChase(player);
      return;
    }
    final route = _currentRoute(map);
    final waypoint = route[_waypointIndex];
    if (_steerToward(
        waypoint.$1, waypoint.$2, GameConstants.ghostPatrolSpeed, dt, map)) {
      _waypointIndex = (_waypointIndex + 1) % route.length;
    }
  }

  void _chase(double dt, HouseMap map, Player player, double dist) {
    if (_spotted(map, player, dist)) {
      _lastSeenX = player.x;
      _lastSeenY = player.y;
      _lostSightTimer = 0;
    } else {
      _lostSightTimer += dt;
      if (_lostSightTimer >= GameConstants.ghostSearchDuration) {
        _beginSearch();
        return;
      }
    }

    _repathTimer -= dt;
    if (_repathTimer <= 0) {
      _repathTimer = GameConstants.ghostRepathInterval;
      _path = Pathfinding.findPath(
        map,
        Point(x.floor(), y.floor()),
        Point(player.x.floor(), player.y.floor()),
      );
      _nodeIndex = 0;
    }

    final node = _nextNode();
    if (node != null) {
      if (_steerToward(
          node.$1, node.$2, GameConstants.ghostChaseSpeed, dt, map)) {
        _nodeIndex++;
      }
    } else if (dist > GameConstants.ghostStopDistance) {
      // No path (blocked/unreachable): face the player instead of
      // beelining through walls and sticking on corners.
      if (map.hasLineOfSight(x, y, player.x, player.y)) {
        _steerToward(player.x, player.y, GameConstants.ghostChaseSpeed, dt, map);
      } else {
        _faceToward(player.x, player.y, dt);
      }
    } else {
      _faceToward(player.x, player.y, dt);
    }
  }

  void _search(double dt, HouseMap map, Player player, double dist) {
    if (_spotted(map, player, dist)) {
      _beginChase(player);
      return;
    }
    _searchTimer += dt;
    if (_searchTimer >= GameConstants.ghostSearchDuration * 2) {
      _beginPatrol();
      return;
    }
    if (_path == null) {
      _path = Pathfinding.findPath(
        map,
        Point(x.floor(), y.floor()),
        Point(_lastSeenX.floor(), _lastSeenY.floor()),
      );
      _nodeIndex = 0;
      if (_path == null || _path!.isEmpty) {
        _beginPatrol();
        return;
      }
    }
    final node = _nextNode();
    if (node == null) {
      _beginPatrol();
      return;
    }
    if (_steerToward(
        node.$1, node.$2, GameConstants.ghostPatrolSpeed, dt, map)) {
      _nodeIndex++;
    }
  }

  void _beginChase(Player player) {
    if (state != GhostState.chase) onAggro?.call();
    state = GhostState.chase;
    _lastSeenX = player.x;
    _lastSeenY = player.y;
    _lostSightTimer = 0;
    _repathTimer = 0;
    _path = null;
    _nodeIndex = 0;
    _searchTimer = 0;
  }

  void _beginSearch() {
    state = GhostState.search;
    _searchTimer = 0;
    _path = null;
    _nodeIndex = 0;
  }

  void _beginPatrol() {
    state = GhostState.patrol;
    _route = null; // forces a fresh nearest-route pick
    _waypointIndex = 0;
    _path = null;
    _nodeIndex = 0;
    _lostSightTimer = 0;
    _searchTimer = 0;
  }

  bool _spotted(HouseMap map, Player player, double dist) {
    // Point-blank grab connects even around a corner; lunge range and
    // beyond require line of sight so walls block vision/drain camping.
    if (dist < 0.9) return true;
    if (dist > GameConstants.ghostSightRange) return false;
    if (dist < _lungeRange) {
      return map.hasLineOfSight(x, y, player.x, player.y);
    }
    return map.hasLineOfSight(x, y, player.x, player.y);
  }

  List<(double, double)> _currentRoute(HouseMap map) {
    final cached = _route;
    if (cached != null && cached.isNotEmpty) return cached;
    final routes = map.patrolRoutes;
    if (routes.isEmpty) return const [(16.5, 6.5)];
    var best = routes.first;
    if (best.isEmpty) return const [(16.5, 6.5)];
    var bestDist = double.infinity;
    for (final route in routes) {
      if (route.isEmpty) continue;
      final first = route.first;
      final d =
          (first.$1 - x) * (first.$1 - x) + (first.$2 - y) * (first.$2 - y);
      if (d < bestDist) {
        bestDist = d;
        best = route;
      }
    }
    if (best.isEmpty) return const [(16.5, 6.5)];
    var bestIndex = 0;
    var bestIndexDist = double.infinity;
    for (var i = 0; i < best.length; i++) {
      final w = best[i];
      final d = (w.$1 - x) * (w.$1 - x) + (w.$2 - y) * (w.$2 - y);
      if (d < bestIndexDist) {
        bestIndexDist = d;
        bestIndex = i;
      }
    }
    _waypointIndex = bestIndex;
    _route = best;
    return best;
  }

  (double, double)? _nextNode() {
    final path = _path;
    if (path == null || _nodeIndex >= path.length) return null;
    final node = path[_nodeIndex];
    return (node.x.toDouble() + 0.5, node.y.toDouble() + 0.5);
  }

  /// Sliding circle-vs-grid move toward ([tx], [ty]); returns true on arrival.
  bool _steerToward(
      double tx, double ty, double speed, double dt, HouseMap map) {
    final dx = tx - x;
    final dy = ty - y;
    final len = sqrt(dx * dx + dy * dy);
    if (len <= GameConstants.ghostArriveThreshold) return true;
    final step = speed * dt;
    final scale = step < len ? step / len : 1.0;
    _slideBy(dx * scale, dy * scale, map);
    _faceToward(tx, ty, dt);
    return false;
  }

  /// Axis-separated slide: X then Y, each rejected on corner overlap.
  void _slideBy(double mx, double my, HouseMap map) {
    final nx = x + mx;
    if (!_blocked(nx, y, map)) x = nx;
    final ny = y + my;
    if (!_blocked(x, ny, map)) y = ny;
  }

  bool _blocked(double px, double py, HouseMap map) {
    return map.isSolid(px - _bodyRadius, py - _bodyRadius) ||
        map.isSolid(px + _bodyRadius, py - _bodyRadius) ||
        map.isSolid(px - _bodyRadius, py + _bodyRadius) ||
        map.isSolid(px + _bodyRadius, py + _bodyRadius);
  }

  void _faceToward(double tx, double ty, double dt) {
    final target = atan2(ty - y, tx - x);
    var diff = target - angle;
    while (diff > pi) {
      diff -= 2 * pi;
    }
    while (diff < -pi) {
      diff += 2 * pi;
    }
    final maxTurn = _turnRate * dt;
    if (diff.abs() <= maxTurn) {
      angle = target;
    } else {
      angle += diff > 0 ? maxTurn : -maxTurn;
    }
  }
}
