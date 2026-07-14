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

/// A room's rectangle on the floor-plan canvas, normalized 0..1 to the canvas
/// bounds (so the layout survives canvas resizes). `x`/`y` is the top-left
/// corner; `w`/`h` the size. Set by the floor-plan builder when a room is drawn
/// or placed.
class FloorRect {
  const FloorRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final double x;
  final double y;
  final double w;
  final double h;

  FloorRect copyWith({double? x, double? y, double? w, double? h}) => FloorRect(
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        h: h ?? this.h,
      );

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  factory FloorRect.fromJson(Map<String, dynamic> j) => FloorRect(
        x: (asDouble(j['x']) ?? 0).clamp(0.0, 1.0),
        y: (asDouble(j['y']) ?? 0).clamp(0.0, 1.0),
        w: (asDouble(j['w']) ?? 0.2).clamp(0.05, 1.0),
        h: (asDouble(j['h']) ?? 0.2).clamp(0.05, 1.0),
      );
}
