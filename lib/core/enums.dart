/// All shared enums for ThirstTrApp domain.
///
/// Each enum has a stable string `id` used for JSON persistence and a
/// `label` (Norwegian default) for display. Parsing falls back to the first
/// value when an unknown id is encountered so old data never crashes the app.
library;

import 'package:flutter/material.dart';

enum LightIntensity {
  shaded('shaded', 'Skyggefull'),
  indirect('indirect', 'Indirekte'),
  direct('direct', 'Direkte');

  const LightIntensity(this.id, this.label);
  final String id;
  final String label;

  static LightIntensity fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => indirect);
}

enum RoomPlacement {
  corner('corner', 'Hjørne'),
  inRoom('in-room', 'I rommet'),
  window('window', 'Vindu');

  const RoomPlacement(this.id, this.label);
  final String id;
  final String label;

  static RoomPlacement fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => inRoom);
}

enum HeatType {
  oilHeater('oil_heater', 'Oljeovn'),
  heatingCable('heating_cable', 'Varmekabler'),
  fanHeater('fan_heater', 'Vifteovn'),
  wallHeater('wall_heater', 'Veggovn'),
  electricHeater('electric_heater', 'Elektrisk ovn'),
  heatPump('heat_pump', 'Varmepumpe'),
  fireplace('fireplace', 'Peis'),
  other('other', 'Annet');

  const HeatType(this.id, this.label);
  final String id;
  final String label;

  static HeatType fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => other);
}

/// Generic low/medium/high used for heat spread, intensity, etc.
enum Level {
  low('low', 'Lav'),
  medium('med', 'Middels'),
  high('high', 'Høy');

  const Level(this.id, this.label);
  final String id;
  final String label;

  static Level fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => medium);

  double get factor => switch (this) { low => 0.5, medium => 1.0, high => 1.6 };
}

enum HeatSetting {
  low('low', 'Lav'),
  medium('med', 'Middels'),
  high('high', 'Høy'),
  static_('static', 'Statisk');

  const HeatSetting(this.id, this.label);
  final String id;
  final String label;

  static HeatSetting fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => static_);
}

/// How often a window/glass door is opened, ordered least → most open.
///
/// Migration: the old 3-option scale used the ids `never`/`normal`/`often`,
/// which all exist unchanged here, so stored values map onto the new scale
/// as-is; anything unknown falls back to [normal].
enum OpenFrequency {
  never('never', 'Aldri'),
  rarely('rarely', 'Sjelden'),
  normal('normal', 'Normalt'),
  often('often', 'Ofte'),
  always('always', 'Alltid');

  const OpenFrequency(this.id, this.label);
  final String id;
  final String label;

  /// Open at least "often" — enough to drive draft/ventilation effects.
  bool get isFrequent => index >= often.index;

  static OpenFrequency fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => normal);
}

/// What kind of glazed object a [WindowObject] is. Glass doors act as windows
/// for both draft and sunlight; [glassFactor] is the glazed share of the
/// object's area (a door with a glass panel lets roughly half the light of a
/// fully glazed one through).
enum WindowType {
  window('window', 'Vindu', 1.0, Icons.window),
  glassDoor('glass_door', 'Glassdør', 1.0, Icons.door_sliding),
  partialGlassDoor(
      'partial_glass_door', 'Dør med glassfelt', 0.5, Icons.door_front_door);

  const WindowType(this.id, this.label, this.glassFactor, this.icon);
  final String id;
  final String label;
  final double glassFactor;
  final IconData icon;

  static WindowType fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => window);
}

enum WindowSize {
  tiny('tiny', 'Bitteliten', 0.5),
  small('small', 'Liten', 0.75),
  regular('regular', 'Vanlig', 1.0),
  big('big', 'Stor', 1.4),
  huge('huge', 'Enorm', 1.8);

  const WindowSize(this.id, this.label, this.lightFactor);
  final String id;
  final String label;
  final double lightFactor;

  static WindowSize fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => regular);
}

enum CareType {
  water('water', 'Vanning', Icons.water_drop),
  fertilize('fertilize', 'Gjødsling', Icons.eco),
  clean('clean', 'Rengjøring', Icons.cleaning_services),
  mist('mist', 'Spraying', Icons.water);

  const CareType(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;

  static CareType fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => water);
}

enum TaskStatus {
  due('due', 'Forfaller'),
  done('done', 'Fullført'),
  postponed('postponed', 'Utsatt'),
  skipped('skipped', 'Hoppet over');

  const TaskStatus(this.id, this.label);
  final String id;
  final String label;

  static TaskStatus fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => due);
}

enum UnitSystem {
  metric('metric', 'Metrisk (°C, cm)'),
  imperial('imperial', 'Imperisk (°F, in)');

  const UnitSystem(this.id, this.label);
  final String id;
  final String label;

  static UnitSystem fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => metric);
}

/// Home-screen portfolio layout. Cycled via the app-bar toggle:
/// flat portfolio list → grouped by room → floorplan room view.
enum PortfolioView {
  groupByView('group_by_view', 'Samlet liste'),
  groupByRoom('group_by_room', 'Gruppert etter rom'),
  roomView('room_view', 'Romvisning (planløsning)');

  const PortfolioView(this.id, this.label);
  final String id;
  final String label;

  static PortfolioView fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => groupByView);

  /// Next mode in the cycle (wraps around).
  PortfolioView get next => values[(index + 1) % values.length];
}

/// An opening between two rooms in the floor plan. A gap is a plain wall
/// opening; a doorway is a door-sized passage. Both let draft, heat and
/// sunlight pass between the rooms they connect.
enum OpeningType {
  gap('gap', 'Åpning', Icons.space_bar),
  doorway('doorway', 'Døråpning', Icons.sensor_door_outlined);

  const OpeningType(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;

  static OpeningType fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => doorway);
}

/// How tall an opening is: full height (floor to ceiling) or half (ceiling to
/// half way down). The vertical share sets how much air/heat/light crosses it.
enum OpeningHeight {
  full('full', 'Full (gulv til tak)', 1.0),
  half('half', 'Halv (tak til midtveis)', 0.5);

  const OpeningHeight(this.id, this.label, this.fraction);
  final String id;
  final String label;

  /// Fraction of the wall height the opening spans.
  final double fraction;

  static OpeningHeight fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => full);
}

/// Cardinal facing of a window/room — affects light estimation.
enum Facing {
  north('north', 'Nord', 0.55),
  east('east', 'Øst', 0.85),
  south('south', 'Sør', 1.3),
  west('west', 'Vest', 0.95),
  unknown('unknown', 'Ukjent', 1.0);

  const Facing(this.id, this.label, this.lightFactor);
  final String id;
  final String label;
  final double lightFactor;

  static Facing fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => unknown);
}
