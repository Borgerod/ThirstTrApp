import '../core/enums.dart';
import '../core/json.dart';
import '../core/plant_enums.dart';
import 'species.dart';

/// User-facing care interval overrides. Null = derive from species/scheduler.
class CareIntervals {
  CareIntervals({
    this.waterDays,
    this.fertilizeDays,
    this.cleanDays,
    this.mistDays,
  });

  int? waterDays;
  int? fertilizeDays;
  int? cleanDays;
  int? mistDays;

  Map<String, dynamic> toJson() => {
        'waterDays': waterDays,
        'fertilizeDays': fertilizeDays,
        'cleanDays': cleanDays,
        'mistDays': mistDays,
      };

  factory CareIntervals.fromJson(Map<String, dynamic> j) => CareIntervals(
        waterDays: asInt(j['waterDays']),
        fertilizeDays: asInt(j['fertilizeDays']),
        cleanDays: asInt(j['cleanDays']),
        mistDays: asInt(j['mistDays']),
      );
}

/// A single plant in the user's home — the central domain entity.
class Plant {
  Plant({
    required this.id,
    required this.name,
    this.species,
    this.roomId,
    this.windowId,
    this.heatSourceIds = const [],
    this.photoPaths = const [],
    this.placement,
    this.lightMeasurementLux,
    this.lightIntensity,
    this.heightCm,
    this.relativeSize,
    this.maturityBase,
    this.acquiredDate,
    this.condition,
    this.priceNok,
    this.receiptPath,
    this.hazardPets,
    this.hazardChildren,
    this.tips,
    this.generalInfo,
    this.nearDraft = false,
    this.nearHeatSource = false,
    CareIntervals? intervals,
    this.lastWatered,
    this.lastFertilized,
    this.lastCleaned,
    this.lastMisted,
    DateTime? createdAt,
  })  : intervals = intervals ?? CareIntervals(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;

  /// Snapshot of Perenual species data; copied in so the app is offline-safe.
  Species? species;

  String? roomId;
  String? windowId;
  List<String> heatSourceIds;
  List<String> photoPaths;

  RoomPlacement? placement;
  double? lightMeasurementLux;
  LightIntensity? lightIntensity;

  // Size / maturity / age block from the spec.
  double? heightCm;
  RelativeSize? relativeSize;

  /// Maturity stage at acquisition. The displayed maturity auto-advances over
  /// time from this base — see [maturity].
  MaturityStage? maturityBase;
  DateTime? acquiredDate;

  PlantCondition? condition;
  double? priceNok;
  String? receiptPath;

  bool? hazardPets;
  bool? hazardChildren;

  String? tips;
  String? generalInfo;

  bool nearDraft;
  bool nearHeatSource;

  CareIntervals intervals;

  DateTime? lastWatered;
  DateTime? lastFertilized;
  DateTime? lastCleaned;
  DateTime? lastMisted;

  final DateTime createdAt;

  /// Age since acquired, if known.
  Duration? get age =>
      acquiredDate == null ? null : DateTime.now().difference(acquiredDate!);

  /// Current maturity = base stage advanced silently by years owned.
  MaturityStage? get maturity {
    final base = maturityBase;
    if (base == null) return null;
    final years = (age?.inDays ?? 0) / 365.0;
    return base.advancedBy(years);
  }

  /// Resolved light: plant override > linked-window > stated word.
  LightIntensity? get statedLight {
    if (lightMeasurementLux != null) {
      final lux = lightMeasurementLux!;
      if (lux < 5000) return LightIntensity.shaded;
      if (lux < 20000) return LightIntensity.indirect;
      return LightIntensity.direct;
    }
    return lightIntensity;
  }

  DateTime? lastDoneFor(CareType t) => switch (t) {
        CareType.water => lastWatered,
        CareType.fertilize => lastFertilized,
        CareType.clean => lastCleaned,
        CareType.mist => lastMisted,
      };

  void markDone(CareType t, DateTime when) {
    switch (t) {
      case CareType.water:
        lastWatered = when;
      case CareType.fertilize:
        lastFertilized = when;
      case CareType.clean:
        lastCleaned = when;
      case CareType.mist:
        lastMisted = when;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'species': species?.toJson(),
        'roomId': roomId,
        'windowId': windowId,
        'heatSourceIds': heatSourceIds,
        'photoPaths': photoPaths,
        'placement': placement?.id,
        'lightMeasurementLux': lightMeasurementLux,
        'lightIntensity': lightIntensity?.id,
        'heightCm': heightCm,
        'relativeSize': relativeSize?.id,
        'maturityBase': maturityBase?.id,
        'acquiredDate': acquiredDate?.toIso8601String(),
        'condition': condition?.id,
        'priceNok': priceNok,
        'receiptPath': receiptPath,
        'hazardPets': hazardPets,
        'hazardChildren': hazardChildren,
        'tips': tips,
        'generalInfo': generalInfo,
        'nearDraft': nearDraft,
        'nearHeatSource': nearHeatSource,
        'intervals': intervals.toJson(),
        'lastWatered': lastWatered?.toIso8601String(),
        'lastFertilized': lastFertilized?.toIso8601String(),
        'lastCleaned': lastCleaned?.toIso8601String(),
        'lastMisted': lastMisted?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Plant.fromJson(Map<String, dynamic> j) => Plant(
        id: j['id'] as String,
        name: asString(j['name']) ?? 'Plante',
        species: j['species'] == null
            ? null
            : Species.fromJson(Map<String, dynamic>.from(j['species'])),
        roomId: asString(j['roomId']),
        windowId: asString(j['windowId']),
        heatSourceIds:
            (j['heatSourceIds'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        photoPaths:
            (j['photoPaths'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        placement: j['placement'] == null
            ? null
            : RoomPlacement.fromId(asString(j['placement'])),
        lightMeasurementLux: asDouble(j['lightMeasurementLux']),
        lightIntensity: j['lightIntensity'] == null
            ? null
            : LightIntensity.fromId(asString(j['lightIntensity'])),
        heightCm: asDouble(j['heightCm']),
        relativeSize: j['relativeSize'] == null
            ? null
            : RelativeSize.fromId(asString(j['relativeSize'])),
        maturityBase: (j['maturityBase'] ?? j['maturity']) == null
            ? null
            : MaturityStage.fromId(
                asString(j['maturityBase'] ?? j['maturity'])),
        acquiredDate: asDate(j['acquiredDate']),
        condition: PlantCondition.fromId(asString(j['condition'])),
        priceNok: asDouble(j['priceNok']),
        receiptPath: asString(j['receiptPath']),
        hazardPets: j['hazardPets'] == null ? null : asBool(j['hazardPets']),
        hazardChildren:
            j['hazardChildren'] == null ? null : asBool(j['hazardChildren']),
        tips: asString(j['tips']),
        generalInfo: asString(j['generalInfo']),
        nearDraft: asBool(j['nearDraft']),
        nearHeatSource: asBool(j['nearHeatSource']),
        intervals: j['intervals'] == null
            ? CareIntervals()
            : CareIntervals.fromJson(Map<String, dynamic>.from(j['intervals'])),
        lastWatered: asDate(j['lastWatered']),
        lastFertilized: asDate(j['lastFertilized']),
        lastCleaned: asDate(j['lastCleaned']),
        lastMisted: asDate(j['lastMisted']),
        createdAt: asDate(j['createdAt']),
      );
}
