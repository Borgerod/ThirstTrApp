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
  /// already complete; Mestergrønn needs a second product fetch.
  Future<Species> enrich(Species s) {
    if (s.source == 'plantasjen') return Future.value(s);
    return _mg.enrichedSpecies(s.id);
  }

  /// Resolve a scanned EAN. Mestergrønn has no EAN mapping, so this is
  /// Plantasjen-only; returns null when the code is unknown or lookup fails.
  Future<Species?> byEan(String code) async {
    try {
      return await _pl.speciesByEan(code);
    } catch (_) {
      return null;
    }
  }
}
