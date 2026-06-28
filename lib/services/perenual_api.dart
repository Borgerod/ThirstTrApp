import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/json.dart';
import '../models/species.dart';

/// Thrown when the API key is missing or rejected.
class PerenualAuthException implements Exception {
  PerenualAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client for the Perenual Plant Open API.
/// Docs: https://perenual.com/docs/plant-open-api
class PerenualApi {
  PerenualApi(this.apiKey, {http.Client? client})
      : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _base = 'https://perenual.com/api';

  bool get hasKey => apiKey.trim().isNotEmpty;

  Uri _u(String path, [Map<String, String> q = const {}]) =>
      Uri.parse('$_base$path').replace(queryParameters: {
        'key': apiKey,
        ...q,
      });

  Future<Map<String, dynamic>> _getJson(Uri url) async {
    if (!hasKey) {
      throw PerenualAuthException('Mangler Perenual API-nøkkel. Legg den inn i Innstillinger.');
    }
    final res = await _client.get(url);
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw PerenualAuthException('API-nøkkel avvist (${res.statusCode}).');
    }
    if (res.statusCode != 200) {
      throw Exception('Perenual-feil ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// GET /v2/species-list — paged + searchable species list.
  Future<List<Species>> speciesList({String? query, int page = 1}) async {
    final json = await _getJson(_u('/v2/species-list', {
      'page': '$page',
      if (query != null && query.isNotEmpty) 'q': query,
    }));
    final data = asMapList(json['data']);
    return data.map(Species.fromJson).toList();
  }

  /// GET /v2/species/details/{id} — full details for one species.
  Future<Species> speciesDetails(int id) async {
    final json = await _getJson(_u('/v2/species/details/$id'));
    return Species.fromJson(json);
  }

  /// GET /species-care-guide-list — care sections (watering/sunlight/pruning).
  /// Returns section -> description merged into a Species snapshot if provided.
  Future<Map<String, String>> careGuide(int speciesId) async {
    final json =
        await _getJson(_u('/species-care-guide-list', {'species_id': '$speciesId'}));
    final guides = asMapList(json['data']);
    final out = <String, String>{};
    for (final g in guides) {
      for (final section in asMapList(g['section'])) {
        final type = asString(section['type']) ?? 'info';
        final desc = asString(section['description']) ?? '';
        if (desc.isNotEmpty) out[type] = desc;
      }
    }
    return out;
  }

  /// GET /pest-disease-list — common pests/diseases (optionally per species).
  Future<List<Map<String, dynamic>>> pestDiseaseList({int? speciesId}) async {
    final json = await _getJson(_u('/pest-disease-list', {
      if (speciesId != null) 'species_id': '$speciesId',
    }));
    return asMapList(json['data']);
  }

  /// GET /hardiness-map — returns the embeddable hardiness-zone map URL for a
  /// species so the UI can show it in a WebView/link.
  Future<String?> hardinessMapUrl(int speciesId) async {
    final json = await _getJson(_u('/hardiness-map', {'species_id': '$speciesId'}));
    // API returns an HTML/iframe blob; surface any URL we can find.
    return asString(json['url']) ?? asString(json['data']);
  }

  /// Fetch full details + care guide and return a merged snapshot.
  Future<Species> enrichedSpecies(int id) async {
    final details = await speciesDetails(id);
    try {
      final guide = await careGuide(id);
      return Species.fromJson({...details.toJson(), 'careGuide': guide});
    } catch (_) {
      return details; // care guide is best-effort
    }
  }
}
