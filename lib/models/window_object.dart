import '../core/enums.dart';
import '../core/json.dart';
import 'floor_position.dart';

/// A window (or glass door) a plant can be linked to. Drives light estimation.
class WindowObject {
  WindowObject({
    required this.id,
    required this.name,
    this.roomId,
    this.type = WindowType.window,
    this.openFrequency = OpenFrequency.normal,
    this.size = WindowSize.regular,
    this.facing = Facing.unknown,
    this.diffused = false,
    this.lightMeasurementLux,
    this.lightIntensity,
    this.floorPosition,
  });

  final String id;
  String name;
  String? roomId;
  WindowType type;
  OpenFrequency openFrequency;
  WindowSize size;
  Facing facing;

  /// Frosted/diffusing glass: light still gets in, but never as direct beams.
  bool diffused;

  /// Room-local position on the floor-plan canvas. Not user-editable — set by
  /// the floor-plan builder when the window is placed. Null until placed.
  FloorPosition? floorPosition;

  /// Measured lux if the user owns a light meter.
  double? lightMeasurementLux;

  /// Word-based fallback when no meter reading exists.
  LightIntensity? lightIntensity;

  /// Resolved light intensity: prefer measured lux, else stated word, else
  /// estimate from facing + size + glazed share. Diffused glass scatters the
  /// beams, so the result is capped at indirect no matter the source.
  LightIntensity get resolvedIntensity {
    final raw = _rawIntensity;
    if (diffused && raw == LightIntensity.direct) return LightIntensity.indirect;
    return raw;
  }

  LightIntensity get _rawIntensity {
    if (lightMeasurementLux != null) {
      final lux = lightMeasurementLux!;
      if (lux < 5000) return LightIntensity.shaded;
      if (lux < 20000) return LightIntensity.indirect;
      return LightIntensity.direct;
    }
    if (lightIntensity != null) return lightIntensity!;
    final score = facing.lightFactor * size.lightFactor * type.glassFactor;
    if (score < 0.7) return LightIntensity.shaded;
    if (score < 1.3) return LightIntensity.indirect;
    return LightIntensity.direct;
  }

  /// Open windows on a cold/windy day = drafts = faster soil drying.
  double get draftFactor => switch (openFrequency) {
        OpenFrequency.never => 0.9,
        OpenFrequency.rarely => 0.95,
        OpenFrequency.normal => 1.0,
        OpenFrequency.often => 1.25,
        OpenFrequency.always => 1.4,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roomId': roomId,
        'type': type.id,
        'diffused': diffused,
        'openFrequency': openFrequency.id,
        'size': size.id,
        'facing': facing.id,
        'lightMeasurementLux': lightMeasurementLux,
        'lightIntensity': lightIntensity?.id,
        'floorPosition': floorPosition?.toJson(),
      };

  factory WindowObject.fromJson(Map<String, dynamic> j) => WindowObject(
        id: j['id'] as String,
        name: asString(j['name']) ?? 'Vindu',
        roomId: asString(j['roomId']),
        type: WindowType.fromId(asString(j['type'])),
        diffused: j['diffused'] == true,
        openFrequency: OpenFrequency.fromId(asString(j['openFrequency'])),
        size: WindowSize.fromId(asString(j['size'])),
        facing: Facing.fromId(asString(j['facing'])),
        lightMeasurementLux: asDouble(j['lightMeasurementLux']),
        lightIntensity: j['lightIntensity'] == null
            ? null
            : LightIntensity.fromId(asString(j['lightIntensity'])),
        floorPosition: j['floorPosition'] == null
            ? null
            : FloorPosition.fromJson(
                Map<String, dynamic>.from(j['floorPosition'])),
      );
}
