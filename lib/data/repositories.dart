import '../models/app_settings.dart';
import '../models/care_task.dart';
import '../models/heat_source.dart';
import '../models/plant.dart';
import '../models/room.dart';
import '../models/window_object.dart';
import 'local_store.dart';

/// Generic JSON-map backed repository.
class _Repo<T> {
  _Repo(this.boxName, this.fromJson, this.toJson, this.idOf);

  final String boxName;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;
  final String Function(T) idOf;

  final LocalStore _store = LocalStore.instance;

  List<T> all() => _store.readAll(boxName).map(fromJson).toList();

  T? byId(String id) {
    final raw = _store.box(boxName).get(id);
    if (raw is Map) return fromJson(Map<String, dynamic>.from(raw));
    return null;
  }

  Future<void> save(T item) => _store.put(boxName, idOf(item), toJson(item));

  Future<void> remove(String id) => _store.delete(boxName, id);
}

class PlantRepository extends _Repo<Plant> {
  PlantRepository()
      : super(LocalStore.plantsBox, Plant.fromJson, (p) => p.toJson(),
            (p) => p.id);
}

class RoomRepository extends _Repo<Room> {
  RoomRepository()
      : super(
            LocalStore.roomsBox, Room.fromJson, (r) => r.toJson(), (r) => r.id);
}

class WindowRepository extends _Repo<WindowObject> {
  WindowRepository()
      : super(LocalStore.windowsBox, WindowObject.fromJson, (w) => w.toJson(),
            (w) => w.id);
}

class HeatSourceRepository extends _Repo<HeatSource> {
  HeatSourceRepository()
      : super(LocalStore.heatSourcesBox, HeatSource.fromJson, (h) => h.toJson(),
            (h) => h.id);
}

class TaskRepository extends _Repo<CareTask> {
  TaskRepository()
      : super(LocalStore.tasksBox, CareTask.fromJson, (t) => t.toJson(),
            (t) => t.id);

  List<CareTask> forPlant(String plantId) =>
      all().where((t) => t.plantId == plantId).toList();
}

/// Settings live as a single key in their own box.
class SettingsRepository {
  static const _key = 'app_settings';
  final LocalStore _store = LocalStore.instance;

  AppSettings load() {
    final raw = _store.box(LocalStore.settingsBox).get(_key);
    if (raw is Map) return AppSettings.fromJson(Map<String, dynamic>.from(raw));
    return AppSettings();
  }

  Future<void> save(AppSettings s) =>
      _store.put(LocalStore.settingsBox, _key, s.toJson());
}
