import 'dart:math' as math;

import '../core/enums.dart';
import '../core/json.dart';

/// A heat source in a room (oven, fireplace, heat pump, ...).
///
/// The user supplies only what they can read off the device: its type, the
/// rated power from the label (optional — a typical value per type is used
/// otherwise), and the dial setting or thermostat target. Heat *intensity* and
/// *spread* are *computed* from those — output power, the radiant/convective
/// split per heater type, and inverse-square decay with distance — instead of
/// being guessed by the user.
class HeatSource {
  HeatSource({
    required this.id,
    required this.name,
    this.roomId,
    this.type = HeatType.electricHeater,
    this.ratedPowerW,
    this.heatSetting,
    this.tempSetting,
  });

  final String id;
  String name;
  String? roomId;
  HeatType type;

  /// Rated (max) electrical/heat power from the device label [W]. Null → the
  /// typical value for the type is assumed.
  double? ratedPowerW;

  /// Dial-style setting; one of this or [tempSetting] should be set.
  HeatSetting? heatSetting;

  /// Thermostat target in °C.
  double? tempSetting;

  /// Typical rated power by type [W] when no label value is given.
  static double defaultRatedW(HeatType t) => switch (t) {
        HeatType.oilHeater => 2000, // rolling oil radiators: 1500–2500 W
        HeatType.heatingCable => 600, // bathroom floor loop
        HeatType.fanHeater => 2000,
        HeatType.wallHeater => 1000, // panel oven
        HeatType.electricHeater => 1500,
        HeatType.heatPump => 4500, // heat *output*, not compressor draw
        HeatType.fireplace => 6000, // nominal wood-stove output
        HeatType.other => 1500,
      };

  double get ratedW => ratedPowerW ?? defaultRatedW(type);

  /// Mean duty fraction of rated power for the dial setting. A thermostatted
  /// device can pull full power; the room-level model caps it at the target.
  double get _settingFraction => switch (heatSetting) {
        HeatSetting.low => 0.35,
        HeatSetting.medium => 0.65,
        HeatSetting.high => 1.0,
        HeatSetting.static_ => 0.65,
        null => tempSetting != null ? 1.0 : 0.65,
      };

  /// Average heat output [W].
  double get outputW => ratedW * _settingFraction;

  /// Fraction of output emitted as thermal radiation (rest is convective).
  /// Engineering typicals: oil/panel radiators ~35–40 %, floors ~50 %,
  /// fan-driven units nearly all convective.
  double get radiantFraction => switch (type) {
        HeatType.oilHeater => 0.40,
        HeatType.heatingCable => 0.50,
        HeatType.fanHeater => 0.05,
        HeatType.wallHeater => 0.35,
        HeatType.electricHeater => 0.40,
        HeatType.heatPump => 0.02,
        HeatType.fireplace => 0.50,
        HeatType.other => 0.30,
      };

  double get radiantW => outputW * radiantFraction;
  double get convectiveW => outputW - radiantW;

  /// Temperature the device tries to hold: explicit thermostat, else the
  /// built-in thermostat implied by the dial position.
  double get targetC =>
      tempSetting ??
      switch (heatSetting) {
        HeatSetting.low => 18,
        HeatSetting.medium => 22,
        HeatSetting.high => 27,
        HeatSetting.static_ => 22,
        null => 22,
      };

  /// Local air-temperature rise [°C] at [distanceM] from the device, from its
  /// radiant emission: ΔT = α·P_rad/(4πd²)/h with absorptivity α ≈ 0.9 and an
  /// indoor convective film coefficient h ≈ 6 W/m²K. Inverse-square decay is
  /// the "heat spread" — no user guess needed.
  double localRiseC(double distanceM) {
    final d = math.max(distanceM, 0.3); // touching the unit isn't modelled
    return (0.9 * radiantW / (4 * math.pi * d * d) / 6.0).clamp(0.0, 8.0);
  }

  /// Legacy relative intensity (≈ output vs a 1.5 kW panel). Kept for the
  /// draft/air-movement model.
  double get effectiveIntensity => (outputW / 1500).clamp(0.2, 3.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roomId': roomId,
        'type': type.id,
        'ratedPowerW': ratedPowerW,
        'heatSetting': heatSetting?.id,
        'tempSetting': tempSetting,
      };

  factory HeatSource.fromJson(Map<String, dynamic> j) => HeatSource(
        id: j['id'] as String,
        name: asString(j['name']) ?? 'Varmekilde',
        roomId: asString(j['roomId']),
        type: HeatType.fromId(asString(j['type'])),
        ratedPowerW: asDouble(j['ratedPowerW']),
        heatSetting: j['heatSetting'] == null
            ? null
            : HeatSetting.fromId(asString(j['heatSetting'])),
        tempSetting: asDouble(j['tempSetting']),
        // Legacy heatSpread/heatIntensity fields are ignored: both are now
        // computed from type + power + setting.
      );
}
