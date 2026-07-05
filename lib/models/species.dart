import 'dart:convert';

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
    this.careTips = const [],
    this.standardHeightCm,
    this.source,
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

  /// section -> description (watering, sunlight, pruning). Used by Perenual-style
  /// data; empty for Mestergrønn (which uses [careTips] instead).
  final Map<String, String> careGuide;

  /// Short care hints (e.g. "sol/skygge", "tørkes lett mellom vanning") taken
  /// from the Mestergrønn product care-tip icons.
  final List<String> careTips;

  /// The product's standard/default height in cm, if the source states one.
  /// Used as the plant's height unless the user enters their own.
  final double? standardHeightCm;

  /// Which catalogue this came from ('mestergronn' | 'plantasjen'). Drives
  /// whether a search hit still needs a second "enrich" fetch (Mestergrønn) or
  /// is already complete (Plantasjen returns everything in one search call).
  final String? source;

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
        'careTips': careTips,
        'standardHeightCm': standardHeightCm,
        'source': source,
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
        careTips: _strList(j['careTips']),
        standardHeightCm: asDouble(j['standardHeightCm']),
        source: asString(j['source']),
      );

  /// Lightweight species from a search-suggestion (id + name + thumbnail only).
  factory Species.fromSuggestion({
    required int id,
    required String name,
    String? imageUrl,
  }) =>
      Species(
        id: id,
        commonName: name.isEmpty ? 'Ukjent plante' : name,
        imageUrl: _normUrl(imageUrl),
        indoor: true,
      );

  /// Build a species from a Mestergrønn `Product-Variation` product object.
  factory Species.fromMestergronn(Map<String, dynamic> p) {
    // Thumbnail: prefer the large image; absolute URL if present.
    String? img;
    final images = p['images'];
    if (images is Map) {
      final large = images['large'] ?? images['medium'] ?? images['small'];
      if (large is List && large.isNotEmpty && large.first is Map) {
        final m = large.first as Map;
        img = asString(m['absURL']) ?? asString(m['url']);
      }
    }

    // Care tips live in the <title> of each care-tip SVG icon.
    final tips = <String>[];
    final titleRe = RegExp(r'<title>(.*?)</title>', dotAll: true);
    for (final k in const ['careTips1', 'careTips2', 'careTips3', 'careTips4']) {
      final svg = asString(p[k]);
      if (svg == null) continue;
      final m = titleRe.firstMatch(svg);
      if (m == null) continue;
      final t = m.group(1)!.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
      if (t.isNotEmpty) tips.add(t);
    }

    // Standard height from productDimensions, e.g. "Høyde 60 cm".
    double? height;
    final dims = p['productDimensions'];
    if (dims is List) {
      for (final d in dims) {
        if (d is! Map) continue;
        final text = asString(d['text']) ?? '';
        final icon = asString(d['iconClass']) ?? '';
        if (icon.contains('height') || text.toLowerCase().contains('høyde')) {
          final n = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(text);
          if (n != null) {
            height = double.tryParse(n.group(1)!.replaceAll(',', '.'));
            break;
          }
        }
      }
    }

    return Species(
      id: asInt(p['id']) ?? 0,
      commonName: asString(p['productName']) ?? 'Ukjent plante',
      description: _stripHtml(asString(p['shortDescription'])),
      imageUrl: _normUrl(img),
      careTips: tips,
      standardHeightCm: height,
      indoor: true,
    );
  }

  /// Build a species from a Plantasjen Meilisearch product hit. Unlike
  /// Mestergrønn, one search call already carries the full profile (scientific
  /// name, light, watering, toxicity, height), so no enrich step is needed.
  factory Species.fromPlantasjen(Map<String, dynamic> h) {
    final f = (h['filterable'] is Map)
        ? Map<String, dynamic>.from(h['filterable'] as Map)
        : const <String, dynamic>{};

    // Norwegian light words → the English sunlight words the getters expect.
    final light = _strList(f['plant_light_level']).map(_fixEnc).toList();
    final sunlight = <String>[
      for (final l in light)
        switch (l.toLowerCase()) {
          'sol' => 'full sun',
          'halvskygge' => 'part shade',
          'skygge' => 'full shade',
          _ => l,
        },
    ];

    // Norwegian watering word → Perenual watering word.
    final waterNo = _strList(f['plant_watering_needs']).map(_fixEnc).join(' ');
    final wateringWord = switch (waterNo.toLowerCase()) {
      String s when s.contains('lite') || s.contains('lav') => 'minimum',
      String s when s.contains('mye') || s.contains('rikelig') => 'frequent',
      String s when s.contains('moderat') => 'average',
      _ => null,
    };

    final toxic = _strList(f['plant_properties'])
        .map(_fixEnc)
        .any((p) => p.toLowerCase().contains('giftig'));

    // Human-readable care hints for the detail screen.
    final tips = <String>[
      if (light.isNotEmpty) 'Lys: ${light.join('/')}',
      if (waterNo.isNotEmpty) 'Vanning: ${_fixEnc(waterNo)}',
      for (final ff in _strList(f['plant_fertilization_types']).map(_fixEnc))
        'Gjødsling: $ff',
    ];

    return Species(
      // SKU is numeric and stable; use it as the id (ObjectId is hex, not int).
      id: asInt(h['sku']) ?? 0,
      commonName: _fixEnc(asString(h['title']) ?? 'Ukjent plante'),
      scientificName: [
        if (asString(f['scientific_name']) != null)
          _fixEnc(asString(f['scientific_name'])!),
      ],
      description: _fixEncN(asString(h['description'])),
      imageUrl: asString(h['image_url']),
      sunlight: sunlight,
      wateringWord: wateringWord,
      standardHeightCm: asDouble(f['height']),
      poisonousToPets: toxic ? true : null,
      poisonousToHumans: toxic ? true : null,
      careTips: tips,
      indoor: true,
      source: 'plantasjen',
    );
  }

  /// Plantasjen's Meili index stores text as double-encoded UTF-8 (e.g. "Grønn"
  /// arrives as "GrÃ¸nn"). Re-interpret the Latin-1 bytes as UTF-8 to repair it;
  /// fall back to the original if the string isn't actually mis-encoded.
  static String _fixEnc(String s) {
    if (s.isEmpty) return s;
    try {
      return utf8.decode(latin1.encode(s));
    } catch (_) {
      return s; // contains real >0xFF chars — already fine.
    }
  }

  static String? _fixEncN(String? s) => s == null ? null : _fixEnc(s);

  /// Mestergrønn image paths contain literal backslashes; normalise to slashes
  /// so Flutter can parse them.
  static String? _normUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.replaceAll(r'\', '/');
  }

  /// Strip HTML tags/entities from a rich-text blurb into plain paragraphs.
  static String? _stripHtml(String? html) {
    if (html == null || html.isEmpty) return null;
    var s = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\n{3,}'), '\n\n');
    s = s.trim();
    return s.isEmpty ? null : s;
  }

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
