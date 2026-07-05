import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/species.dart';

/// Thrown when the Plantasjen search backend fails.
class PlantasjenException implements Exception {
  PlantasjenException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client for Plantasjen's product search — used as a fallback when Mestergrønn
/// has no match, and (unlike Mestergrønn) it can resolve EAN barcodes.
///
/// Plantasjen's storefront is a Next.js app whose search is a public, read-only
/// **Meilisearch** instance. The host, search-only API key and index name are
/// all shipped in the site's JS bundle (no secret) and the endpoint returns
/// `Access-Control-Allow-Origin: *`, so the browser can call it directly with
/// no CORS proxy. If Plantasjen rotates the key or renames the index, refresh
/// these from the site's `/_next/static/chunks/*.js` bundle.
class PlantasjenApi {
  PlantasjenApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _host = 'https://ms-a6530e77c471-12443.lon.meilisearch.io';
  static const _index = 'products_nb-NO';
  static const _searchKey =
      'a2159774cf867351b1195f0a05a4fb9f4693c781bd3e89a3ff5e856637710594';

  // Only the fields the Species mapper needs, to keep responses small.
  static const _attrs = [
    'sku',
    'title',
    'description',
    'image_url',
    'filterable',
  ];

  Future<List<dynamic>> _search(Map<String, dynamic> body) async {
    final http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$_host/indexes/$_index/search'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_searchKey',
        },
        body: jsonEncode({'attributesToRetrieve': _attrs, ...body}),
      );
    } catch (e) {
      throw PlantasjenException('Plantasjen søk feilet: $e');
    }
    if (res.statusCode != 200) {
      throw PlantasjenException('Plantasjen søk feilet (${res.statusCode}).');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (json['hits'] as List?) ?? const [];
  }

  /// Search products by name.
  Future<List<Species>> speciesList({String? query, int page = 1}) async {
    final q = (query ?? '').trim();
    if (q.isEmpty) return const [];
    final hits = await _search({'q': q, 'hitsPerPage': 20});
    return hits
        .whereType<Map>()
        .map((h) => Species.fromPlantasjen(Map<String, dynamic>.from(h)))
        .toList();
  }

  /// Resolve a scanned EAN barcode to a product, or null if unknown.
  Future<Species?> speciesByEan(String ean) async {
    final code = ean.trim();
    if (code.isEmpty) return null;
    // `ean` is a filterable numeric array; an exact filter beats a text query.
    final hits = await _search({
      'q': '',
      'filter': 'ean = $code',
      'hitsPerPage': 1,
    });
    if (hits.isEmpty) return null;
    return Species.fromPlantasjen(Map<String, dynamic>.from(hits.first as Map));
  }

  /// Plantasjen search hits are already complete — kept for API parity with the
  /// Mestergrønn client so the catalogue facade can call it uniformly.
  Future<Species> enrichedSpecies(Species s) async => s;
}
