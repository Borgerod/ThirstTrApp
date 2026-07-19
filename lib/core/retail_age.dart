/// Estimated age of a houseplant at retail purchase ("retail age").
///
/// Growers sell plants young: roughly 80–90% of retail houseplants are
/// juvenile or semi-mature, so a plant's age is never 0 at acquisition.
/// A plant's real age = (user-provided or estimated) retail age + time owned.
library;

import 'plant_enums.dart';

class RetailAge {
  RetailAge._();

  /// Typical years from propagation to retail sale, by size class.
  /// small pot (6–9 cm) 3–9 mo · medium 1–3 yr · large floor 3–8 yr ·
  /// specimen 8–20+ yr. Midpoints, biased low — retail skews juvenile.
  static const _bySize = {
    RelativeSize.tiny: 0.3,
    RelativeSize.small: 0.5,
    RelativeSize.medium: 2.0,
    RelativeSize.large: 5.5,
    RelativeSize.huge: 14.0,
  };

  /// Species-specific retail age at MEDIUM size, where known. Keys are
  /// lower-case substrings matched against any of the plant's names
  /// (common / scientific / Norwegian trade names).
  static const _speciesMediumYears = <String, double>{
    'monstera': 1.5, // medium 1–2 yr
    'ficus elastica': 2.0, // 1–3 yr
    'gummifikus': 2.0,
    'pothos': 0.7, // 4–12 mo
    'epipremnum': 0.7,
    'gullranke': 0.7,
    'sansevieria': 2.0, // 1–3 yr
    'dracaena trifasciata': 2.0,
    'svigermors tunge': 2.0,
    'peace lily': 1.5, // 1–2 yr, often already flowering
    'spathiphyllum': 1.5,
    'fredslilje': 1.5,
  };

  /// Estimated age in years at acquisition.
  ///
  /// [names] = every name the plant goes by (nickname, common, scientific);
  /// [size] = relative size class, defaults to medium. A species override is
  /// that species' MEDIUM retail age, scaled to other size classes by the
  /// generic ratio — fast growers reach every size class younger.
  static double estimateYears({
    Iterable<String> names = const [],
    RelativeSize? size,
  }) {
    final sizeYears = _bySize[size ?? RelativeSize.medium]!;
    final haystack = names.map((n) => n.toLowerCase()).join(' | ');
    for (final e in _speciesMediumYears.entries) {
      if (haystack.contains(e.key)) {
        return e.value * (sizeYears / _bySize[RelativeSize.medium]!);
      }
    }
    return sizeYears;
  }
}
