import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;

import '../models/species.dart';

/// Thrown when the Mestergrønn endpoints fail.
class MestergronnException implements Exception {
  MestergronnException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client for the Mestergrønn product API.
///
/// The site runs on Salesforce Commerce Cloud (Demandware). It exposes the same
/// JSON/HTML controllers the website uses to render its pages — no API key is
/// required:
///   * `SearchServices-GetSuggestions?q=...`  → search autocomplete (HTML)
///   * `Product-Variation?pid=...&quantity=1` → full product JSON
class MestergronnApi {
  MestergronnApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base =
      'https://www.mestergronn.no/on/demandware.store/Sites-mg-Site/no_NO';

  /// Mestergrønn sends no CORS headers, so a Flutter **web** build can't call it
  /// directly from the browser (you get "ClientException: Failed to fetch").
  /// Native builds (Android/iOS/desktop) don't enforce CORS and ignore this.
  ///
  /// Web builds therefore go through a CORS proxy that appends the request URL
  /// url-encoded:
  ///   * Debug web builds default to the local dev proxy — start it first with
  ///     `dart run tool/cors_proxy.dart` (see that file).
  ///   * Release web builds need a deployed proxy passed at build time:
  ///     `flutter build web --dart-define=MG_CORS_PROXY=https://my-proxy.workers.dev/?url=`
  ///     Public proxies (corsproxy.io etc.) are paywalled/unreliable — don't
  ///     depend on them.
  ///
  /// Minimal Cloudflare Worker that works with this client:
  ///   export default {
  ///     async fetch(req) {
  ///       const url = new URL(req.url).searchParams.get('url');
  ///       const r = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
  ///       const h = new Headers(r.headers);
  ///       h.set('Access-Control-Allow-Origin', '*');
  ///       return new Response(r.body, { status: r.status, headers: h });
  ///     }
  ///   }
  static const _corsProxy =
      String.fromEnvironment('MG_CORS_PROXY', defaultValue: '');
  static const _debugProxy = 'http://localhost:8787/?url=';

  // A desktop UA keeps the endpoints happy and avoids odd mobile variants.
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ThirstTrApp',
  };

  /// The Mestergrønn API needs no credentials; kept so callers can stay generic.
  bool get hasKey => true;

  /// Wrap an image URL with the CORS proxy on web builds. The Demandware
  /// image CDN sends no CORS headers and CanvasKit fetches image bytes with
  /// fetch(), so direct URLs render as blanks on web. Display-time only —
  /// never persist the returned URL (it may point at a localhost proxy).
  static String? displayImage(String? url) {
    if (url == null || !kIsWeb) return url;
    final proxy = _corsProxy.isNotEmpty
        ? _corsProxy
        : (kDebugMode ? _debugProxy : '');
    if (proxy.isEmpty) return url;
    return '$proxy${Uri.encodeComponent(url)}';
  }

  Uri _u(String path) {
    final target = '$_base$path';
    final proxy = _corsProxy.isNotEmpty
        ? _corsProxy
        : (kDebugMode ? _debugProxy : '');
    if (kIsWeb && proxy.isNotEmpty) {
      return Uri.parse('$proxy${Uri.encodeComponent(target)}');
    }
    return Uri.parse(target);
  }

  /// Package deals ("Monstera i sort potte", "… i gavebag med bobler") are
  /// noise for plant care. The suggestions HTML has no product_type field
  /// (only Product-Variation does, at one extra request per hit), so bundles
  /// are dropped by the container/packaging words in their names instead.
  static final _bundleName = RegExp(
    r'(potte\b|potter\b|potteskjuler|krukke|kurv|vase|glass|gave|bobler|'
    r'sjokolade|ballong|bamse|\bsett\b|\bkort\b)',
    caseSensitive: false,
  );

  /// Search products by name — returns lightweight [Species] (id + name + image)
  /// parsed from the autocomplete suggestions. Bundles are filtered out.
  Future<List<Species>> speciesList({String? query, int page = 1}) async {
    final q = (query ?? '').trim();
    if (q.isEmpty) return const [];
    final res = await _client.get(
      _u('/SearchServices-GetSuggestions?q=${Uri.encodeQueryComponent(q)}'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw MestergronnException('Søk feilet (${res.statusCode}).');
    }
    return _parseSuggestions(res.body)
        .where((s) => !_bundleName.hasMatch(s.commonName))
        .toList();
  }

  /// Full product details for one product id (the `pid`).
  Future<Species> speciesDetails(int id) async {
    final res = await _client.get(
      _u('/Product-Variation?pid=$id&quantity=1'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw MestergronnException('Produkt $id feilet (${res.statusCode}).');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final product = json['product'];
    if (product is! Map) {
      throw MestergronnException('Uventet svar for produkt $id.');
    }
    return Species.fromMestergronn(Map<String, dynamic>.from(product));
  }

  /// Product-Variation already returns everything in one call, so the "enriched"
  /// fetch is just the details fetch (name kept for API parity with the UI).
  Future<Species> enrichedSpecies(int id) => speciesDetails(id);

  /// Parse the autocomplete HTML, keeping only product entries (`id="product-N"`)
  /// and skipping editorial/content links.
  static List<Species> _parseSuggestions(String html) {
    // Each product suggestion: a <span ... id="product-N"> wrapping an anchor to
    // "/.../<pid>.html", a thumbnail <img src>, and a <span class="name">.
    final block = RegExp(
      r'id="product-\d+".*?href="([^"]+)".*?<img[^>]*\bsrc="([^"]+)".*?'
      r'<span class="name">\s*(.*?)\s*</span>',
      dotAll: true,
    );
    final pid = RegExp(r'/(\d+)\.html');
    final out = <Species>[];
    final seen = <int>{};
    for (final m in block.allMatches(html)) {
      final href = m.group(1) ?? '';
      final idMatch = pid.firstMatch(href);
      if (idMatch == null) continue; // editorial link, no numeric pid
      final id = int.tryParse(idMatch.group(1)!);
      if (id == null || !seen.add(id)) continue;
      out.add(Species.fromSuggestion(
        id: id,
        name: _decode(m.group(3) ?? ''),
        imageUrl: _decode(m.group(2) ?? ''),
      ));
    }
    return out;
  }

  /// Minimal HTML-entity decode for the few entities the markup uses.
  static String _decode(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
}
