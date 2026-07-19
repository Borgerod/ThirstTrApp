import '../models/species.dart';
import 'mestergronn_api.dart';
import 'plantasjen_api.dart';

/// Unifies the plant catalogues behind one interface. Mestergrønn is primary;
/// Plantasjen is the fallback when Mestergrønn has no match, and the only
/// source that can resolve an EAN barcode.
class PlantCatalog {
  PlantCatalog(this._mg, this._pl);

  final MestergronnApi _mg;
  final PlantasjenApi _pl;

  /// Search by name: Mestergrønn first, Plantasjen if it comes back empty (or
  /// unreachable). Only the fallback's error is allowed to surface.
  Future<List<Species>> search(String query) async {
    try {
      final mg = await _mg.speciesList(query: query);
      if (mg.isNotEmpty) return mg;
    } catch (_) {/* proxy down or endpoint changed — try the fallback */}
    return _pl.speciesList(query: query);
  }

  /// Fill in the full profile for a chosen search hit. Plantasjen hits are
  /// already complete; Mestergrønn needs a second product fetch — and since
  /// Mestergrønn never states toxicity (among other facts), Plantasjen fills
  /// whatever is still missing afterwards.
  Future<Species> enrich(Species s) async {
    // Plantasjen hits are complete per-product, but a single product can miss
    // facts its siblings carry (e.g. one Monstera pot size lacks the 'Giftig'
    // tag while the others have it) — so both sources go through the fill.
    if (s.source == 'plantasjen') return fillMissingFacts(s);
    final full = await _mg.enrichedSpecies(s.id);
    return fillMissingFacts(full);
  }

  /// Cross-catalogue fallback: look the plant up by name in Plantasjen and
  /// copy over facts the current snapshot lacks (toxicity, light, watering).
  /// Facts are aggregated across ALL matching products — the same plant is
  /// listed in several sizes and not every listing is fully tagged.
  /// Never throws; returns the input unchanged when no trustworthy match.
  Future<Species> fillMissingFacts(Species s) async {
    if (!s.hasMissingFacts) return s;
    try {
      final hits = await _pl.speciesList(query: s.commonName);
      var out = s;
      for (final h in _nameMatches(s, hits)) {
        out = out.mergeMissingFrom(h);
        if (!out.hasMissingFacts) break;
      }
      return out;
    } catch (_) {/* fallback only — never let it break the primary flow */}
    return s;
  }

  /// The hits that plausibly are the same plant. Scientific-name matches are
  /// trusted and returned alone when any exist; otherwise fall back to hits
  /// sharing a significant word of the common name. Empty rather than
  /// merging facts from the wrong plant.
  static List<Species> _nameMatches(Species s, List<Species> hits) {
    final sci = s.scientificName.map((e) => e.toLowerCase()).toSet();
    final tokens = s.commonName
        .toLowerCase()
        .split(RegExp(r'[^a-zæøåäöü]+'))
        .where((w) => w.length > 2)
        .toSet();
    final sciHits = <Species>[];
    final wordHits = <Species>[];
    for (final h in hits) {
      if (sci.isNotEmpty &&
          h.scientificName.any((n) => sci.contains(n.toLowerCase()))) {
        sciHits.add(h);
      } else if (tokens.any(h.commonName.toLowerCase().contains)) {
        wordHits.add(h);
      }
    }
    return sciHits.isNotEmpty ? sciHits : wordHits;
  }

  /// Resolve a scanned EAN. Mestergrønn has no EAN mapping, so this is
  /// Plantasjen-only; returns null when the code is unknown or lookup fails.
  Future<Species?> byEan(String code) async {
    try {
      final s = await _pl.speciesByEan(code);
      return s == null ? null : await fillMissingFacts(s);
    } catch (_) {
      return null;
    }
  }
}
