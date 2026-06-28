import 'package:flutter_test/flutter_test.dart';

import 'package:thirsttrapp/models/species.dart';
import 'package:thirsttrapp/services/weather_api.dart';

void main() {
  test('Species derives watering interval from word', () {
    final s = Species(id: 1, commonName: 'Test', wateringWord: 'Frequent');
    expect(s.baseWateringDays, 3);
  });

  test('Weather watering factor stays within bounds', () {
    final w = WeatherSnapshot(
      temperatureC: 35,
      humidityPct: 10,
      windKmh: 40,
      precip24hMm: 0,
      fetchedAt: DateTime(2026, 6, 27),
    );
    expect(w.wateringFactor, greaterThanOrEqualTo(0.6));
    expect(w.wateringFactor, lessThanOrEqualTo(1.6));
  });
}
