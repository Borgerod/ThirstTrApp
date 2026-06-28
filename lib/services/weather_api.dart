import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/json.dart';

/// A geocoded place.
class GeoPlace {
  GeoPlace({required this.name, required this.latitude, required this.longitude});
  final String name;
  final double latitude;
  final double longitude;
}

/// Current outdoor climate snapshot used to nudge care schedules.
class WeatherSnapshot {
  WeatherSnapshot({
    required this.temperatureC,
    required this.humidityPct,
    required this.windKmh,
    required this.precip24hMm,
    required this.fetchedAt,
  });

  final double temperatureC;
  final double humidityPct;
  final double windKmh;
  final double precip24hMm;
  final DateTime fetchedAt;

  /// Multiplier applied to base watering interval. >1 = water less often
  /// (humid/cool), <1 = water more often (hot/dry/windy). Clamped.
  double get wateringFactor {
    var f = 1.0;
    f *= 1 + ((humidityPct - 50) / 100); // humid air slows drying
    f *= 1 - ((temperatureC - 21) * 0.015); // warmth speeds drying
    f *= 1 - (windKmh * 0.004); // wind speeds drying
    return f.clamp(0.6, 1.6);
  }

  Map<String, dynamic> toJson() => {
        'temperatureC': temperatureC,
        'humidityPct': humidityPct,
        'windKmh': windKmh,
        'precip24hMm': precip24hMm,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> j) => WeatherSnapshot(
        temperatureC: asDouble(j['temperatureC']) ?? 21,
        humidityPct: asDouble(j['humidityPct']) ?? 50,
        windKmh: asDouble(j['windKmh']) ?? 0,
        precip24hMm: asDouble(j['precip24hMm']) ?? 0,
        fetchedAt: asDate(j['fetchedAt']) ?? DateTime.now(),
      );
}

enum Season { winter, spring, summer, autumn }

/// Weather client backed by free, key-less services:
/// - Forecast: MET Norway / yr.no Locationforecast 2.0 (https://api.met.no).
///   Global coverage, best in the Nordics. No API key — but an identifying
///   `User-Agent` header is MANDATORY (requests without it get HTTP 403).
/// - Geocoding: OpenStreetMap Nominatim (MET offers no geocoding). Also
///   key-less; the same identifying `User-Agent` is required by its usage
///   policy.
///
/// Both are free for low-volume personal use. Be a good citizen: one call per
/// refresh, identifiable UA, no hammering.
class WeatherApi {
  WeatherApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// Identifies the app + a contact, per MET and Nominatim usage policies.
  static const _userAgent = 'ThirstTrApp/1.0 (personal; aborgerod@gmail.com)';
  Map<String, String> get _headers => {'User-Agent': _userAgent};

  /// City/place search via Nominatim → coordinates.
  Future<List<GeoPlace>> geocode(String name) async {
    final url = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
      queryParameters: {
        'q': name,
        'format': 'jsonv2',
        'limit': '8',
        'addressdetails': '1',
        'accept-language': 'nb',
      },
    );
    final res = await _client.get(url, headers: _headers);
    if (res.statusCode != 200) return const [];
    final list = jsonDecode(res.body);
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((r) => GeoPlace(
              name: asString(r['display_name']) ?? asString(r['name']) ?? name,
              latitude: asDouble(r['lat']) ?? 0,
              longitude: asDouble(r['lon']) ?? 0,
            ))
        .where((p) => p.latitude != 0 || p.longitude != 0)
        .toList();
  }

  /// Reverse-geocode coordinates → a readable place name (Nominatim).
  Future<String?> reverseGeocode(double lat, double lon) async {
    final url = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(
      queryParameters: {
        'lat': '$lat',
        'lon': '$lon',
        'format': 'jsonv2',
        'zoom': '12',
        'accept-language': 'nb',
      },
    );
    final res = await _client.get(url, headers: _headers);
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body);
    if (j is Map) return asString(j['display_name']) ?? asString(j['name']);
    return null;
  }

  /// Current conditions from MET Locationforecast (first timeseries entry).
  Future<WeatherSnapshot> current(double lat, double lon) async {
    // MET asks coordinates be truncated to 4 decimals to improve caching.
    String c(double v) => v.toStringAsFixed(4);
    final url = Uri.parse(
            'https://api.met.no/weatherapi/locationforecast/2.0/compact')
        .replace(queryParameters: {'lat': c(lat), 'lon': c(lon)});
    final res = await _client.get(url, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('MET-feil ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final series = ((json['properties'] as Map?)?['timeseries'] as List?) ?? const [];
    if (series.isEmpty) throw Exception('MET: tomt værvarsel');
    final data = (series.first as Map)['data'] as Map? ?? {};
    final details =
        ((data['instant'] as Map?)?['details'] as Map?) ?? const {};

    // Near-term precipitation as an outdoor-humidity proxy: prefer next 6h.
    double precip(String window) =>
        asDouble(((data[window] as Map?)?['details'] as Map?)?['precipitation_amount']) ?? 0;
    final nextPrecip =
        precip('next_6_hours') > 0 ? precip('next_6_hours') : precip('next_1_hours');

    return WeatherSnapshot(
      temperatureC: asDouble(details['air_temperature']) ?? 21,
      humidityPct: asDouble(details['relative_humidity']) ?? 50,
      // MET reports wind in m/s; the snapshot expects km/h.
      windKmh: (asDouble(details['wind_speed']) ?? 0) * 3.6,
      precip24hMm: nextPrecip,
      fetchedAt: DateTime.now(),
    );
  }

  /// Northern-hemisphere season from month.
  static Season seasonFor(DateTime d) {
    return switch (d.month) {
      12 || 1 || 2 => Season.winter,
      3 || 4 || 5 => Season.spring,
      6 || 7 || 8 => Season.summer,
      _ => Season.autumn,
    };
  }

  /// Plants drink less in winter dormancy, more in summer growth.
  static double seasonFactor(Season s) => switch (s) {
        Season.winter => 1.4,
        Season.spring => 0.95,
        Season.summer => 0.85,
        Season.autumn => 1.1,
      };
}
