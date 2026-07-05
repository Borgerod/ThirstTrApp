// Tiny local CORS proxy for Flutter web development.
//
// Mestergrønn (and most scraped endpoints) send no Access-Control-Allow-Origin
// header, so the browser blocks direct fetches from a `flutter run -d chrome`
// build. This proxy fetches the target server-side (no CORS there) and relays
// the body back with `Access-Control-Allow-Origin: *`.
//
// Usage:
//   dart run tool/cors_proxy.dart          # listens on http://localhost:8787
//   dart run tool/cors_proxy.dart 9000     # custom port
//
// Request format (matches MestergronnApi._corsProxy):
//   http://localhost:8787/?url=<url-encoded target>
//
// Dev-only: binds to loopback and should never be deployed as-is (it is an
// open relay). For production web builds use a restricted Cloudflare Worker.
import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8787;
  final client = HttpClient();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('CORS proxy listening on http://localhost:$port/?url=...');

  await for (final req in server) {
    req.response.headers.set('Access-Control-Allow-Origin', '*');
    if (req.method == 'OPTIONS') {
      req.response.headers.set('Access-Control-Allow-Headers', '*');
      await req.response.close();
      continue;
    }
    final target = req.uri.queryParameters['url'];
    if (target == null || target.isEmpty) {
      req.response
        ..statusCode = HttpStatus.badRequest
        ..write('missing ?url= parameter');
      await req.response.close();
      continue;
    }
    try {
      // Forward method + body so POST endpoints (e.g. OCR upload) work too.
      final upstream = await client.openUrl(req.method, Uri.parse(target));
      upstream.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        'ThirstTrApp',
      );
      final reqType = req.headers.contentType;
      if (reqType != null) upstream.headers.contentType = reqType;
      await upstream.addStream(req);
      final res = await upstream.close();
      req.response.statusCode = res.statusCode;
      final type = res.headers.contentType;
      if (type != null) req.response.headers.contentType = type;
      await res.pipe(req.response); // pipe closes the response
      stdout.writeln('${res.statusCode} $target');
    } catch (e) {
      stdout.writeln('ERR $target — $e');
      req.response
        ..statusCode = HttpStatus.badGateway
        ..write('proxy error: $e');
      await req.response.close();
    }
  }
}
