import '../core/enums.dart';
import '../core/json.dart';

/// A heat source in a room (oven, fireplace, heat pump, ...).
///
/// Per the spec, an oven has at least one of [heatSetting] / [tempSetting],
/// which moderate the effective [heatIntensity].
class HeatSource {
  HeatSource({
    required this.id,
    required this.name,
    this.roomId,
    this.type = HeatType.electricHeater,
    this.heatSpread = Level.medium,
    this.heatIntensity = Level.medium,
    this.heatSetting,
    this.tempSetting,
  });

  final String id;
  String name;
  String? roomId;
  HeatType type;

  /// How far the heat reaches (heat pump = high, oil heater = low).
  Level heatSpread;

  /// Base intensity (fireplace = high, oven/cable = low/med).
  Level heatIntensity;

  /// Dial-style setting; one of this or [tempSetting] should be set.
  HeatSetting? heatSetting;

  /// Thermostat target in °C.
  double? tempSetting;

  /// Effective intensity after applying user setting/thermostat.
  /// Used by the scheduler to bump evaporation near the plant.
  double get effectiveIntensity {
    var base = heatIntensity.factor;
    if (tempSetting != null) {
      // 21°C neutral; every degree above adds ~6%.
      base *= 1 + ((tempSetting! - 21) * 0.06);
    } else if (heatSetting != null) {
      base *= switch (heatSetting!) {
        HeatSetting.low => 0.7,
        HeatSetting.medium => 1.0,
        HeatSetting.high => 1.4,
        HeatSetting.static_ => 1.0,
      };
    }
    return base.clamp(0.2, 3.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roomId': roomId,
        'type': type.id,
        'heatSpread': heatSpread.id,
        'heatIntensity': heatIntensity.id,
        'heatSetting': heatSetting?.id,
        'tempSetting': tempSetting,
      };

  factory HeatSource.fromJson(Map<String, dynamic> j) => HeatSource(
        id: j['id'] as String,
        name: asString(j['name']) ?? 'Varmekilde',
        roomId: asString(j['roomId']),
        type: HeatType.fromId(asString(j['type'])),
        heatSpread: Level.fromId(asString(j['heatSpread'])),
        heatIntensity: Level.fromId(asString(j['heatIntensity'])),
        heatSetting: j['heatSetting'] == null
            ? null
            : HeatSetting.fromId(asString(j['heatSetting'])),
        tempSetting: asDouble(j['tempSetting']),
      );
}
