import '../core/json.dart';

/// Room-local placement of an item on the floor-plan ("gulvplan") canvas.
///
/// These are NOT geographic coordinates and NOT user-editable. The floor-plan
/// builder writes them when the item (plant, heat source, ...) is dropped onto
/// a room. Values are normalized 0..1 within the room's bounds — `x` across the
/// room width, `y` across its depth — so a saved layout survives canvas resizes
/// and different screen sizes.
class FloorPosition {
  const FloorPosition({required this.x, required this.y});

  /// Horizontal position within the room, 0 (left) .. 1 (right).
  final double x;

  /// Vertical position within the room, 0 (top) .. 1 (bottom).
  final double y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory FloorPosition.fromJson(Map<String, dynamic> j) => FloorPosition(
        x: (asDouble(j['x']) ?? 0).clamp(0.0, 1.0),
        y: (asDouble(j['y']) ?? 0).clamp(0.0, 1.0),
      );
}
