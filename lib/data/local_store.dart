import 'package:hive_flutter/hive_flutter.dart';

/// Hive bootstrap + raw box access.
///
/// To avoid build_runner/codegen, every model is stored as a JSON `Map`
/// (Hive supports primitive maps/lists natively) keyed by the entity id.
/// Repositories handle (de)serialization to typed models.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  static const plantsBox = 'plants';
  static const roomsBox = 'rooms';
  static const windowsBox = 'windows';
  static const heatSourcesBox = 'heat_sources';
  static const openingsBox = 'room_openings';
  static const floorsBox = 'floors';
  static const tasksBox = 'care_tasks';
  static const settingsBox = 'settings';

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(plantsBox),
      Hive.openBox(roomsBox),
      Hive.openBox(windowsBox),
      Hive.openBox(heatSourcesBox),
      Hive.openBox(openingsBox),
      Hive.openBox(floorsBox),
      Hive.openBox(tasksBox),
      Hive.openBox(settingsBox),
    ]);
    _ready = true;
  }

  Box box(String name) => Hive.box(name);

  /// Read all values from a box as JSON maps.
  List<Map<String, dynamic>> readAll(String boxName) => box(boxName)
      .values
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  Future<void> put(String boxName, String key, Map<String, dynamic> value) =>
      box(boxName).put(key, value);

  Future<void> delete(String boxName, String key) => box(boxName).delete(key);
}
