import 'package:flutter_test/flutter_test.dart';

import 'package:thirsttrapp/core/enums.dart';
import 'package:thirsttrapp/core/plant_enums.dart';
import 'package:thirsttrapp/models/heat_source.dart';
import 'package:thirsttrapp/models/plant.dart';
import 'package:thirsttrapp/models/room.dart';
import 'package:thirsttrapp/models/species.dart';
import 'package:thirsttrapp/services/evapotranspiration.dart';
import 'package:thirsttrapp/services/weather_api.dart';

Plant _plant() => Plant(
      id: 'p1',
      name: 'Monstera',
      relativeSize: RelativeSize.medium,
      maturityBase: MaturityStage.mature,
      species: Species(id: 1, commonName: 'Monstera', wateringWord: 'average'),
    );

WeatherSnapshot _weather({double t = 5, double rh = 80}) => WeatherSnapshot(
      temperatureC: t,
      humidityPct: rh,
      windKmh: 12,
      precip24hMm: 0,
      fetchedAt: DateTime(2026, 1, 15),
    );

void main() {
  test('Penman-Monteith vapour-pressure helpers match FAO-56 reference', () {
    // At 20 °C, e_s ≈ 2.338 kPa and Δ ≈ 0.145 kPa/°C (FAO-56 worked example).
    expect(LocalClimate.satVapPressure(20), closeTo(2.338, 0.01));
    expect(LocalClimate.satSlope(20), closeTo(0.145, 0.005));
  });

  test('Warm bright dry room dries faster than cool dim humid room', () {
    final now = DateTime(2026, 1, 15, 12);

    final warmDry = WaterModel.estimate(EtInputs(
      plant: _plant(),
      room: Room(id: 'r', name: 'Stue', temperatureC: 24)
        ..lightIntensity = LightIntensity.direct,
      weather: _weather(t: -5, rh: 70), // cold outside → dry heated indoor air
      latitude: 59.9,
      now: now,
    ));

    final coolHumid = WaterModel.estimate(EtInputs(
      plant: _plant(),
      room: Room(id: 'r', name: 'Bad', temperatureC: 18)
        ..lightIntensity = LightIntensity.shaded,
      weather: _weather(t: 12, rh: 95),
      latitude: 59.9,
      now: now,
    ));

    expect(warmDry.etPlantMmDay, greaterThan(coolHumid.etPlantMmDay));
    expect(warmDry.intervalDays, lessThan(coolHumid.intervalDays));
    // Sensor/manual/weather data present → not a statistical guess.
    expect(warmDry.quality, isNot(ClimateSource.statistical));
  });

  test('A nearby heat source shortens the interval', () {
    final now = DateTime(2026, 1, 15, 12);
    final room = Room(id: 'r', name: 'Stue', temperatureC: 21)
      ..lightIntensity = LightIntensity.indirect;

    final base = WaterModel.estimate(EtInputs(
      plant: _plant(),
      room: room,
      weather: _weather(),
      latitude: 59.9,
      now: now,
    ));

    final fireplace = HeatSource(
      id: 'h',
      name: 'Peis',
      type: HeatType.fireplace,
      heatSetting: HeatSetting.high,
    );
    final heated = WaterModel.estimate(EtInputs(
      plant: _plant()..nearHeatSource = true,
      room: room,
      nearbyHeatSources: [fireplace],
      roomHeatSources: [fireplace],
      weather: _weather(),
      latitude: 59.9,
      now: now,
    ));

    expect(heated.climate.airTempC.value,
        greaterThan(base.climate.airTempC.value));
    expect(heated.intervalDays, lessThanOrEqualTo(base.intervalDays));
  });

  test('Pot on a floor with heating cables dries faster than a raised pot',
      () {
    final now = DateTime(2026, 1, 15, 12);
    final room = Room(id: 'r', name: 'Bad', temperatureC: 22)
      ..lightIntensity = LightIntensity.indirect;
    final cable = HeatSource(
        id: 'c', name: 'Gulvvarme', type: HeatType.heatingCable);

    EtEstimate run(bool onFloor) => WaterModel.estimate(EtInputs(
          plant: _plant()..onFloor = onFloor,
          room: room,
          roomHeatSources: [cable], // room-based: never "near"-selected
          weather: _weather(),
          latitude: 59.9,
          now: now,
        ));

    final raised = run(false);
    final onFloor = run(true);
    expect(onFloor.climate.airTempC.value,
        closeTo(raised.climate.airTempC.value + 3.0, 0.01));
    expect(onFloor.intervalDays, lessThanOrEqualTo(raised.intervalDays));
  });

  test('No room/weather/sensors → statistical fallback is flagged', () {
    final est = WaterModel.estimate(EtInputs(
      plant: _plant(),
      now: DateTime(2026, 1, 15, 12),
    ));
    expect(est.quality, ClimateSource.statistical);
    expect(est.intervalDays, inInclusiveRange(1, 90));
  });

  test('Interval stays within sane bounds across extremes', () {
    for (final t in [10.0, 21.0, 35.0]) {
      for (final light in LightIntensity.values) {
        final est = WaterModel.estimate(EtInputs(
          plant: _plant(),
          room: Room(id: 'r', name: 'R', temperatureC: t)
            ..lightIntensity = light,
          weather: _weather(t: t - 5),
          latitude: 59.9,
          now: DateTime(2026, 6, 15, 12),
        ));
        expect(est.intervalDays, inInclusiveRange(1, 90));
        expect(est.etPlantMmDay, greaterThanOrEqualTo(0));
      }
    }
  });
}
