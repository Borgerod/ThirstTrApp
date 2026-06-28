import '../core/enums.dart';
import '../core/json.dart';

/// A window a plant can be linked to. Drives light estimation.
class WindowObject {
  WindowObject({
    required this.id,
    required this.name,
    this.roomId,
    this.openFrequency = OpenFrequency.normal,
    this.size = WindowSize.regular,
    this.facing = Facing.unknown,
    this.lightMeasurementLux,
    this.lightIntensity,
  });

  final String id;
  String name;
  String? roomId;
  OpenFrequency openFrequency;
  WindowSize size;
  Facing facing;

  /// Measured lux if the user owns a light meter.
  double? lightMeasurementLux;

  /// Word-based fallback when no meter reading exists.
  LightIntensity? lightIntensity;

  /// Resolved light intensity: prefer measured lux, else stated word, else
  /// estimate from facing + size.
  LightIntensity get resolvedIntensity {
    if (lightMeasurementLux != null) {
      final lux = lightMeasurementLux!;
      if (lux < 5000) return LightIntensity.shaded;
      if (lux < 20000) return LightIntensity.indirect;
      return LightIntensity.direct;
    }
    if (lightIntensity != null) return lightIntensity!;
    final score = facing.lightFactor * size.lightFactor;
    if (score < 0.7) return LightIntensity.shaded;
    if (score < 1.3) return LightIntensity.indirect;
    return LightIntensity.direct;
  }

  /// Open windows on a cold/windy day = drafts = faster soil drying.
  double get draftFactor => switch (openFrequency) {
        OpenFrequency.often => 1.25,
        OpenFrequency.normal => 1.0,
        OpenFrequency.never => 0.9,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roomId': roomId,
        'openFrequency': openFrequency.id,
        'size': size.id,
        'facing': facing.id,
        'lightMeasurementLux': lightMeasurementLux,
        'lightIntensity': lightIntensity?.id,
      };

  factory WindowObject.fromJson(Map<String, dynamic> j) => WindowObject(
        id: j['id'] as String,
        name: asString(j['name']) ?? 'Vindu',
        roomId: asString(j['roomId']),
        openFrequency: OpenFrequency.fromId(asString(j['openFrequency'])),
        size: WindowSize.fromId(asString(j['size'])),
        facing: Facing.fromId(asString(j['facing'])),
        lightMeasurementLux: asDouble(j['lightMeasurementLux']),
        lightIntensity: j['lightIntensity'] == null
            ? null
            : LightIntensity.fromId(asString(j['lightIntensity'])),
      );
}
