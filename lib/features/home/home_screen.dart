import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import '../../models/plant.dart';
import '../../models/room.dart';
import '../add_plant/add_plant_screen.dart';
import '../plant_detail/plant_detail_screen.dart';
import '../rooms/rooms_screen.dart';

/// Plant portfolio. Flat list or grouped by room, toggled in the app bar
/// (and persisted in settings).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plants = ref.watch(plantsProvider);
    final rooms = ref.watch(roomsProvider);
    final settings = ref.watch(settingsProvider);
    final view = settings.portfolioView;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mine planter'),
        actions: [
          IconButton(
            tooltip: 'Rom og objekter',

            // icon: const Icon(Icons.meeting_room_outlined),
            // icon: const Icon(Icons.home),
            // icon: const Icon(Icons.home_rounded),
            icon: const Icon(Icons.add_home_outlined),
            // icon: const Icon(Icons.view_in_ar_outlined),

            // icon: const Icon(Icons.loyalty_outlined), //! usefull
            // icon: const Icon(
            //   Icons.signal_cellular_connected_no_internet_0_bar_rounded,
            // ),
            // icon: const Icon(Icons.account_tree_outlined),
            // icon: const Icon(Icons.space_dashboard_outlined),

            // icon: const Icon(Icons.crop_free),
            // icon: const Icon(Icons.crop_square),
            // icon: const Icon(Icons.map_outlined),
            // icon: const Icon(Icons.view_comfortable_outlined),
            // icon: const Icon(Icons.view_quilt_outlined),

            // icon: const Icon(Icons.home),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RoomsScreen())),
          ),
          IconButton(
            tooltip: 'Neste visning: ${view.next.label}',
            // icon: const Icon(Icons.architecture_outlined),
            // icon: const Icon(Icons.meeting_room_outlined),
            // icon: const Icon(Icons.chair_outlined),
            // icon: const Icon(Icons.home_outlined),
            // icon: const Icon(Icons.home_filled),
            icon: Icon(
              switch (view) {
                PortfolioView.groupByView => Icons.dashboard_outlined,
                PortfolioView.groupByRoom => Icons.view_headline_outlined,
                // ADD THIS FOR room_view : Icons.home_outlined
                PortfolioView.roomView => Icons.home_outlined,
              },
            ),
            onPressed: () => ref
                .read(settingsProvider.notifier)
                .update(settings.copyWith(portfolioView: view.next)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddPlantScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Legg til'),
      ),
      body: switch (view) {
        // Floorplan room view renders regardless of whether plants exist.
        PortfolioView.roomView => _RoomView(plants: plants, rooms: rooms),
        _ when plants.isEmpty => const _EmptyState(),
        PortfolioView.groupByRoom => _GroupedList(plants: plants, rooms: rooms),
        PortfolioView.groupByView => _FlatList(plants: plants),
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.eco_outlined, size: 72),
          const SizedBox(height: 16),
          Text(
            'Ingen planter ennå',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Trykk «Legg til» for å registrere din første plante.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _FlatList extends StatelessWidget {
  const _FlatList({required this.plants});
  final List<Plant> plants;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 96),
    children: [for (final p in plants) PlantTile(plant: p)],
  );
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.plants, required this.rooms});
  final List<Plant> plants;
  final List<Room> rooms;

  @override
  Widget build(BuildContext context) {
    final byRoom = <String?, List<Plant>>{};
    for (final p in plants) {
      byRoom.putIfAbsent(p.roomId, () => []).add(p);
    }
    final roomName = {for (final r in rooms) r.id: r.name};

    final sections = byRoom.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return (roomName[a] ?? '').compareTo(roomName[b] ?? '');
      });

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final roomId in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              roomId == null ? 'Uten rom' : (roomName[roomId] ?? 'Rom'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          for (final p in byRoom[roomId]!) PlantTile(plant: p),
        ],
      ],
    );
  }
}

/// Floorplan room view — placeholder until the blueprint/map UI is built.
/// Shows rooms as cards with their plant counts for now.
class _RoomView extends StatelessWidget {
  const _RoomView({required this.plants, required this.rooms});
  final List<Plant> plants;
  final List<Room> rooms;

  @override
  Widget build(BuildContext context) {
    final count = <String?, int>{};
    for (final p in plants) {
      count[p.roomId] = (count[p.roomId] ?? 0) + 1;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.home_outlined),
              const SizedBox(width: 8),
              Text(
                'Planløsning (kommer)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final r in rooms)
                Card(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          r.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${count[r.id] ?? 0} planter'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single plant row with thumbnail + soonest care badge.
class PlantTile extends ConsumerWidget {
  const PlantTile({super.key, required this.plant});
  final Plant plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plantPlansProvider(plant.id));
    plans.sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final next = plans.isEmpty ? null : plans.first;
    final overdue = next?.isOverdue ?? false;

    return ListTile(
      leading: CircleAvatar(
        radius: 26,
        backgroundImage: (plant.species?.imageUrl != null)
            ? NetworkImage(plant.species!.imageUrl!)
            : null,
        child: plant.species?.imageUrl == null
            ? const Icon(Icons.local_florist)
            : null,
      ),
      title: Text(plant.name),
      subtitle: Text(plant.species?.commonName ?? 'Ukjent art'),
      trailing: next == null
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${next.type.emoji} ${next.type.label}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  Fmt.relativeDue(next.nextDue),
                  style: TextStyle(
                    color: overdue ? Theme.of(context).colorScheme.error : null,
                    fontWeight: overdue ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: plant.id)),
      ),
    );
  }
}
