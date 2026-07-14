import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/providers.dart';
import '../../models/care_task.dart';

/// Care queue: overdue + upcoming watering/fertilizing/cleaning tasks, each
/// with confirm ("Fullført") and postpone actions — mirrors the notification.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider.notifier).dueSoon;
    final plants = {for (final p in ref.watch(plantsProvider)) p.id: p};

    final overdue = tasks.where((t) => t.isOverdue).toList();
    final today = tasks
        .where((t) => !t.isOverdue && t.isDueWithin(const Duration(days: 1)))
        .toList();
    final upcoming = tasks
        .where((t) => !t.isOverdue && !t.isDueWithin(const Duration(days: 1)))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oppgaver'),
        actions: [
          IconButton(
            tooltip: 'Oppdater planer',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(tasksProvider.notifier).rebuildAll(),
          ),
        ],
      ),
      body: tasks.isEmpty
          ? const Center(child: Text('Ingenting å gjøre'))
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _section(context, 'Forsinket', overdue, plants, ref,
                    color: Theme.of(context).colorScheme.error),
                _section(context, 'I dag / i morgen', today, plants, ref),
                _section(context, 'Kommende', upcoming, plants, ref),
              ],
            ),
    );
  }

  Widget _section(BuildContext context, String title, List<CareTask> items,
      Map<String, dynamic> plants, WidgetRef ref,
      {Color? color}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color)),
        ),
        for (final t in items)
          _TaskTile(task: t, plantName: plants[t.plantId]?.name ?? 'Plante'),
      ],
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, required this.plantName});
  final CareTask task;
  final String plantName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(tasksProvider.notifier);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Icon(task.type.icon, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$plantName · ${task.type.label}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(Fmt.relativeDue(task.dueDate),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            TextButton(
              onPressed: () => ctrl.postponeTask(task.id),
              child: const Text('Utsett'),
            ),
            FilledButton(
              onPressed: () => ctrl.completeTask(task.id),
              child: const Text('Fullført'),
            ),
          ],
        ),
      ),
    );
  }
}
