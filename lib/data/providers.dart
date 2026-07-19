import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/enums.dart';
import '../models/app_settings.dart';
import '../models/care_task.dart';
import '../models/floor.dart';
import '../models/heat_source.dart';
import '../models/plant.dart';
import '../models/room.dart';
import '../models/room_opening.dart';
import '../models/window_object.dart';
import '../services/mestergronn_api.dart';
import '../services/notification_service.dart';
import '../services/evapotranspiration.dart';
import '../services/ocr_api.dart';
import '../services/plant_catalog.dart';
import '../services/plantasjen_api.dart';
import '../services/scheduler.dart';
import '../services/weather_api.dart';
import 'repositories.dart';

const uuid = Uuid();

// ---------------------------------------------------------------------------
// Repositories (singletons)
// ---------------------------------------------------------------------------
final plantRepoProvider = Provider((_) => PlantRepository());
final roomRepoProvider = Provider((_) => RoomRepository());
final windowRepoProvider = Provider((_) => WindowRepository());
final heatRepoProvider = Provider((_) => HeatSourceRepository());
final openingRepoProvider = Provider((_) => RoomOpeningRepository());
final floorRepoProvider = Provider((_) => FloorRepository());
final taskRepoProvider = Provider((_) => TaskRepository());
final settingsRepoProvider = Provider((_) => SettingsRepository());

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsRepoProvider).load();

  Future<void> update(AppSettings s) async {
    await ref.read(settingsRepoProvider).save(s);
    state = s;
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

// ---------------------------------------------------------------------------
// Rooms / Windows / Heat sources
// ---------------------------------------------------------------------------
class RoomsController extends Notifier<List<Room>> {
  @override
  List<Room> build() => ref.read(roomRepoProvider).all();

  Future<void> save(Room r) async {
    await ref.read(roomRepoProvider).save(r);
    state = ref.read(roomRepoProvider).all();
  }

  Future<void> delete(String id) async {
    await ref.read(roomRepoProvider).remove(id);
    state = ref.read(roomRepoProvider).all();
  }
}

final roomsProvider = NotifierProvider<RoomsController, List<Room>>(
  RoomsController.new,
);

class WindowsController extends Notifier<List<WindowObject>> {
  @override
  List<WindowObject> build() => ref.read(windowRepoProvider).all();

  Future<void> save(WindowObject w) async {
    await ref.read(windowRepoProvider).save(w);
    state = ref.read(windowRepoProvider).all();
  }

  Future<void> delete(String id) async {
    await ref.read(windowRepoProvider).remove(id);
    state = ref.read(windowRepoProvider).all();
  }
}

final windowsProvider = NotifierProvider<WindowsController, List<WindowObject>>(
  WindowsController.new,
);

class HeatSourcesController extends Notifier<List<HeatSource>> {
  @override
  List<HeatSource> build() => ref.read(heatRepoProvider).all();

  Future<void> save(HeatSource h) async {
    await ref.read(heatRepoProvider).save(h);
    state = ref.read(heatRepoProvider).all();
  }

  Future<void> delete(String id) async {
    await ref.read(heatRepoProvider).remove(id);
    state = ref.read(heatRepoProvider).all();
  }
}

final heatSourcesProvider =
    NotifierProvider<HeatSourcesController, List<HeatSource>>(
      HeatSourcesController.new,
    );

class OpeningsController extends Notifier<List<RoomOpening>> {
  @override
  List<RoomOpening> build() => ref.read(openingRepoProvider).all();

  Future<void> save(RoomOpening o) async {
    await ref.read(openingRepoProvider).save(o);
    state = ref.read(openingRepoProvider).all();
    // Openings change how rooms share climate → recompute every schedule.
    await ref.read(tasksProvider.notifier).rebuildAll();
  }

  Future<void> delete(String id) async {
    await ref.read(openingRepoProvider).remove(id);
    state = ref.read(openingRepoProvider).all();
    await ref.read(tasksProvider.notifier).rebuildAll();
  }
}

final openingsProvider =
    NotifierProvider<OpeningsController, List<RoomOpening>>(
      OpeningsController.new,
    );

class FloorsController extends Notifier<List<Floor>> {
  @override
  List<Floor> build() => ref.read(floorRepoProvider).all()
    ..sort((a, b) => a.level.compareTo(b.level));

  Future<void> save(Floor f) async {
    await ref.read(floorRepoProvider).save(f);
    state = ref.read(floorRepoProvider).all()
      ..sort((a, b) => a.level.compareTo(b.level));
  }

  Future<void> delete(String id) async {
    await ref.read(floorRepoProvider).remove(id);
    state = ref.read(floorRepoProvider).all()
      ..sort((a, b) => a.level.compareTo(b.level));
  }
}

final floorsProvider =
    NotifierProvider<FloorsController, List<Floor>>(FloorsController.new);

// ---------------------------------------------------------------------------
// Weather (cached future based on home location)
// ---------------------------------------------------------------------------
final weatherApiProvider = Provider((_) => WeatherApi());

final weatherProvider = FutureProvider<WeatherSnapshot?>((ref) async {
  final s = ref.watch(settingsProvider);
  if (!s.hasLocation || !s.useWeatherAdjustment) return null;
  try {
    return await ref
        .read(weatherApiProvider)
        .current(s.latitude!, s.longitude!);
  } catch (_) {
    return null;
  }
});

// ---------------------------------------------------------------------------
// Mestergrønn API (no key required)
// ---------------------------------------------------------------------------

/// Mestergrønn has no pest/disease endpoint; kept as an empty stub so the
/// plant-detail UI keeps compiling and simply hides the section.
final pestDiseaseProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>(
        (ref, speciesId) async => const []);

final mestergronnProvider =
    Provider<MestergronnApi>((ref) => MestergronnApi());

final plantasjenProvider =
    Provider<PlantasjenApi>((ref) => PlantasjenApi());

/// Unified catalogue: Mestergrønn primary, Plantasjen fallback + EAN lookup.
final catalogProvider = Provider<PlantCatalog>(
  (ref) => PlantCatalog(
    ref.read(mestergronnProvider),
    ref.read(plantasjenProvider),
  ),
);

/// Receipt OCR (OCR.space) — see [OcrApi] for key setup.
final ocrProvider = Provider<OcrApi>((ref) => OcrApi());

// ---------------------------------------------------------------------------
// Plants
// ---------------------------------------------------------------------------
class PlantsController extends Notifier<List<Plant>> {
  @override
  List<Plant> build() {
    final repo = ref.read(plantRepoProvider);
    final plants = repo.all();
    // Notes are user-only: older versions auto-copied species tips/description
    // into them on creation. Scrub any note that is still the untouched copy
    // (user-edited text no longer matches and is kept).
    for (final p in plants) {
      if (_scrubSpeciesNotes(p)) repo.save(p);
    }
    // Older snapshots miss facts Mestergrønn never provides (toxicity etc.);
    // backfill them from Plantasjen in the background.
    Future.microtask(_backfillSpeciesFacts);
    return plants;
  }

  /// One pass over stored plants: cross-catalogue fill of missing species
  /// facts (see [PlantCatalog.fillMissingFacts]). Silent, best-effort.
  Future<void> _backfillSpeciesFacts() async {
    final catalog = ref.read(catalogProvider);
    final repo = ref.read(plantRepoProvider);
    var changed = false;
    for (final p in repo.all()) {
      final s = p.species;
      if (s == null || !s.hasMissingFacts) continue;
      final filled = await catalog.fillMissingFacts(s);
      if (identical(filled, s)) continue;
      p.species = filled;
      await repo.save(p);
      changed = true;
    }
    if (changed) state = repo.all();
  }

  static bool _scrubSpeciesNotes(Plant p) {
    final s = p.species;
    if (s == null) return false;
    var changed = false;
    final prefillTips = s.careTips.map((t) => '• $t').join('\n').trim();
    if (p.tips != null && p.tips!.trim() == prefillTips) {
      p.tips = null;
      changed = true;
    }
    if (p.generalInfo != null &&
        p.generalInfo!.trim() == (s.description ?? '').trim()) {
      p.generalInfo = null;
      changed = true;
    }
    return changed;
  }

  Future<void> save(Plant p) async {
    await ref.read(plantRepoProvider).save(p);
    state = ref.read(plantRepoProvider).all();
    await ref.read(tasksProvider.notifier).rebuildForPlant(p.id);
  }

  Future<void> delete(String id) async {
    await ref.read(plantRepoProvider).remove(id);
    state = ref.read(plantRepoProvider).all();
    await ref.read(tasksProvider.notifier).removeForPlant(id);
  }

  Plant? byId(String id) {
    for (final p in state) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Mark a care action done now and persist (also refreshes its task).
  Future<void> markCareDone(String plantId, CareType type) async {
    final p = byId(plantId);
    if (p == null) return;
    p.markDone(type, DateTime.now());
    await save(p);
  }
}

final plantsProvider = NotifierProvider<PlantsController, List<Plant>>(
  PlantsController.new,
);

// ---------------------------------------------------------------------------
// Care context + plans (derived)
// ---------------------------------------------------------------------------
CareContext buildContext(Ref ref, Plant p) {
  final rooms = ref.read(roomsProvider);
  final windows = ref.read(windowsProvider);
  final heats = ref.read(heatSourcesProvider);
  final openings = ref.read(openingsProvider);
  final weather = ref.read(weatherProvider).value;
  final settings = ref.read(settingsProvider);
  return CareContext(
    plant: p,
    room: _firstOrNull(rooms, (r) => r.id == p.roomId),
    window: _firstOrNull(windows, (w) => w.id == p.windowId),
    draftWindow: _firstOrNull(windows, (w) => w.id == p.draftWindowId),
    // "Near" = radiant sources the user picked on the plant.
    heatSources: heats.where((h) => p.heatSourceIds.contains(h.id)).toList(),
    // Ambient = every heat source in the plant's room (cables included).
    roomHeatSources: p.roomId == null
        ? const []
        : heats.where((h) => h.roomId == p.roomId).toList(),
    // Rooms reachable through openings share climate with this plant's room.
    neighbours: p.roomId == null
        ? const []
        : _neighbourLinks(p.roomId!, rooms, heats, windows, openings),
    weather: weather,
    latitude: settings.latitude,
  );
}

/// Build the [RoomLink]s for a room from every opening that touches it.
List<RoomLink> _neighbourLinks(
  String roomId,
  List<Room> rooms,
  List<HeatSource> heats,
  List<WindowObject> windows,
  List<RoomOpening> openings,
) {
  final links = <RoomLink>[];
  for (final o in openings) {
    final otherId = o.otherRoom(roomId);
    if (otherId == null) continue; // opening doesn't touch this room
    final other = _firstOrNull(rooms, (r) => r.id == otherId);
    if (other == null) continue;
    links.add(RoomLink(
      room: other,
      weight: o.flowWeight,
      heatSources: heats.where((h) => h.roomId == otherId).toList(),
      windows: windows.where((w) => w.roomId == otherId).toList(),
      openingName: o.name,
    ));
  }
  return links;
}

final plantPlansProvider = Provider.family<List<CarePlan>, String>((ref, id) {
  ref.watch(weatherProvider);
  ref.watch(settingsProvider);
  final p = ref.watch(plantsProvider.notifier).byId(id);
  if (p == null) return const [];
  return Scheduler.allPlans(buildContext(ref, p));
});

/// Resolved [CareContext] for a plant (room/window/heat/weather), for the UI.
final careContextProvider = Provider.family<CareContext?, String>((ref, id) {
  ref.watch(roomsProvider);
  ref.watch(windowsProvider);
  ref.watch(heatSourcesProvider);
  ref.watch(openingsProvider);
  ref.watch(weatherProvider);
  final p = ref.watch(plantsProvider.notifier).byId(id);
  return p == null ? null : buildContext(ref, p);
});

// ---------------------------------------------------------------------------
// Care tasks
// ---------------------------------------------------------------------------
class TasksController extends Notifier<List<CareTask>> {
  @override
  List<CareTask> build() => ref.read(taskRepoProvider).all();

  TaskRepository get _repo => ref.read(taskRepoProvider);

  /// Recompute due tasks for one plant from its current care plans and
  /// (re)schedule notifications.
  Future<void> rebuildForPlant(String plantId) async {
    final p = ref.read(plantsProvider.notifier).byId(plantId);
    if (p == null) return;
    final plans = Scheduler.allPlans(buildContext(ref, p));
    final settings = ref.read(settingsProvider);
    final notif = NotificationService.instance;

    // Drop existing open tasks for this plant; keep history (done/skipped).
    final existing = _repo.forPlant(plantId);
    for (final t in existing.where((t) => t.status == TaskStatus.due)) {
      await notif.cancel(t.notificationId);
      await _repo.remove(t.id);
    }

    for (final plan in plans) {
      final task = CareTask(
        id: uuid.v4(),
        plantId: plantId,
        type: plan.type,
        dueDate: plan.nextDue,
        notificationId: _notifId(plantId, plan.type),
      );
      await _repo.save(task);
      if (settings.notificationsEnabled) {
        await notif.scheduleTask(task, p.name, hour: settings.notifyHour);
      }
    }
    state = _repo.all();
  }

  Future<void> removeForPlant(String plantId) async {
    final notif = NotificationService.instance;
    for (final t in _repo.forPlant(plantId)) {
      await notif.cancel(t.notificationId);
      await _repo.remove(t.id);
    }
    state = _repo.all();
  }

  Future<void> completeTask(String taskId) async {
    final t = _repo.byId(taskId);
    if (t == null) return;
    await NotificationService.instance.cancel(t.notificationId);
    await ref
        .read(plantsProvider.notifier)
        .markCareDone(t.plantId, t.type); // recomputes next task
  }

  Future<void> postponeTask(String taskId, {int days = 1}) async {
    final t = _repo.byId(taskId);
    if (t == null) return;
    t.dueDate = DateTime.now().add(Duration(days: days));
    t.postponedDays += days;
    t.status = TaskStatus.due;
    await _repo.save(t);
    final p = ref.read(plantsProvider.notifier).byId(t.plantId);
    if (p != null) {
      await NotificationService.instance.scheduleTask(
        t,
        p.name,
        hour: ref.read(settingsProvider).notifyHour,
      );
    }
    state = _repo.all();
  }

  /// Handle a notification action button press.
  Future<void> handleAction(NotificationAction a) async {
    if (a.actionId == kActionPostpone) {
      await postponeTask(a.taskId);
    } else {
      await completeTask(a.taskId);
    }
  }

  /// Rebuild every plant's schedule (after settings/weather change).
  Future<void> rebuildAll() async {
    for (final p in ref.read(plantsProvider)) {
      await rebuildForPlant(p.id);
    }
  }

  List<CareTask> get dueSoon =>
      state.where((t) => t.status == TaskStatus.due).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
}

final tasksProvider = NotifierProvider<TasksController, List<CareTask>>(
  TasksController.new,
);

// 31-bit stable notification id per (plant, careType).
int _notifId(String plantId, CareType type) =>
    (plantId.hashCode ^ (type.index * 0x9E3779B1)) & 0x7fffffff;

T? _firstOrNull<T>(List<T> list, bool Function(T) test) {
  for (final e in list) {
    if (test(e)) return e;
  }
  return null;
}
