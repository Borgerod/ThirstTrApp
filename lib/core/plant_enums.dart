/// Enums for plant size / maturity / condition / care-tag selects.
/// Kept separate from the environment enums in `enums.dart`.
library;

import 'package:flutter/material.dart';

enum RelativeSize {
  tiny('tiny', 'Bitteliten'),
  small('small', 'Liten'),
  medium('medium', 'Middels'),
  large('large', 'Stor'),
  huge('huge', 'Enorm');

  const RelativeSize(this.id, this.label);
  final String id;
  final String label;

  static RelativeSize fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => medium);
}

/// Maturity stages, ordered. [baseAgeYears] = approximate age at which a plant
/// first reaches this stage; used to auto-advance maturity over time.
enum MaturityStage {
  seedling('seedling', 'Frøplante', 0),
  young('young', 'Ung', 1),
  juvenile('juvenile', 'Juvenil', 3),
  mature('mature', 'Voksen', 6),
  old('old', 'Gammel', 15);

  const MaturityStage(this.id, this.label, this.baseAgeYears);
  final String id;
  final String label;
  final int baseAgeYears;

  static MaturityStage fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => mature);

  /// Highest stage whose [baseAgeYears] threshold is <= [years].
  static MaturityStage fromAgeYears(double years) {
    var result = seedling;
    for (final s in values) {
      if (years >= s.baseAgeYears) result = s;
    }
    return result;
  }

  /// This stage advanced forward by [yearsOwned] (silent auto-advance).
  MaturityStage advancedBy(double yearsOwned) =>
      fromAgeYears(baseAgeYears + yearsOwned);
}

enum PlantCondition {
  blooming('blooming', 'Blomstrende'),
  healthy('healthy', 'Frisk'),
  stressed('stressed', 'Stresset'),
  sick('sick', 'Syk'),
  recovering('recovering', 'Restituerer'),
  dying('dying', 'Døende');

  const PlantCondition(this.id, this.label);
  final String id;
  final String label;

  static PlantCondition? fromId(String? id) =>
      id == null ? null : values.where((e) => e.id == id).firstOrNull;
}

/// Notable care characteristic shown as the 4th mini-care circle.
enum CareTag {
  easyCare('Lettstelt', Icons.eco),
  hardCare('Krevende', Icons.science),
  needsShower('Trenger dusj', Icons.shower),
  lovesSoaking('Elsker bløtlegging', Icons.bathtub),
  humidityLover('Liker fukt', Icons.water_drop),
  droughtTolerant('Tåler tørke', Icons.wb_sunny),
  toxic('Giftig', Icons.dangerous);

  const CareTag(this.label, this.icon);
  final String label;
  final IconData icon;
}
