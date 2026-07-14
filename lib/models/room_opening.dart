import '../core/enums.dart';
import '../core/json.dart';
import 'floor_position.dart';

/// An opening (gap or doorway) between two rooms.
///
/// Unlike a [WindowObject] (room ↔ outside), an opening connects two rooms and
/// lets draft, heat and sunlight pass between them. Its cross-flow strength
/// scales with the opening area — width × height fraction (see [flowWeight]).
class RoomOpening {
  RoomOpening({
    required this.id,
    required this.name,
    this.type = OpeningType.doorway,
    this.roomAId,
    this.roomBId,
    this.height = OpeningHeight.full,
    this.widthCm,
    this.floorPosition,
  });

  final String id;
  String name;
  OpeningType type;

  /// The two rooms this opening connects. Either may be null until the user
  /// assigns both ends.
  String? roomAId;
  String? roomBId;

  OpeningHeight height;

  /// User-specified width [cm]. Null → a type default (doorway ≈ 90, gap ≈ 120).
  double? widthCm;

  /// Room-local position on the floor-plan canvas (between the two rooms). Not
  /// user-editable — set by the floor-plan builder when the opening is drawn.
  FloorPosition? floorPosition;

  double get effectiveWidthCm =>
      widthCm ?? (type == OpeningType.doorway ? 90 : 120);

  /// True once both ends are assigned to (distinct) rooms.
  bool get isConnected =>
      roomAId != null && roomBId != null && roomAId != roomBId;

  bool connects(String roomId) => roomAId == roomId || roomBId == roomId;

  /// The room on the other end, given one end's id (null if [roomId] is not an
  /// end of this opening).
  String? otherRoom(String roomId) => roomId == roomAId
      ? roomBId
      : roomId == roomBId
          ? roomAId
          : null;

  /// Normalized cross-flow weight 0..0.9: how strongly the two rooms share
  /// climate. Scales with area (width × height fraction) against a wide-opening
  /// reference (200 cm full). Capped so a room never fully equals its neighbour.
  double get flowWeight {
    const refWidthCm = 200.0;
    final w = (effectiveWidthCm / refWidthCm) * height.fraction;
    return w.clamp(0.0, 0.9);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.id,
        'roomAId': roomAId,
        'roomBId': roomBId,
        'height': height.id,
        'widthCm': widthCm,
        'floorPosition': floorPosition?.toJson(),
      };

  factory RoomOpening.fromJson(Map<String, dynamic> j) => RoomOpening(
        id: j['id'] as String,
        name: asString(j['name']) ?? 'Åpning',
        type: OpeningType.fromId(asString(j['type'])),
        roomAId: asString(j['roomAId']),
        roomBId: asString(j['roomBId']),
        height: OpeningHeight.fromId(asString(j['height'])),
        widthCm: asDouble(j['widthCm']),
        floorPosition: j['floorPosition'] == null
            ? null
            : FloorPosition.fromJson(
                Map<String, dynamic>.from(j['floorPosition'])),
      );
}
