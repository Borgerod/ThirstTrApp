import '../core/enums.dart';
import '../models/heat_source.dart';
import '../models/plant.dart';
import '../models/room.dart';
import '../models/window_object.dart';
import 'weather_api.dart';

/// Everything the scheduler needs to know about a plant's surroundings.
class CareContext {
  CareContext({
    required this.plant,
    this.room,
    this.window,
    this.heatSources = const [],
    this.weather,
    DateTime? now,
  }) : now = now ?? DateTime.now();

  final Plant plant;
  final Room? room;
  final WindowObject? window;
  final List<HeatSource> heatSources;
  final WeatherSnapshot? weather;
  final DateTime now;
}

/// One computed care interval + next due date with a human explanation.
class CarePlan {
  CarePlan({
    required this.type,
    required this.intervalDays,
    required this.nextDue,
    required this.factors,
  });

  final CareType type;
  final int intervalDays;
  final DateTime nextDue;

  /// label -> multiplier, for the "why" breakdown in the UI.
  final Map<String, double> factors;

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

  static double _lightFactor(LightIntensity l) => switch (l) {
        LightIntensity.shaded => 1.2, // dries slower -> water less often
        LightIntensity.indirect => 1.0,
        LightIntensity.direct => 0.8, // dries faster -> water more often
      };

  /// Compute the watering plan for a plant in its context.
  static CarePlan watering(CareContext c) {
    final base = c.plant.intervals.waterDays ?? c.plant.species?.baseWateringDays ?? 7;
    final factors = <String, double>{};

    final light = resolveLight(c);
    factors['Lys (${light.label})'] = _lightFactor(light);

    final season = WeatherApi.seasonFor(c.now);
    factors['Sesong'] = WeatherApi.seasonFactor(season);

    if (c.weather != null) {
      factors['Vær'] = c.weather!.wateringFactor;
      if (c.weather!.precip24hMm > 5) {
        factors['Regn ute'] = 1.1; // higher outdoor humidity indoors-ish
      }
    }

    if (c.room != null) {
      final dev = (c.room!.effectiveTemperatureC - 21) * 0.015;
      factors['Romtemp'] = (1 - dev).clamp(0.8, 1.2);
    }

    if (c.plant.nearHeatSource || c.heatSources.isNotEmpty) {
      final intensity = c.heatSources.isEmpty
          ? 1.3
          : c.heatSources.map((h) => h.effectiveIntensity).reduce((a, b) => a > b ? a : b);
      factors['Varmekilde'] = (1 / (0.9 + intensity * 0.15)).clamp(0.7, 1.0);
    }

    if (c.plant.nearDraft || c.window?.openFrequency == OpenFrequency.often) {
      factors['Trekk'] = 0.9;
    }

    var days = base.toDouble();
    for (final f in factors.values) {
      days *= f;
    }
    final intervalDays = days.round().clamp(1, 90);

    final last = c.plant.lastDoneFor(CareType.water);
    final next = (last ?? c.now).add(Duration(days: intervalDays));
    return CarePlan(
      type: CareType.water,
      intervalDays: intervalDays,
      nextDue: last == null ? c.now : next,
      factors: factors,
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
