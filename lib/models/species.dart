import '../core/enums.dart';
import '../core/plant_enums.dart';
import '../core/json.dart';

/// A plant species as returned by the Perenual API (list + details merged).
/// Stored as a snapshot on each [Plant] so the app works offline and the user
/// keeps data even if their API quota runs out.
class Species {
  Species({
    required this.id,
    required this.commonName,
    this.scientificName = const [],
    this.otherNames = const [],
    this.cycle,
    this.wateringWord,
    this.wateringBenchmarkValue,
    this.wateringBenchmarkUnit,
    this.sunlight = const [],
    this.imageUrl,
    this.careLevel,
    this.description,
    this.poisonousToPets,
    this.poisonousToHumans,
    this.indoor,
    this.careGuide = const {},
  });

  final int id;
  final String commonName;
  final List<String> scientificName;
  final List<String> otherNames;
  final String? cycle;

  /// Perenual "watering" word: Frequent / Average / Minimum / None.
  final String? wateringWord;

  /// Optional benchmark like "7" days from the care-guide.
  final double? wateringBenchmarkValue;
  final String? wateringBenchmarkUnit;

  final List<String> sunlight;
  final String? imageUrl;
  final String? careLevel;
  final String? description;
  final bool? poisonousToPets;
  final bool? poisonousToHumans;
  final bool? indoor;

  /// section -> description (watering, sunlight, pruning).
  final Map<String, String> careGuide;

  /// Baseline watering interval in days derived from the watering word.
  int get baseWateringDays {
    if (wateringBenchmarkValue != null &&
        (wateringBenchmarkUnit ?? '').toLowerCase().contains('day')) {
      return wateringBenchmarkValue!.round().clamp(1, 60);
    }
    return switch ((wateringWord ?? '').toLowerCase()) {
      'frequent' => 3,
      'average' => 7,
      'minimum' => 12,
      'none' => 21,
      _ => 7,
    };
  }

  // --- Derived hints for the 4 mini-care circles ---

  /// Light exposure from Perenual sunlight words.
  LightIntensity get lightExposure {
    final s = sunlight.join(' ').toLowerCase();
    if (s.contains('full sun') || s.contains('full_sun')) {
      return LightIntensity.direct;
    }
    if (s.contains('full shade') || s.contains('deep shade')) {
      return LightIntensity.shaded;
    }
    return LightIntensity.indirect;
  }

  /// Watering need as a low/med/high level.
  Level get wateringLevel => switch ((wateringWord ?? '').toLowerCase()) {
        'frequent' => Level.high,
        'average' => Level.medium,
        'minimum' || 'none' => Level.low,
        _ => Level.medium,
      };

  /// Rough fertilizing need; Perenual gives no direct value, so proxy off
  /// growth/watering vigour.
  Level get fertilizingLevel => switch (wateringLevel) {
        Level.high => Level.high,
        Level.low => Level.low,
        Level.medium => Level.medium,
      };

  /// A single notable care characteristic for the 4th circle.
  CareTag get careTag {
    final level = (careLevel ?? '').toLowerCase();
    final guide = careGuide.values.join(' ').toLowerCase();
    if (level.contains('difficult') || level.contains('hard')) {
      return CareTag.hardCare;
    }
    if (guide.contains('humid') || guide.contains('mist')) {
      return CareTag.humidityLover;
    }
    if (wateringLevel == Level.high) return CareTag.lovesSoaking;
    if (wateringLevel == Level.low) return CareTag.droughtTolerant;
    if (level.contains('easy')) return CareTag.easyCare;
    return CareTag.easyCare;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'commonName': commonName,
        'scientificName': scientificName,
        'otherNames': otherNames,
        'cycle': cycle,
        'wateringWord': wateringWord,
        'wateringBenchmarkValue': wateringBenchmarkValue,
        'wateringBenchmarkUnit': wateringBenchmarkUnit,
        'sunlight': sunlight,
        'imageUrl': imageUrl,
        'careLevel': careLevel,
        'description': description,
        'poisonousToPets': poisonousToPets,
        'poisonousToHumans': poisonousToHumans,
        'indoor': indoor,
        'careGuide': careGuide,
      };

  factory Species.fromJson(Map<String, dynamic> j) => Species(
        id: asInt(j['id']) ?? 0,
        commonName: asString(j['commonName']) ??
            asString(j['common_name']) ??
            'Ukjent art',
        scientificName: _strList(j['scientificName'] ?? j['scientific_name']),
        otherNames: _strList(j['otherNames'] ?? j['other_name']),
        cycle: asString(j['cycle']),
        wateringWord: asString(j['wateringWord'] ?? j['watering']),
        wateringBenchmarkValue: asDouble(j['wateringBenchmarkValue']),
        wateringBenchmarkUnit: asString(j['wateringBenchmarkUnit']),
        sunlight: _strList(j['sunlight']),
        imageUrl: asString(j['imageUrl']) ?? _imageFrom(j['default_image']),
        careLevel: asString(j['careLevel'] ?? j['care_level']),
        description: asString(j['description']),
        poisonousToPets: _toBoolN(j['poisonousToPets'] ?? j['poisonous_to_pets']),
        poisonousToHumans:
            _toBoolN(j['poisonousToHumans'] ?? j['poisonous_to_humans']),
        indoor: _toBoolN(j['indoor']),
        careGuide: (j['careGuide'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ) ??
            const {},
      );

  static List<String> _strList(Object? v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }

  static String? _imageFrom(Object? v) {
    if (v is Map) {
      final url =
          asString(v['regular_url'] ?? v['original_url'] ?? v['thumbnail']);
      // Perenual free tier returns an "upgrade_access.jpg" placeholder for
      // every image. Treat it as no image so the UI shows a clean fallback.
      if (url == null || url.contains('upgrade_access')) return null;
      return url;
    }
    return null;
  }

  static bool? _toBoolN(Object? v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return null;
  }
}
