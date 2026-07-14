import '../core/json.dart';

/// One floor/storey of the home. The floor-plan builder shows a single floor at
/// a time (selectable from the floor rail); rooms are placed on a floor as
/// rectangles (see `Room.floorId` + `Room.floorRect`).
class Floor {
  Floor({required this.id, required this.name, this.level = 0});

  final String id;
  String name;

  /// Ordering key — lower is further down (ground = 0). Drives the floor rail
  /// order and the "+" that adds the next floor up.
  int level;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'level': level};

  factory Floor.fromJson(Map<String, dynamic> j) => Floor(
        id: j['id'] as String,
        name: asString(j['name']) ?? 'Etasje',
        level: asInt(j['level']) ?? 0,
      );
}
