import 'dart:math' as math;

class CellType {
  static const int empty = 0;
  static const int wallBrick = 1;
  static const int wallWood = 2;
  static const int wallStone = 3;
  static const int wallPaper = 4;
  static const int exitDoor = 8;
}

class GameConstants {
  GameConstants._();

  static const String gameTitle = 'BLACKWOOD MANOR';

  static const double mapTileSize = 1.0;

  static const double fov = math.pi / 3;
  static const int rayCount = 240;
  static const double maxRenderDistance = 24.0;

  static const double playerStartX = 16.5;
  static const double playerStartY = 26.5;
  static const double playerStartAngle = -math.pi / 2;
  static const double playerWalkSpeed = 2.6;
  static const double playerRunSpeed = 3.8;
  static const double playerRadius = 0.28;
  static const double playerTurnSpeed = 2.4;

  static const double ghostPatrolSpeed = 1.7;
  static const double ghostChaseSpeed = 3.0;
  static const double ghostSightRange = 8.0;
  static const double ghostDrainRange = 1.3;
  static const double ghostDrainPerSecond = 10.0;
  static const double ghostSearchDuration = 5.0;
  static const double ghostRepathInterval = 0.35;
  static const double ghostArriveThreshold = 0.18;
  static const double ghostStopDistance = 0.55;
  static const double ghostSpawnX = 16.5;
  static const double ghostSpawnY = 6.5;

  static const double maxHealth = 100.0;
  static const double lowHealthThreshold = 30.0;

  static const int totalKeys = 3;
  static const double keyPickupRadius = 0.65;
  static const double keyBillboardScale = 0.35;
  static const double ghostBillboardScale = 0.95;

  static const double exitInteractDistance = 1.5;

  static const double proximityFull = 0.5;
  static const double proximityZero = 7.0;
}
