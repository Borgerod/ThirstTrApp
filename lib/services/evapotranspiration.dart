import 'dart:math' as math;

import '../core/enums.dart';
import '../core/plant_enums.dart';
import '../models/heat_source.dart';
import '../models/plant.dart';
import '../models/room.dart';
import '../models/window_object.dart';
import 'weather_api.dart';

/// Where a resolved climate value came from, best → worst. The whole point of
/// this engine is to lean on real inputs; [statistical] is the last-resort
/// fallback and its use is treated as a failure to be surfaced to the user.
enum ClimateSource {
  sensor(3, 'måler'), // light meter / thermometer the user actually owns
  manual(2, 'oppgitt'), // user-entered room/window/heat-source data
  weather(1, 'vær-API'), // MET forecast for the home location
  statistical(0, 'statistikk'); // generic indoor assumption — a fallback

  const ClimateSource(this.rank, this.label);
  final int rank;
  final String label;
}

/// A single resolved climate value tagged with its provenance.
class Measured {
  const Measured(this.value, this.source, {this.note});
  final double value;
  final ClimateSource source;
  final String? note;

  Measured copy(double v, {ClimateSource? source, String? note}) =>
      Measured(v, source ?? this.source, note: note ?? this.note);
}

/// The microclimate resolved at one plant's exact position. All the inputs the
/// FAO-56 Penman-Monteith equation needs, each carrying where it came from.
class LocalClimate {
  LocalClimate({
    required this.airTempC,
    required this.relHumidityPct,
    required this.windSpeedMs,
    required this.solarWm2,
    required this.daylightHours,
  });

  final Measured airTempC; // T   [°C]
  final Measured relHumidityPct; // RH  [%]
  final Measured windSpeedMs; // u2  [m/s]
  final Measured solarWm2; // mean shortwave irradiance at the plant [W/m²]
  final Measured daylightHours; // hours of light per day [h]

  /// Saturation vapour pressure e_s(T) [kPa] — FAO-56 eq. 11.
  static double satVapPressure(double t) =>
      0.6108 * math.exp((17.27 * t) / (t + 237.3));

  /// Slope of the e_s curve Δ [kPa/°C] — FAO-56 eq. 13.
  static double satSlope(double t) =>
      (4098 * satVapPressure(t)) / math.pow(t + 237.3, 2);

  double get es => satVapPressure(airTempC.value);
  double get ea => es * (relHumidityPct.value / 100.0);

  /// Vapour pressure deficit [kPa] — the dryness that drives transpiration.
  double get vpd => (es - ea).clamp(0.0, 10.0);

  /// Net radiation Rn [MJ/m²/day]. Indoors, incoming shortwave dominates and
  /// net longwave loss is negligible (surfaces sit near air temperature), so
  /// Rn ≈ (1−α)·Rs with the FAO reference albedo α = 0.23.
  double get netRadiationMJ {
    final rsMJ = solarWm2.value * daylightHours.value * 3600 / 1e6;
    return 0.77 * rsMJ;
  }

  /// Lowest-ranked source that fed the four PM drivers — the model is only as
  /// trustworthy as its weakest input.
  ClimateSource get quality {
    var worst = ClimateSource.sensor;
    for (final m in [airTempC, relHumidityPct, windSpeedMs, solarWm2]) {
      if (m.source.rank < worst.rank) worst = m.source;
    }
    return worst;
  }
}

/// Reference evapotranspiration via the FAO-56 Penman-Monteith equation.
class PenmanMonteith {
  // Psychrometric constant γ = 0.665e-3 · P [kPa/°C]. P at sea level = 101.3
  // kPa (indoor pressure differences are immaterial here).
  static const double _gamma = 0.000665 * 101.3;

  /// ET_ref [mm/day] for the given microclimate. G (soil heat flux) is taken
  /// as 0 over a daily indoor period.
  static double referenceEt(LocalClimate c) {
    final t = c.airTempC.value;
    final u2 = c.windSpeedMs.value;
    final delta = LocalClimate.satSlope(t);
    final rn = c.netRadiationMJ;
    final vpd = c.vpd;

    final numerator =
        0.408 * delta * rn + _gamma * (900 / (t + 273)) * u2 * vpd;
    final denominator = delta + _gamma * (1 + 0.34 * u2);
    final et = numerator / denominator;
    return et < 0 ? 0 : et;
  }
}

/// Full watering estimate for one plant: resolved microclimate → ET_ref → Kc →
/// plant water loss → how many days the pot's reserve lasts.
class EtEstimate {
  EtEstimate({
    required this.climate,
    required this.etRefMmDay,
    required this.kc,
    required this.etPlantMmDay,
    required this.readilyAvailableMm,
    required this.intervalDays,
    required this.breakdown,
  });

  final LocalClimate climate;
  final double etRefMmDay;
  final double kc;
  final double etPlantMmDay;
  final double readilyAvailableMm;
  final int intervalDays;

  /// Ordered, human-readable "why" rows for the detail sheet.
  final List<MapEntry<String, String>> breakdown;

  ClimateSource get quality => climate.quality;
}

/// Everything the model needs about a plant's surroundings. Mirrors the
/// scheduler's CareContext but kept dependency-free so the physics can be unit
/// tested in isolation.
class EtInputs {
  EtInputs({
    required this.plant,
    this.room,
    this.window,
    this.draftWindow,
    this.nearbyHeatSources = const [],
    this.roomHeatSources = const [],
    this.weather,
    this.latitude,
    required this.now,
  });

  final Plant plant;
  final Room? room;

  /// Window the plant stands by (drives its light).
  final WindowObject? window;

  /// Window the user picked as the plant's draft source (null = other/unknown).
  final WindowObject? draftWindow;

  /// Radiant sources the plant is marked "near" — local 1/d² heating.
  final List<HeatSource> nearbyHeatSources;

  /// Every heat source in the room — sets the ambient room temperature
  /// (heating cables land here; they are room-scale, never "near").
  final List<HeatSource> roomHeatSources;

  final WeatherSnapshot? weather;
  final double? latitude;
  final DateTime now;
}

/// Resolves a [LocalClimate] from real inputs and runs the water-balance.
///
/// Data-source policy (strict, per project requirement):
///   1. sensors the user owns — light meter (lux), thermometer (room °C)
///   2. manual inputs — room/window/heat-source configuration
///   3. weather API — MET forecast for the home location
///   4. statistics — generic indoor assumptions; only if 1–3 give nothing,
///      and flagged so the UI can nudge the user to supply better data.
class WaterModel {
  static EtEstimate estimate(EtInputs i) {
    final climate = _resolveClimate(i);
    final etRef = PenmanMonteith.referenceEt(climate);
    final kc = _cropCoefficient(i.plant);
    final etPlant = kc * etRef;

    final potDepthMm = _potDepthMm(i.plant);
    // Potting mix holds ~30 % plant-available water by volume; we water when
    // half of it (allowable depletion p ≈ 0.5) over the root zone is gone.
    const availableWaterFraction = 0.30;
    const allowableDepletion = 0.5;
    final rootDepthMm = 0.8 * potDepthMm;
    final raw = availableWaterFraction * allowableDepletion * rootDepthMm;

    // Days until the readily-available reserve is depleted at the current loss
    // rate. A tiny floor on ET avoids divide-by-zero in a cold dark room.
    final interval = (raw / math.max(etPlant, 0.05)).round().clamp(1, 90);

    final breakdown = <MapEntry<String, String>>[
      MapEntry('Lokal temperatur',
          '${climate.airTempC.value.toStringAsFixed(1)} °C (${climate.airTempC.source.label})'),
      MapEntry('Luftfuktighet',
          '${climate.relHumidityPct.value.toStringAsFixed(0)} % (${climate.relHumidityPct.source.label})'),
      MapEntry('Damptrykkunderskudd (VPD)',
          '${climate.vpd.toStringAsFixed(2)} kPa'),
      MapEntry('Luftbevegelse',
          '${climate.windSpeedMs.value.toStringAsFixed(2)} m/s (${climate.windSpeedMs.source.label})'),
      MapEntry('Lysinnstråling',
          '${climate.solarWm2.value.toStringAsFixed(0)} W/m² · ${climate.daylightHours.value.toStringAsFixed(1)} t (${climate.solarWm2.source.label})'),
      MapEntry('Netto stråling', '${climate.netRadiationMJ.toStringAsFixed(1)} MJ/m²/dag'),
      MapEntry('Referanse-ET₀', '${etRef.toStringAsFixed(2)} mm/dag'),
      MapEntry('Plantekoeffisient Kc', kc.toStringAsFixed(2)),
      MapEntry('Plantens vanntap', '${etPlant.toStringAsFixed(2)} mm/dag'),
      MapEntry('Tilgjengelig vann i potte', '${raw.toStringAsFixed(1)} mm'),
    ];

    return EtEstimate(
      climate: climate,
      etRefMmDay: etRef,
      kc: kc,
      etPlantMmDay: etPlant,
      readilyAvailableMm: raw,
      intervalDays: interval,
      breakdown: breakdown,
    );
  }

  // ---------------------------------------------------------------------------
  // Climate resolution
  // ---------------------------------------------------------------------------

  static LocalClimate _resolveClimate(EtInputs i) {
    final temp = _resolveTemp(i);
    return LocalClimate(
      airTempC: temp,
      relHumidityPct: _resolveHumidity(i, temp.value),
      windSpeedMs: _resolveWind(i),
      solarWm2: _resolveSolar(i),
      daylightHours: _resolveDaylight(i),
    );
  }

  /// Assumed pot-to-heater distance [m] when the plant is only flagged "near"
  /// a heat source (no exact distance is collected yet).
  static const _nearDistanceM = 1.0;

  /// Air temperature at the plant: thermometer → heat-balance estimate from
  /// the room's heaters → weather-driven → 21 °C fallback. Then local bumps:
  /// radiant near-field from picked sources, and floor heating under the pot.
  static Measured _resolveTemp(EtInputs i) {
    final roomTemp = i.room?.temperatureC;
    var t = roomTemp != null
        ? Measured(roomTemp, ClimateSource.sensor, note: 'termometer')
        : _estimateRoomTemp(i);

    // Near-field: sum of each picked device's radiant irradiance at the
    // assumed distance, inverse-square decay (HeatSource.localRiseC).
    if (i.plant.nearHeatSource && i.nearbyHeatSources.isNotEmpty) {
      final rise = i.nearbyHeatSources
          .fold(0.0, (s, h) => s + h.localRiseC(_nearDistanceM))
          .clamp(0.0, 8.0);
      t = t.copy(t.value + rise,
          source: t.source.rank < ClimateSource.manual.rank
              ? t.source
              : ClimateSource.manual,
          note:
              '+${rise.toStringAsFixed(1)}°C strålevarme (~${_nearDistanceM.toStringAsFixed(0)} m)');
    } else if (i.plant.nearHeatSource) {
      // Flagged near heat but no source picked — modest generic bump.
      t = t.copy(t.value + 2.0, note: '+2°C nær varmekilde');
    }

    // A pot standing on a floor with heating cables is warmed from below —
    // the soil dries from the bottom regardless of the air temperature.
    if (i.plant.onFloor &&
        i.roomHeatSources.any((h) => h.type == HeatType.heatingCable)) {
      t = t.copy(t.value + 3.0,
          source: t.source.rank < ClimateSource.manual.rank
              ? t.source
              : ClimateSource.manual,
          note: '+3°C gulvvarme under potten');
    }
    return t;
  }

  /// Steady-state room temperature from a heat balance:
  ///   T_room = T_out + ΣQ/UA, capped at the heaters' thermostat/dial target.
  /// UA (room heat-loss coefficient, W/K) is estimated from floor area and the
  /// number of exterior walls: ventilation ≈ 0.28·A, each exterior wall adds
  /// envelope loss ≈ 0.72·√A + 1.8 (wall U≈0.3 + a window share), plus a small
  /// infiltration constant.
  static Measured _estimateRoomTemp(EtInputs i) {
    final w = i.weather;
    // Ambient temperature is set by every heater in the room, not just the
    // ones the plant happens to stand near (heating cables included).
    final heaters = i.roomHeatSources;

    if (heaters.isNotEmpty) {
      final target = heaters.map((h) => h.targetC).reduce(math.max);
      if (w != null) {
        final area = i.room?.sizeSqm ?? 15.0;
        final nExt = i.room?.exteriorWalls.length ?? 1;
        final ua = 0.28 * area + nExt * (0.72 * math.sqrt(area) + 1.8) + 2.0;
        final q = heaters.fold(0.0, (s, h) => s + h.outputW);
        final steady = w.temperatureC + q / ua;
        final t = math.min(steady, target).clamp(5.0, 30.0);
        final limited = steady < target;
        return Measured(t, ClimateSource.manual,
            note: limited
                ? 'varmekilde (${q.round()} W) rekker ikke målet'
                : 'varmebalanse (${q.round()} W, mål ${target.round()}°C)');
      }
      // No weather: assume the device holds its target.
      return Measured(target.clamp(5.0, 30.0), ClimateSource.manual,
          note: 'termostatmål');
    }

    if (w != null && w.temperatureC > 21) {
      // Warm outside: an un-airconditioned home drifts up with the outdoors,
      // lagging a few degrees behind it.
      return Measured(w.temperatureC - 3, ClimateSource.weather,
          note: 'sommer, følger utetemp');
    }
    return const Measured(21, ClimateSource.statistical,
        note: 'antatt romtemperatur');
  }

  /// Indoor relative humidity by psychrometrics: ventilation keeps indoor
  /// absolute moisture ≈ outdoor, so heating the same air lowers its RH.
  /// RH_in = e_a(outdoor) / e_s(T_indoor). No humidity sensor is assumed.
  static Measured _resolveHumidity(EtInputs i, double indoorTemp) {
    final w = i.weather;
    if (w != null) {
      final eaOut =
          LocalClimate.satVapPressure(w.temperatureC) * (w.humidityPct / 100);
      final esIn = LocalClimate.satVapPressure(indoorTemp);
      var rh = (eaOut / esIn) * 100;
      // An often-open window near the plant pulls the local air back toward
      // outdoor humidity.
      final win = i.draftWindow ?? i.window;
      if (win?.openFrequency == OpenFrequency.often) {
        rh = (rh + w.humidityPct) / 2;
      }
      return Measured(rh.clamp(15, 95), ClimateSource.weather,
          note: 'uteluft omregnet til inneklima');
    }
    return const Measured(40, ClimateSource.statistical,
        note: 'antatt innefuktighet');
  }

  /// Air movement at the pot. Indoor still air is ~0.1 m/s (natural
  /// convection). Draft comes from the window the user PICKED as the source
  /// (its opening habits × outdoor wind); fan-type heaters in the room stir
  /// the air; an unexplained draft flag falls back to a generic breeze.
  static Measured _resolveWind(EtInputs i) {
    var v = 0.1;
    var source = ClimateSource.manual; // still-air baseline is a known constant
    var note = 'stillestående inneluft';

    final weather = i.weather;
    if (i.plant.nearDraft) {
      final dw = i.draftWindow;
      if (dw != null && dw.openFrequency != OpenFrequency.never) {
        final openFactor =
            dw.openFrequency == OpenFrequency.often ? 0.15 : 0.05;
        final outdoorMs = (weather?.windKmh ?? 12) / 3.6;
        final draft = outdoorMs * openFactor;
        if (draft > v) {
          v = draft;
          source =
              weather != null ? ClimateSource.weather : ClimateSource.manual;
          note = 'trekk fra ${dw.name}';
        }
      } else if (dw == null) {
        // Draft from an unspecified source (door, vent, ...).
        v = 0.3;
        note = 'trekk (ukjent kilde)';
      }
    }
    // Convective heaters (fan heater, heat pump) anywhere in the room move
    // air even with the windows shut.
    for (final h in i.roomHeatSources) {
      if (h.type == HeatType.fanHeater || h.type == HeatType.heatPump) {
        final add = 0.2 * h.effectiveIntensity;
        if (v < 0.1 + add) {
          v = 0.1 + add;
          note = 'luftstrøm fra ${h.type.label.toLowerCase()}';
        }
      }
    }
    return Measured(v.clamp(0.1, 1.5), source, note: note);
  }

  /// Mean shortwave irradiance reaching the plant [W/m²]. Light meter → yes;
  /// otherwise the resolved light band (window facing/size or stated word),
  /// dimmed by cloud/rain from the weather forecast.
  static Measured _resolveSolar(EtInputs i) {
    // 1) Sensor: a lux reading on the plant, its window, or its room.
    final lux = i.plant.lightMeasurementLux ??
        i.window?.lightMeasurementLux ??
        i.room?.lightMeasurementLux;
    if (lux != null) {
      // Daylight luminous efficacy ≈ 110 lm/W → W/m² ≈ lux / 110.
      return Measured((lux / 110).clamp(0, 1000), ClimateSource.sensor,
          note: 'lysmåler ($lux lux)');
    }

    // 2) Manual/derived light band.
    final band = _resolveLightBand(i);
    var wm2 = switch (band) {
      LightIntensity.direct => 250.0,
      LightIntensity.indirect => 60.0,
      LightIntensity.shaded => 15.0,
    };

    // 3) Cloud/rain dimming from weather (precipitation is a wet-sky proxy).
    var source = ClimateSource.manual;
    if (i.weather != null) {
      final rain = i.weather!.precip24hMm;
      final cloudDim = rain > 2
          ? 0.5
          : rain > 0
              ? 0.75
              : 1.0;
      wm2 *= cloudDim;
      source = ClimateSource.manual; // band is manual; weather only trims it
    }
    // If we had no window/room/plant light info at all, the band was a pure
    // default → statistical.
    final hasLightInfo = i.plant.lightIntensity != null ||
        i.window != null ||
        (i.room?.lightIntensity != null) ||
        (i.room?.exteriorWalls.isNotEmpty ?? false);
    if (!hasLightInfo) source = ClimateSource.statistical;

    return Measured(wm2, source, note: 'lysnivå: ${band.label}');
  }

  static LightIntensity _resolveLightBand(EtInputs i) {
    if (i.plant.statedLight != null) return i.plant.statedLight!;
    if (i.window != null) return i.window!.resolvedIntensity;
    if (i.room != null) return i.room!.resolvedIntensity;
    return LightIntensity.indirect;
  }

  /// Daylight hours from latitude + day-of-year (astronomical), else a seasonal
  /// approximation. Uses the context clock, never a wall-clock call.
  static Measured _resolveDaylight(EtInputs i) {
    final lat = i.latitude;
    if (lat != null) {
      final j = _dayOfYear(i.now);
      final phi = lat * math.pi / 180;
      final decl = 0.409 * math.sin(2 * math.pi / 365 * j - 1.39);
      final x = (-math.tan(phi) * math.tan(decl)).clamp(-1.0, 1.0);
      final omega = math.acos(x);
      final hours = (24 / math.pi) * omega;
      return Measured(hours.clamp(0, 24), ClimateSource.weather,
          note: 'beregnet fra breddegrad');
    }
    final season = WeatherApi.seasonFor(i.now);
    final h = switch (season) {
      Season.winter => 6.0,
      Season.spring || Season.autumn => 12.0,
      Season.summer => 16.0,
    };
    return Measured(h, ClimateSource.statistical, note: 'antatt for årstiden');
  }

  static int _dayOfYear(DateTime d) =>
      d.difference(DateTime(d.year, 1, 1)).inDays + 1;

  // ---------------------------------------------------------------------------
  // Plant crop coefficient & pot reservoir
  // ---------------------------------------------------------------------------

  /// Crop coefficient Kc — scales reference ET to this specific plant from its
  /// thirst (species watering need), leaf area (relative size) and maturity.
  static double _cropCoefficient(Plant p) {
    final base = switch (p.species?.wateringLevel) {
      Level.high => 0.9,
      Level.low => 0.5,
      Level.medium => 0.7,
      null => 0.7,
    };
    final sizeMult = switch (p.relativeSize) {
      RelativeSize.tiny => 0.6,
      RelativeSize.small => 0.8,
      RelativeSize.large => 1.2,
      RelativeSize.huge => 1.35,
      RelativeSize.medium || null => 1.0,
    };
    final maturityMult = switch (p.maturity) {
      MaturityStage.seedling => 0.7,
      MaturityStage.young => 0.85,
      MaturityStage.juvenile => 0.95,
      MaturityStage.mature || MaturityStage.old || null => 1.0,
    };
    return (base * sizeMult * maturityMult).clamp(0.3, 1.15);
  }

  /// Effective soil depth of the pot [mm], from the pot diameter we can infer.
  /// Relative size gives a diameter directly; otherwise fall back to plant
  /// height (pot ≈ ⅓ of height). Depth ≈ diameter for a typical pot.
  static double _potDepthMm(Plant p) {
    final diameterCm = switch (p.relativeSize) {
      RelativeSize.tiny => 8.0,
      RelativeSize.small => 12.0,
      RelativeSize.medium => 16.0,
      RelativeSize.large => 22.0,
      RelativeSize.huge => 30.0,
      null => (p.heightCm != null)
          ? (p.heightCm! * 0.33).clamp(8.0, 35.0)
          : 16.0,
    };
    return diameterCm * 10; // cm → mm, depth ≈ diameter
  }
}
