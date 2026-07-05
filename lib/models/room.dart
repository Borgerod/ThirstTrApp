import '../core/enums.dart';
import '../core/json.dart';

/// A room grouping plants and objects. All properties optional with sensible
/// fallbacks (room temperature falls back to 21 °C per spec).
class Room {
  Room({
    required this.id,
    required this.name,
    this.sizeSqm,
    this.temperatureC,
    this.lightMeasurementLux,
    this.lightIntensity,
    Set<Facing>? exteriorWalls,
  }) : exteriorWalls = exteriorWalls ?? <Facing>{};

  final String id;
  String name;
  double? sizeSqm;

  /// Manual thermostat reading; null -> fallback 21 °C.
  double? temperatureC;
  double? lightMeasurementLux;
  LightIntensity? lightIntensity;

  /// The cardinal directions this room has an **exterior** wall facing (toward
  /// the outdoors). A wall between two rooms is interior and simply absent from
  /// this set. Empty = a fully interior room with no outside walls.
  Set<Facing> exteriorWalls;

  /// The four cardinal directions a wall can face outward.
  static const List<Facing> cardinals = [
    Facing.north,
    Facing.east,
    Facing.south,
    Facing.west,
  ];

  double get effectiveTemperatureC => temperatureC ?? 21.0;

  LightIntensity get resolvedIntensity {
    if (lightMeasurementLux != null) {
      final lux = lightMeasurementLux!;
      if (lux < 5000) return LightIntensity.shaded;
      if (lux < 20000) return LightIntensity.indirect;
      return LightIntensity.direct;
    }
    if (lightIntensity != null) return lightIntensity!;
    // No exterior walls → no daylight reaches the room → shaded.
    if (exteriorWalls.isEmpty) return LightIntensity.shaded;
    // Otherwise the brightest outside-facing wall sets the room's daylight.
    final score =
        exteriorWalls.map((f) => f.lightFactor).reduce((a, b) => a > b ? a : b);
    if (score < 0.7) return LightIntensity.shaded;
    if (score < 1.2) return LightIntensity.indirect;
    return LightIntensity.direct;
  }

  /// Short human summary of the exterior walls for list rows.
  String get wallsSummary => exteriorWalls.isEmpty
      ? 'Kun innervegger'
      : 'Yttervegg: ${(cardinals.where(exteriorWalls.contains).map((f) => f.label)).join(', ')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sizeSqm': sizeSqm,
        'temperatureC': temperatureC,
        'lightMeasurementLux': lightMeasurementLux,
        'lightIntensity': lightIntensity?.id,
        'exteriorWalls': exteriorWalls.map((f) => f.id).toList(),
      };

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: j['id'] as String,
        name: asString(j['name']) ?? 'Rom',
        sizeSqm: asDouble(j['sizeSqm']),
        temperatureC: asDouble(j['temperatureC']),
        lightMeasurementLux: asDouble(j['lightMeasurementLux']),
        lightIntensity: j['lightIntensity'] == null
            ? null
            : LightIntensity.fromId(asString(j['lightIntensity'])),
        exteriorWalls: _wallsFromJson(j),
      );

  /// Parse the wall set, migrating the legacy single `facing` field: an old
  /// room with one cardinal facing becomes a room with that one exterior wall.
  static Set<Facing> _wallsFromJson(Map<String, dynamic> j) {
    final raw = j['exteriorWalls'];
    if (raw is List) {
      return raw
          .map((e) => Facing.fromId(e.toString()))
          .where((f) => f != Facing.unknown)
          .toSet();
    }
    final legacy = asString(j['facing']);
    if (legacy != null) {
      final f = Facing.fromId(legacy);
      if (f != Facing.unknown) return {f};
    }
    return {};
  }
}
