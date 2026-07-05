import 'dart:convert';

import 'package:flutter/foundation.dart' show Uint8List, kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;

/// Thrown when OCR fails (network, quota, unreadable image).
class OcrException implements Exception {
  OcrException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Receipt OCR via the OCR.space REST API.
///
/// Chosen because it works identically on web and native (plain HTTP POST) —
/// google_mlkit has no web support and tesseract needs per-platform binaries.
///
/// Key: the default `helloworld` demo key is enough to try it out but is
/// heavily rate-limited (and caps images at 1 MB). Get a free key (25k
/// requests/month) at https://ocr.space/ocrapi/freekey and pass it with:
///   flutter run --dart-define=OCR_SPACE_KEY=your_key
class OcrApi {
  OcrApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoint = 'https://api.ocr.space/parse/image';
  static const _apiKey =
      String.fromEnvironment('OCR_SPACE_KEY', defaultValue: 'helloworld');

  /// OCR.space does send CORS headers, but in debug web builds we still route
  /// through the local dev proxy (tool/cors_proxy.dart) so all outbound
  /// traffic takes one path. Release builds call it directly.
  Uri get _uri => kIsWeb && kDebugMode
      ? Uri.parse('http://localhost:8787/?url=${Uri.encodeComponent(_endpoint)}')
      : Uri.parse(_endpoint);

  /// Run OCR on a receipt photo and return the raw recognized text.
  Future<String> recognizeReceipt(Uint8List imageBytes) async {
    final http.Response res;
    try {
      res = await _client.post(_uri, body: {
        'apikey': _apiKey,
        'base64Image': 'data:image/jpeg;base64,${base64Encode(imageBytes)}',
        // Engine 2 auto-detects western languages (incl. Norwegian, which
        // engine 1 lacks); table mode keeps receipt lines intact.
        'OCREngine': '2',
        'isTable': 'true',
        'scale': 'true',
        'detectOrientation': 'true',
      });
    } catch (e) {
      throw OcrException('OCR-tjenesten er utilgjengelig: $e');
    }
    if (res.statusCode != 200) {
      throw OcrException('OCR feilet (${res.statusCode}).');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['IsErroredOnProcessing'] == true) {
      final err = json['ErrorMessage'];
      final msg = err is List ? err.join(' ') : '$err';
      throw OcrException('OCR feilet: $msg');
    }
    final results = json['ParsedResults'] as List?;
    if (results == null || results.isEmpty) {
      throw OcrException('Fant ingen tekst på bildet.');
    }
    return results
        .map((r) => (r as Map)['ParsedText'] as String? ?? '')
        .join('\n');
  }

  /// Noise on Norwegian receipts that is never a product name.
  static final _noise = RegExp(
    r'(total|sum|subtotal|mva|moms|kort|bank|kontant|veksel|betal|'
    r'org\.?\s*nr|kvitter|takk|velkommen|dato|tid|kasse|butikk|avd|'
    r'tlf|www\.|https?:|medlem|bonus|rabatt|\d{2}[.:/-]\d{2}[.:/-]\d{2})',
    caseSensitive: false,
  );

  /// Trailing price ("129,00", "129.00", "129,-") with optional qty markers.
  static final _price = RegExp(r'\s*\d+\s*(x\s*\d+)?\s*[\d.,]*\s*(kr|,-)?\s*$');

  /// Extract plausible product-name lines from raw receipt text.
  static List<String> candidateLines(String text) {
    final out = <String>[];
    final seen = <String>{};
    for (var line in const LineSplitter().convert(text)) {
      line = line.trim();
      if (line.length < 3 || _noise.hasMatch(line)) continue;
      line = line.replaceFirst(_price, '').trim();
      // Need at least 3 letters left to be a searchable name.
      if (RegExp(r'[a-zA-ZæøåÆØÅ]').allMatches(line).length < 3) continue;
      if (seen.add(line.toLowerCase())) out.add(line);
    }
    return out;
  }
}
