import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../data/providers.dart';
import '../../models/heat_source.dart';
import '../../models/room.dart';
import '../../models/window_object.dart';

/// Manage rooms, windows and heat sources that plants link to.
class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rom & objekter'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Rom'),
            Tab(text: 'Vinduer'),
            Tab(text: 'Varmekilder'),
            Tab(text: 'Gulvplan'),
          ]),
        ),
        body: const TabBarView(children: [
          _RoomTab(),
          _WindowTab(),
          _HeatTab(),
          _FloorTab(),
        ]),
      ),
    );
  }
}

// --------------------------------------------------------------------------- Rooms
class _RoomTab extends ConsumerWidget {
  const _RoomTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editRoom(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          for (final r in rooms)
            ListTile(
              leading: const Icon(Icons.meeting_room),
              title: Text(r.name),
              subtitle: Text(
                  '${r.effectiveTemperatureC.round()}°C · ${r.resolvedIntensity.label} · ${r.facing.label}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => ref.read(roomsProvider.notifier).delete(r.id),
              ),
              onTap: () => _editRoom(context, ref, r),
            ),
        ],
      ),
    );
  }

  void _editRoom(BuildContext context, WidgetRef ref, Room? room) {
    final r = room ?? Room(id: uuid.v4(), name: '');
    final name = TextEditingController(text: r.name);
    final size = TextEditingController(text: r.sizeSqm?.toString() ?? '');
    final temp = TextEditingController(text: r.temperatureC?.toString() ?? '');
    final lux =
        TextEditingController(text: r.lightMeasurementLux?.toString() ?? '');
    var facing = r.facing;
    var light = r.lightIntensity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tf(name, 'Navn'),
              _tf(size, 'Størrelse (m²)', number: true),
              _tf(temp, 'Romtemperatur (°C) — standard 21', number: true),
              _tf(lux, 'Lysmåling (lux) — valgfritt', number: true),
              _facingDropdown(facing, (v) => setSheet(() => facing = v)),
              _lightDropdown(light, (v) => setSheet(() => light = v)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  r.name = name.text.trim().isEmpty ? 'Rom' : name.text.trim();
                  r.sizeSqm = double.tryParse(size.text.replaceAll(',', '.'));
                  r.temperatureC =
                      double.tryParse(temp.text.replaceAll(',', '.'));
                  r.lightMeasurementLux =
                      double.tryParse(lux.text.replaceAll(',', '.'));
                  r.facing = facing;
                  r.lightIntensity = light;
                  ref.read(roomsProvider.notifier).save(r);
                  Navigator.pop(ctx);
                },
                child: const Text('Lagre'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- Windows
class _WindowTab extends ConsumerWidget {
  const _WindowTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = ref.watch(windowsProvider);
    final rooms = {for (final r in ref.watch(roomsProvider)) r.id: r.name};
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editWindow(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          for (final w in windows)
            ListTile(
              leading: const Icon(Icons.window),
              title: Text(w.name),
              subtitle: Text(
                  '${w.facing.label} · ${w.size.label} · ${w.resolvedIntensity.label}${w.roomId != null ? ' · ${rooms[w.roomId] ?? ''}' : ''}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    ref.read(windowsProvider.notifier).delete(w.id),
              ),
              onTap: () => _editWindow(context, ref, w),
            ),
        ],
      ),
    );
  }

  void _editWindow(BuildContext context, WidgetRef ref, WindowObject? win) {
    final rooms = ref.read(roomsProvider);
    final w = win ?? WindowObject(id: uuid.v4(), name: '');
    final name = TextEditingController(text: w.name);
    final lux =
        TextEditingController(text: w.lightMeasurementLux?.toString() ?? '');
    var roomId = w.roomId;
    var facing = w.facing;
    var size = w.size;
    var open = w.openFrequency;
    var light = w.lightIntensity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tf(name, 'Navn'),
                _roomDropdown(rooms, roomId, (v) => setSheet(() => roomId = v)),
                _facingDropdown(facing, (v) => setSheet(() => facing = v)),
                _enumDropdown<WindowSize>('Størrelse', size, WindowSize.values,
                    (e) => e.label, (v) => setSheet(() => size = v!)),
                _enumDropdown<OpenFrequency>(
                    'Åpningsfrekvens',
                    open,
                    OpenFrequency.values,
                    (e) => e.label,
                    (v) => setSheet(() => open = v!)),
                _tf(lux, 'Lysmåling (lux) — valgfritt', number: true),
                _lightDropdown(light, (v) => setSheet(() => light = v)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    w.name =
                        name.text.trim().isEmpty ? 'Vindu' : name.text.trim();
                    w.roomId = roomId;
                    w.facing = facing;
                    w.size = size;
                    w.openFrequency = open;
                    w.lightMeasurementLux =
                        double.tryParse(lux.text.replaceAll(',', '.'));
                    w.lightIntensity = light;
                    ref.read(windowsProvider.notifier).save(w);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Lagre'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- Heat sources
class _HeatTab extends ConsumerWidget {
  const _HeatTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heats = ref.watch(heatSourcesProvider);
    final rooms = {for (final r in ref.watch(roomsProvider)) r.id: r.name};
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editHeat(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          for (final h in heats)
            ListTile(
              leading: const Icon(Icons.local_fire_department),
              title: Text(h.name),
              subtitle: Text(
                  '${h.type.label} · spredning ${h.heatSpread.label} · intensitet ${h.heatIntensity.label}${h.roomId != null ? ' · ${rooms[h.roomId] ?? ''}' : ''}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    ref.read(heatSourcesProvider.notifier).delete(h.id),
              ),
              onTap: () => _editHeat(context, ref, h),
            ),
        ],
      ),
    );
  }

  void _editHeat(BuildContext context, WidgetRef ref, HeatSource? heat) {
    final rooms = ref.read(roomsProvider);
    final h = heat ?? HeatSource(id: uuid.v4(), name: '');
    final name = TextEditingController(text: h.name);
    final temp = TextEditingController(text: h.tempSetting?.toString() ?? '');
    var roomId = h.roomId;
    var type = h.type;
    var spread = h.heatSpread;
    var intensity = h.heatIntensity;
    var setting = h.heatSetting;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tf(name, 'Navn'),
                _roomDropdown(rooms, roomId, (v) => setSheet(() => roomId = v)),
                _enumDropdown<HeatType>('Type', type, HeatType.values,
                    (e) => e.label, (v) => setSheet(() => type = v!)),
                _enumDropdown<Level>('Varmespredning', spread, Level.values,
                    (e) => e.label, (v) => setSheet(() => spread = v!)),
                _enumDropdown<Level>('Varmeintensitet', intensity, Level.values,
                    (e) => e.label, (v) => setSheet(() => intensity = v!)),
                _enumDropdown<HeatSetting?>(
                    'Innstilling',
                    setting,
                    [null, ...HeatSetting.values],
                    (e) => e?.label ?? 'Ingen',
                    (v) => setSheet(() => setting = v)),
                _tf(temp, 'Termostat (°C) — valgfritt', number: true),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    h.name = name.text.trim().isEmpty
                        ? 'Varmekilde'
                        : name.text.trim();
                    h.roomId = roomId;
                    h.type = type;
                    h.heatSpread = spread;
                    h.heatIntensity = intensity;
                    h.heatSetting = setting;
                    h.tempSetting =
                        double.tryParse(temp.text.replaceAll(',', '.'));
                    ref.read(heatSourcesProvider.notifier).save(h);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Lagre'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- Floorplan
/// Draw/edit the home floorplan. Placeholder until the canvas editor is built.
/// This is the blueprint the home screen's "Romvisning" (room_view) renders.
class _FloorTab extends ConsumerWidget {
  const _FloorTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tegneverktøy kommer snart')),
        ),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Tegn'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Planløsning',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Tegn en enkel plantegning av hjemmet og plasser rom, vinduer og '
              'varmekilder. Vises i «Romvisning» på hjemskjermen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            // Placeholder canvas — replace with the draw/edit surface later.
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.4),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.architecture_outlined, size: 56),
                      SizedBox(height: 12),
                      Text('Ingen plantegning ennå'),
                      SizedBox(height: 4),
                      Text('Trykk «Tegn» for å starte (kommer snart)'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- shared form bits
Widget _tf(TextEditingController c, String label, {bool number = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : null,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
      ),
    );

Widget _enumDropdown<T>(String label, T value, List<T> values,
        String Function(T) labelOf, ValueChanged<T?> onChanged) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            items: [
              for (final v in values)
                DropdownMenuItem(value: v, child: Text(labelOf(v))),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );

Widget _facingDropdown(Facing value, ValueChanged<Facing> onChanged) =>
    _enumDropdown<Facing>('Himmelretning', value, Facing.values,
        (e) => e.label, (v) => onChanged(v ?? Facing.unknown));

Widget _lightDropdown(
        LightIntensity? value, ValueChanged<LightIntensity?> onChanged) =>
    _enumDropdown<LightIntensity?>(
        'Lysintensitet (valgfritt)',
        value,
        [null, ...LightIntensity.values],
        (e) => e?.label ?? 'Estimer',
        onChanged);

Widget _roomDropdown(
        List<Room> rooms, String? value, ValueChanged<String?> onChanged) =>
    _enumDropdown<String?>(
        'Rom',
        value,
        [null, ...rooms.map((r) => r.id)],
        (id) => id == null
            ? 'Uten rom'
            : rooms.firstWhere((r) => r.id == id).name,
        onChanged);
