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
    this.facing = Facing.unknown,
  });

  final String id;
  String name;
  double? sizeSqm;

  /// Manual thermostat reading; null -> fallback 21 °C.
  double? temperatureC;
  double? lightMeasurementLux;
  LightIntensity? lightIntensity;
  Facing facing;

  double get effectiveTemperatureC => temperatureC ?? 21.0;

  LightIntensity get resolvedIntensity {
    if (lightMeasurementLux != null) {
      final lux = lightMeasurementLux!;
      if (lux < 5000) return LightIntensity.shaded;
      if (lux < 20000) return LightIntensity.indirect;
      return LightIntensity.direct;
    }
    if (lightIntensity != null) return lightIntensity!;
    final score = facing.lightFactor;
    if (score < 0.7) return LightIntensity.shaded;
    if (score < 1.2) return LightIntensity.indirect;
    return LightIntensity.direct;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sizeSqm': sizeSqm,
        'temperatureC': temperatureC,
        'lightMeasurementLux': lightMeasurementLux,
        'lightIntensity': lightIntensity?.id,
        'facing': facing.id,
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
        facing: Facing.fromId(asString(j['facing'])),
      );
}
