import '../core/enums.dart';
import '../models/heat_source.dart';
import '../models/plant.dart';
import '../models/room.dart';
import '../models/window_object.dart';
import 'evapotranspiration.dart';
import 'weather_api.dart';

/// Everything the scheduler needs to know about a plant's surroundings.
class CareContext {
  CareContext({
    required this.plant,
    this.room,
    this.window,
    this.draftWindow,
    this.heatSources = const [],
    this.roomHeatSources = const [],
    this.weather,
    this.latitude,
    DateTime? now,
  }) : now = now ?? DateTime.now();

  final Plant plant;
  final Room? room;

  /// The window the plant stands by (light).
  final WindowObject? window;

  /// The window the plant's draft comes from (plant.draftWindowId).
  final WindowObject? draftWindow;

  /// Radiant sources the user marked the plant as "near" (local heating).
  final List<HeatSource> heatSources;

  /// ALL heat sources in the plant's room — they set the ambient room
  /// temperature whether or not the plant is near one.
  final List<HeatSource> roomHeatSources;

  final WeatherSnapshot? weather;

  /// Home latitude (from settings) — lets the ET model compute real daylight
  /// hours instead of assuming them.
  final double? latitude;

  final DateTime now;

  /// Bundle the surroundings for the evapotranspiration engine.
  EtInputs get etInputs => EtInputs(
        plant: plant,
        room: room,
        window: window,
        draftWindow: draftWindow,
        nearbyHeatSources: heatSources,
        roomHeatSources: roomHeatSources,
        weather: weather,
        latitude: latitude,
        now: now,
      );
}

/// One computed care interval + next due date with a human explanation.
class CarePlan {
  CarePlan({
    required this.type,
    required this.intervalDays,
    required this.nextDue,
    required this.factors,
    this.details,
    this.quality,
  });

  final CareType type;
  final int intervalDays;
  final DateTime nextDue;

  /// label -> multiplier, for the "why" breakdown in the UI (legacy heuristic
  /// care types: fertilizing/cleaning).
  final Map<String, double> factors;

  /// Rich, pre-formatted "why" rows for physics-based estimates (watering).
  /// label -> formatted value; preferred over [factors] when present.
  final List<MapEntry<String, String>>? details;

  /// Weakest data source behind this estimate. When [ClimateSource.statistical]
  /// the UI should warn that the estimate is a guess and better inputs help.
  final ClimateSource? quality;

  bool get isOverdue => nextDue.isBefore(DateTime.now());
}

/// Core care-schedule engine. Pure functions — easy to unit test.
class Scheduler {
  /// Resolve effective light for a plant from its own data, then window, room.
  static LightIntensity resolveLight(CareContext c) {
    return c.plant.statedLight ??
        c.window?.resolvedIntensity ??
        c.room?.resolvedIntensity ??
        LightIntensity.indirect;
  }

  /// Compute the watering plan for a plant in its context.
  ///
  /// Physics-based: a FAO-56 Penman-Monteith evapotranspiration estimate at the
  /// plant's resolved microclimate (see [WaterModel]) gives the daily soil-water
  /// loss; the interval is how long the pot's readily-available reserve lasts.
  /// A user-set override on the plant short-circuits the model.
  static CarePlan watering(CareContext c) {
    final last = c.plant.lastDoneFor(CareType.water);

    // Explicit user override always wins over the estimate.
    final override = c.plant.intervals.waterDays;
    if (override != null) {
      final next = (last ?? c.now).add(Duration(days: override));
      return CarePlan(
        type: CareType.water,
        intervalDays: override,
        nextDue: last == null ? c.now : next,
        factors: const {},
        details: [const MapEntry('Kilde', 'Manuelt satt intervall')],
      );
    }

    final est = WaterModel.estimate(c.etInputs);
    final next = (last ?? c.now).add(Duration(days: est.intervalDays));
    return CarePlan(
      type: CareType.water,
      intervalDays: est.intervalDays,
      nextDue: last == null ? c.now : next,
      factors: const {},
      details: est.breakdown,
      quality: est.quality,
    );
  }

  /// Fertilizing: tied to growth season; little/none in winter dormancy.
  static CarePlan fertilizing(CareContext c) {
    final season = WeatherApi.seasonFor(c.now);
    final base = c.plant.intervals.fertilizeDays ??
        switch (season) {
          Season.spring || Season.summer => 14,
          Season.autumn => 30,
          Season.winter => 60,
        };
    final last = c.plant.lastDoneFor(CareType.fertilize);
    final next = (last ?? c.now).add(Duration(days: base));
    return CarePlan(
      type: CareType.fertilize,
      intervalDays: base,
      nextDue: last == null ? c.now.add(Duration(days: base ~/ 2)) : next,
      factors: {'Sesong (${season.name})': 1.0},
    );
  }

  /// Cleaning leaves — gentle default cadence.
  static CarePlan cleaning(CareContext c) {
    final base = c.plant.intervals.cleanDays ?? 30;
    final last = c.plant.lastDoneFor(CareType.clean);
    final next = (last ?? c.now).add(Duration(days: base));
    return CarePlan(
      type: CareType.clean,
      intervalDays: base,
      nextDue: last == null ? c.now.add(Duration(days: base)) : next,
      factors: const {},
    );
  }

  /// Misting — only when explicitly configured (humidity lovers).
  static CarePlan? misting(CareContext c) {
    final days = c.plant.intervals.mistDays;
    if (days == null) return null;
    final last = c.plant.lastDoneFor(CareType.mist);
    final next = (last ?? c.now).add(Duration(days: days));
    return CarePlan(
      type: CareType.mist,
      intervalDays: days,
      nextDue: last == null ? c.now : next,
      factors: const {},
    );
  }

  /// All applicable care plans for a plant.
  static List<CarePlan> allPlans(CareContext c) => [
        watering(c),
        fertilizing(c),
        // Cleaning is opt-in: only scheduled when the user set an interval for
        // this plant. Not all plants need leaf cleaning.
        if (c.plant.intervals.cleanDays != null) cleaning(c),
        if (misting(c) != null) misting(c)!,
      ];
}
