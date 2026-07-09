import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../models/floor.dart';
import '../../models/floor_position.dart';
import '../../models/heat_source.dart';
import '../../models/plant.dart';
import '../../models/room.dart';
import '../../models/window_object.dart';

/// What kind of placeable object is being dragged onto the canvas.
enum _Kind { plant, heat, window }

/// A palette/canvas drag payload: the object kind + its id.
class _Placeable {
  const _Placeable(this.kind, this.id);
  final _Kind kind;
  final String id;
}

/// Interactive floor-plan builder.
///
/// - Floors are selectable from the rail on the right; "+" adds a floor.
/// - Toggle "Tegn rom" then drag on the canvas to draw a new room (also created
///   in the Rooms tab). Existing un-placed rooms can be dropped from the "Rom"
///   menu.
/// - Rooms can be moved (drag the title bar) and resized (bottom-right handle).
/// - Plants, heat sources and windows are dragged from the palette into a room;
///   dragging them within/between rooms updates their room-local position.
class FloorPlanBuilder extends ConsumerStatefulWidget {
  const FloorPlanBuilder({super.key});

  @override
  ConsumerState<FloorPlanBuilder> createState() => _FloorPlanBuilderState();
}

class _FloorPlanBuilderState extends ConsumerState<FloorPlanBuilder> {
  final _canvasKey = GlobalKey();
  String? _floorId;
  bool _drawMode = false;

  // Live draw-rectangle preview, in canvas pixels.
  Offset? _drawStart;
  Offset? _drawEnd;

  @override
  Widget build(BuildContext context) {
    final floors = ref.watch(floorsProvider);
    final rooms = ref.watch(roomsProvider);
    final plants = ref.watch(plantsProvider);
    final heats = ref.watch(heatSourcesProvider);
    final windows = ref.watch(windowsProvider);

    if (floors.isEmpty) {
      return _EmptyFloors(onCreate: () => _addFloor(floors));
    }

    final floorId =
        floors.any((f) => f.id == _floorId) ? _floorId! : floors.first.id;
    final placedRooms =
        rooms.where((r) => r.floorId == floorId && r.floorRect != null).toList();

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _toolbar(rooms, floorId),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    return ClipRect(
                      child: Stack(
                        key: _canvasKey,
                        children: [
                          _background(w, h),
                          for (final room in placedRooms)
                            _roomBox(room, plants, heats, windows, w, h),
                          if (_drawStart != null && _drawEnd != null)
                            _drawPreview(),
                          _palette(plants, heats, windows),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        _FloorRail(
          floors: floors,
          selectedId: floorId,
          onSelect: (id) => setState(() => _floorId = id),
          onAdd: () => _addFloor(floors),
          onRename: _renameFloor,
          onDelete: (f) => _deleteFloor(f, rooms),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------- chrome
  Widget _toolbar(List<Room> rooms, String floorId) {
    final unplaced = rooms
        .where((r) => r.floorId == null || r.floorRect == null)
        .toList();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _drawMode = !_drawMode),
              icon: Icon(_drawMode ? Icons.check : Icons.crop_square),
              label: Text(_drawMode ? 'Ferdig' : 'Tegn rom'),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              enabled: unplaced.isNotEmpty,
              onSelected: (id) => _placeExistingRoom(
                  rooms.firstWhere((r) => r.id == id), floorId),
              itemBuilder: (_) => [
                for (final r in unplaced)
                  PopupMenuItem(value: r.id, child: Text(r.name)),
              ],
              child: Chip(
                avatar: const Icon(Icons.meeting_room, size: 18),
                label: Text('Plasser rom (${unplaced.length})'),
              ),
            ),
            const Spacer(),
            Text(
              _drawMode ? 'Dra for å tegne et rom' : 'Dra objekter inn i rom',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _background(double w, double h) => Positioned.fill(
        child: GestureDetector(
          onPanStart: _drawMode
              ? (d) => setState(() {
                    _drawStart = _toCanvas(d.globalPosition);
                    _drawEnd = _drawStart;
                  })
              : null,
          onPanUpdate: _drawMode
              ? (d) => setState(() => _drawEnd = _toCanvas(d.globalPosition))
              : null,
          onPanEnd: _drawMode ? (_) => _finishDraw(w, h) : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.35),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );

  Widget _drawPreview() {
    final r = Rect.fromPoints(_drawStart!, _drawEnd!);
    return Positioned(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
                color: Theme.of(context).colorScheme.primary, width: 2),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- room box
  Widget _roomBox(Room room, List<Plant> plants, List<HeatSource> heats,
      List<WindowObject> windows, double w, double h) {
    final rect = room.floorRect!;
    final left = rect.x * w;
    final top = rect.y * h;
    final width = rect.w * w;
    final height = rect.h * h;
    final scheme = Theme.of(context).colorScheme;

    final roomPlants = plants.where((p) => p.roomId == room.id).toList();
    final roomHeats = heats.where((e) => e.roomId == room.id).toList();
    final roomWindows = windows.where((e) => e.roomId == room.id).toList();

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: DragTarget<_Placeable>(
        onAcceptWithDetails: (d) => _dropInto(room, d.data, d.offset, w, h),
        builder: (context, cand, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            // Room shell.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(
                      alpha: cand.isNotEmpty ? 0.55 : 0.30),
                  border: Border.all(color: scheme.outline, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            // Title bar = move handle.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: GestureDetector(
                onPanUpdate: (d) => _moveRoom(room, d.delta, w, h),
                onPanEnd: (_) => ref.read(roomsProvider.notifier).save(room),
                child: Container(
                  height: 22,
                  color: scheme.secondary.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_indicator, size: 14),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(room.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      InkWell(
                        onTap: () => _unplaceRoom(room),
                        child: const Icon(Icons.close, size: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Placed objects.
            for (final p in roomPlants)
              _chip(room, _Placeable(_Kind.plant, p.id), p.floorPosition,
                  Icons.local_florist, p.name, width, height),
            for (final e in roomHeats)
              _chip(room, _Placeable(_Kind.heat, e.id), e.floorPosition,
                  Icons.local_fire_department, e.name, width, height),
            for (final e in roomWindows)
              _chip(room, _Placeable(_Kind.window, e.id), e.floorPosition,
                  Icons.window, e.name, width, height),
            // Resize handle.
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onPanUpdate: (d) => _resizeRoom(room, d.delta, w, h),
                onPanEnd: (_) => ref.read(roomsProvider.notifier).save(room),
                child: Icon(Icons.open_in_full,
                    size: 16, color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A placed object inside a room, positioned by its room-local coordinates.
  Widget _chip(Room room, _Placeable item, FloorPosition? pos, IconData icon,
      String label, double roomW, double roomH) {
    final x = (pos?.x ?? 0.5) * roomW;
    final y = (pos?.y ?? 0.5) * roomH;
    final chip = Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: const StadiumBorder(),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
    return Positioned(
      left: (x - 20).clamp(0.0, roomW - 8),
      top: (y - 10).clamp(20.0, roomH - 8),
      child: Draggable<_Placeable>(
        data: item,
        feedback: Opacity(opacity: 0.85, child: chip),
        childWhenDragging: Opacity(opacity: 0.3, child: chip),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: roomW * 0.9),
          child: chip,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ palette
  Widget _palette(List<Plant> plants, List<HeatSource> heats,
      List<WindowObject> windows) {
    final items = <Widget>[
      for (final p in plants.where((p) => p.roomId == null))
        _paletteChip(_Placeable(_Kind.plant, p.id), Icons.local_florist, p.name),
      for (final e in heats.where((e) => e.roomId == null))
        _paletteChip(
            _Placeable(_Kind.heat, e.id), Icons.local_fire_department, e.name),
      for (final e in windows.where((e) => e.roomId == null))
        _paletteChip(_Placeable(_Kind.window, e.id), Icons.window, e.name),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        elevation: 4,
        child: SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(child: Text('Dra inn:', style: TextStyle(fontSize: 11))),
              ),
              ...items,
            ],
          ),
        ),
      ),
    );
  }

  Widget _paletteChip(_Placeable item, IconData icon, String label) {
    final chip = Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11)),
    );
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Draggable<_Placeable>(
        data: item,
        feedback: Material(color: Colors.transparent, child: chip),
        childWhenDragging: Opacity(opacity: 0.3, child: chip),
        child: chip,
      ),
    );
  }

  // -------------------------------------------------------------------- logic
  Offset _toCanvas(Offset global) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  void _finishDraw(double w, double h) {
    final start = _drawStart, end = _drawEnd;
    setState(() {
      _drawStart = null;
      _drawEnd = null;
      _drawMode = false;
    });
    if (start == null || end == null) return;
    final r = Rect.fromPoints(start, end);
    if (r.width < 24 || r.height < 24) return; // ignore stray taps
    final floors = ref.read(floorsProvider);
    final floorId =
        floors.any((f) => f.id == _floorId) ? _floorId! : floors.first.id;
    final rect = FloorRect(
      x: (r.left / w).clamp(0.0, 1.0),
      y: (r.top / h).clamp(0.0, 1.0),
      w: (r.width / w).clamp(0.05, 1.0),
      h: (r.height / h).clamp(0.05, 1.0),
    );
    _promptRoomName(rect, floorId);
  }

  Future<void> _promptRoomName(FloorRect rect, String floorId) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nytt rom'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Navn på rommet'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Lagre')),
        ],
      ),
    );
    if (name == null) return;
    final room = Room(
      id: uuid.v4(),
      name: name.trim().isEmpty ? 'Rom' : name.trim(),
      floorId: floorId,
      floorRect: rect,
    );
    await ref.read(roomsProvider.notifier).save(room);
  }

  void _placeExistingRoom(Room room, String floorId) {
    room.floorId = floorId;
    room.floorRect ??= const FloorRect(x: 0.35, y: 0.35, w: 0.3, h: 0.3);
    ref.read(roomsProvider.notifier).save(room);
  }

  void _moveRoom(Room room, Offset deltaPx, double w, double h) {
    final r = room.floorRect!;
    setState(() {
      room.floorRect = r.copyWith(
        x: (r.x + deltaPx.dx / w).clamp(0.0, 1.0 - r.w),
        y: (r.y + deltaPx.dy / h).clamp(0.0, 1.0 - r.h),
      );
    });
  }

  void _resizeRoom(Room room, Offset deltaPx, double w, double h) {
    final r = room.floorRect!;
    setState(() {
      room.floorRect = r.copyWith(
        w: (r.w + deltaPx.dx / w).clamp(0.08, 1.0 - r.x),
        h: (r.h + deltaPx.dy / h).clamp(0.08, 1.0 - r.y),
      );
    });
  }

  void _unplaceRoom(Room room) {
    room.floorId = null;
    room.floorRect = null;
    ref.read(roomsProvider.notifier).save(room);
  }

  /// Drop a palette/canvas object into [room] at the global [dropOffset].
  void _dropInto(Room room, _Placeable item, Offset dropOffset, double w,
      double h) {
    final rect = room.floorRect!;
    final local = _toCanvas(dropOffset);
    final nx = ((local.dx - rect.x * w) / (rect.w * w)).clamp(0.0, 1.0);
    final ny = ((local.dy - rect.y * h) / (rect.h * h)).clamp(0.0, 1.0);
    final pos = FloorPosition(x: nx, y: ny);

    switch (item.kind) {
      case _Kind.plant:
        final p = ref.read(plantsProvider.notifier).byId(item.id);
        if (p == null) return;
        p.roomId = room.id;
        p.floorPosition = pos;
        _maybeAskElevation(p);
        ref.read(plantsProvider.notifier).save(p);
      case _Kind.heat:
        final list = ref.read(heatSourcesProvider);
        final e = list.where((x) => x.id == item.id).firstOrNull;
        if (e == null) return;
        e.roomId = room.id;
        e.floorPosition = pos;
        ref.read(heatSourcesProvider.notifier).save(e);
      case _Kind.window:
        final list = ref.read(windowsProvider);
        final e = list.where((x) => x.id == item.id).firstOrNull;
        if (e == null) return;
        e.roomId = room.id;
        e.floorPosition = pos;
        ref.read(windowsProvider.notifier).save(e);
    }
  }

  /// When a plant is first placed, ask whether it stands on the floor or is
  /// raised (drives the heating-cable warm-from-below term in the water model).
  Future<void> _maybeAskElevation(Plant p) async {
    final onFloor = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hvor står planten?'),
        content: const Text(
            'Står planten på gulvet eller er den hevet (bord, hylle)? '
            'Dette påvirker om gulvvarme regnes inn i vanningsplanen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hevet')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('På gulvet')),
        ],
      ),
    );
    if (onFloor != null) p.onFloor = onFloor;
  }

  // -------------------------------------------------------------------- floors
  Future<void> _addFloor(List<Floor> floors) async {
    final nextLevel =
        floors.isEmpty ? 0 : floors.map((f) => f.level).reduce((a, b) => a > b ? a : b) + 1;
    final f = Floor(
      id: uuid.v4(),
      name: '${nextLevel + 1}. etasje',
      level: nextLevel,
    );
    await ref.read(floorsProvider.notifier).save(f);
    setState(() => _floorId = f.id);
  }

  Future<void> _renameFloor(Floor f) async {
    final c = TextEditingController(text: f.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gi nytt navn'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Lagre')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      f.name = name.trim();
      ref.read(floorsProvider.notifier).save(f);
    }
  }

  Future<void> _deleteFloor(Floor f, List<Room> rooms) async {
    final onFloor = rooms.where((r) => r.floorId == f.id).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Slette ${f.name}?'),
        content: Text(onFloor.isEmpty
            ? 'Etasjen fjernes fra planløsningen.'
            : '${onFloor.length} rom mister plasseringen sin (men beholdes i Rom-fanen).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Avbryt')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Slett')),
        ],
      ),
    );
    if (ok != true) return;
    for (final r in onFloor) {
      r.floorId = null;
      r.floorRect = null;
      await ref.read(roomsProvider.notifier).save(r);
    }
    await ref.read(floorsProvider.notifier).delete(f.id);
    if (_floorId == f.id) setState(() => _floorId = null);
  }
}

// --------------------------------------------------------------------- rail
class _FloorRail extends StatelessWidget {
  const _FloorRail({
    required this.floors,
    required this.selectedId,
    required this.onSelect,
    required this.onAdd,
    required this.onRename,
    required this.onDelete,
  });

  final List<Floor> floors;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<Floor> onRename;
  final ValueChanged<Floor> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 64,
      color: scheme.surfaceContainerHigh,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Top floor first (highest level) so the rail reads top-down.
                for (final f in floors.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    child: GestureDetector(
                      onLongPress: () => onRename(f),
                      child: InkWell(
                        onTap: () => onSelect(f.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: f.id == selectedId
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.layers, size: 18),
                              const SizedBox(height: 2),
                              Text(
                                f.name.split(' ').first,
                                style: const TextStyle(fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (f.id == selectedId)
                                InkWell(
                                  onTap: () => onDelete(f),
                                  child: const Icon(Icons.delete_outline,
                                      size: 14),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton.filledTonal(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              tooltip: 'Ny etasje',
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- empty
class _EmptyFloors extends StatelessWidget {
  const _EmptyFloors({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.architecture_outlined, size: 56),
            const SizedBox(height: 12),
            const Text('Ingen etasjer ennå'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Lag første etasje'),
            ),
          ],
        ),
      );
}
