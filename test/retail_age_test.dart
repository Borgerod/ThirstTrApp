import 'package:flutter_test/flutter_test.dart';
import 'package:thirsttrapp/core/plant_enums.dart';
import 'package:thirsttrapp/core/retail_age.dart';
import 'package:thirsttrapp/models/plant.dart';

void main() {
  group('RetailAge.estimateYears', () {
    test('unknown species uses size-class midpoints', () {
      expect(RetailAge.estimateYears(names: ['Ukjent plante']), 2.0);
      expect(
          RetailAge.estimateYears(
              names: ['Ukjent'], size: RelativeSize.small),
          0.5);
      expect(
          RetailAge.estimateYears(
              names: ['Ukjent'], size: RelativeSize.large),
          5.5);
      expect(
          RetailAge.estimateYears(names: ['Ukjent'], size: RelativeSize.huge),
          14.0);
    });

    test('species override at medium size', () {
      expect(RetailAge.estimateYears(names: ['Monstera deliciosa']), 1.5);
      expect(RetailAge.estimateYears(names: ['Gullranke']), 0.7);
      expect(RetailAge.estimateYears(names: ['Fredslilje']), 1.5);
      expect(RetailAge.estimateYears(names: ['Ficus elastica']), 2.0);
    });

    test('species override matched case-insensitively across any name', () {
      expect(
          RetailAge.estimateYears(names: ['Min fine plante', 'MONSTERA']), 1.5);
      expect(
          RetailAge.estimateYears(names: ['Epipremnum aureum']), 0.7);
    });

    test('species override scales with size class', () {
      // Fast grower stays young in every size class: 0.7 * (5.5 / 2.0).
      expect(
          RetailAge.estimateYears(
              names: ['Pothos'], size: RelativeSize.large),
          closeTo(1.925, 1e-9));
    });
  });

  group('Plant.age', () {
    test('medium monstera bought 1 year ago is ~2.5 years old', () {
      final p = Plant(
        id: 'p1',
        name: 'Monstera',
        relativeSize: RelativeSize.medium,
        acquiredDate: DateTime.now().subtract(const Duration(days: 365)),
      );
      expect(p.ageIsEstimated, isTrue);
      expect(p.age.inDays / 365.0, closeTo(2.5, 0.02));
    });

    test('user-provided age wins over the estimate', () {
      final p = Plant(
        id: 'p2',
        name: 'Monstera',
        ageYearsAtAcquisition: 4,
        acquiredDate: DateTime.now().subtract(const Duration(days: 365)),
      );
      expect(p.ageIsEstimated, isFalse);
      expect(p.age.inDays / 365.0, closeTo(5.0, 0.02));
    });

    test('age is never 0 for a freshly registered plant', () {
      final p = Plant(id: 'p3', name: 'Ukjent', acquiredDate: DateTime.now());
      expect(p.age.inDays, greaterThan(300));
    });

    test('maturity advances by years OWNED, not total age', () {
      final p = Plant(
        id: 'p4',
        name: 'Monstera',
        maturityBase: MaturityStage.young,
        acquiredDate: DateTime.now(),
      );
      // Bought today: retail-age estimate must not advance the stage.
      expect(p.maturity, MaturityStage.young);
    });

    test('ageYearsAtAcquisition survives JSON round-trip', () {
      final p = Plant(id: 'p5', name: 'X', ageYearsAtAcquisition: 2.5);
      final back = Plant.fromJson(p.toJson());
      expect(back.ageYearsAtAcquisition, 2.5);
      final none = Plant.fromJson(Plant(id: 'p6', name: 'Y').toJson());
      expect(none.ageYearsAtAcquisition, isNull);
    });
  });
}
