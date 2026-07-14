import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import '../../models/plant.dart';
import '../../services/evapotranspiration.dart';
import '../../services/mestergronn_api.dart';
import '../../services/scheduler.dart';
import '../widgets/care_circles.dart';
import 'plant_edit_screen.dart';

class PlantDetailScreen extends ConsumerWidget {
  const PlantDetailScreen({super.key, required this.plantId});
  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plant = ref.watch(plantsProvider.notifier).byId(plantId);
    if (plant == null) {
      return const Scaffold(body: Center(child: Text('Plante slettet')));
    }
    final plans = ref.watch(plantPlansProvider(plantId))
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final rooms = {for (final r in ref.watch(roomsProvider)) r.id: r.name};

    return Scaffold(
      appBar: AppBar(
        title: Text(plant.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlantEditScreen(existing: plant))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref, plant),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (plant.species?.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                  MestergronnApi.displayImage(plant.species!.imageUrl)!,
                  height: 200, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox()),
            ),
          const SizedBox(height: 12),
          Text(plant.species?.commonName ?? 'Ukjent art',
              style: Theme.of(context).textTheme.titleMedium),
          if (plant.species?.scientificName.isNotEmpty ?? false)
            Text(plant.species!.scientificName.join(', '),
                style: const TextStyle(fontStyle: FontStyle.italic)),

          const SizedBox(height: 16),
          _careCard(context, ref, plant, plans),

          const SizedBox(height: 16),
          _SectionCard(title: 'Plassering', rows: [
            _row('Rom', plant.roomId == null ? '–' : rooms[plant.roomId] ?? '–'),
            _row('Plassering', plant.placement?.label ?? '–'),
            _row(
                'Lys',
                Scheduler.resolveLight(
                        ref.watch(careContextProvider(plantId)) ??
                            CareContext(plant: plant))
                    .label),
            _row('Underlag', plant.onFloor ? 'På gulvet' : 'Hevet fra gulv'),
            _row('Nær trekk', (plant.nearDraft) ? 'Ja' : 'Nei'),
            _row('Nær varmekilde', (plant.nearHeatSource) ? 'Ja' : 'Nei'),
          ]),

          _SectionCard(title: 'Størrelse & alder', rows: [
            _row('Høyde', plant.heightCm == null ? '–' : '${plant.heightCm} cm'),
            _row('Relativ størrelse', plant.relativeSize?.label ?? '–'),
            _row('Modenhet', plant.maturity?.label ?? '–'),
            _row('Alder', Fmt.age(plant.age)),
            _row('Anskaffet', Fmt.dateFull(plant.acquiredDate)),
          ]),

          _SectionCard(title: 'Tilstand & økonomi', rows: [
            _row('Tilstand', plant.condition?.label ?? '–'),
            _row('Pris',
                plant.priceNok == null ? '–' : '${plant.priceNok} kr'),
          ]),
          if (plant.receiptPath != null) _receipt(plant),

          _SectionCard(title: 'Farer (fra artsdatabasen)', rows: [
            _row('Giftig for kjæledyr',
                _hazard(plant.species?.poisonousToPets)),
            _row('Farlig for barn', _hazard(plant.species?.poisonousToHumans)),
          ]),

          if (plant.species != null) _aboutCard(context, plant),

          if ((plant.species?.careTips.isNotEmpty ?? false) ||
              (plant.species?.careGuide.isNotEmpty ?? false))
            _careGuideCard(context, plant),

          if (plant.species != null) _PestDiseaseCard(speciesId: plant.species!.id),

          if (plant.generalInfo != null || plant.tips != null)
            _SectionCard(title: 'Notater', rows: [
              if (plant.generalInfo != null) _row('Info', plant.generalInfo!),
              if (plant.tips != null) _row('Tips', plant.tips!),
            ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _careCard(BuildContext context, WidgetRef ref, Plant plant,
      List<CarePlan> plans) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stell',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (plant.species != null) ...[
              const SizedBox(height: 12),
              CareCircles(species: plant.species!),
            ],
            const SizedBox(height: 8),
            for (final plan in plans)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(plan.type.icon, size: 24),
                title: Row(
                  children: [
                    Text(plan.type.label),
                    if (plan.quality == ClimateSource.statistical) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Usikkert anslag — mangler data.\n'
                            'Legg til rom, vindu, varmekilder eller '
                            'hjemsted for et bedre estimat.',
                        child: Icon(Icons.warning_amber_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                    'Hver ${plan.intervalDays}. dag · ${Fmt.relativeDue(plan.nextDue)}'),
                trailing: FilledButton.tonal(
                  onPressed: () => ref
                      .read(plantsProvider.notifier)
                      .markCareDone(plant.id, plan.type),
                  child: const Text('Utført'),
                ),
                onTap: () => _showFactors(context, plan),
              ),
          ],
        ),
      ),
    );
  }

  void _showFactors(BuildContext context, CarePlan plan) {
    // Prefer the rich physics breakdown; fall back to legacy multipliers.
    final rows = plan.details ??
        plan.factors.entries
            .map((e) => MapEntry(e.key, '×${e.value.toStringAsFixed(2)}'))
            .toList();
    if (rows.isEmpty) return;
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hvorfor hver ${plan.intervalDays}. dag?',
                  style: Theme.of(context).textTheme.titleMedium),
              if (plan.type == CareType.water)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Estimert med Penman-Monteith fordampningsmodell.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (plan.quality == ClimateSource.statistical)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: scheme.onErrorContainer, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bygger delvis på statistiske antakelser. Legg til '
                          'rom-temperatur, vindu, varmekilder eller hjemsted '
                          'for et sikrere anslag.',
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              for (final e in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(e.key)),
                      const SizedBox(width: 12),
                      Text(e.value,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _careGuideCard(BuildContext context, Plant plant) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stelletips (Mestergrønn)',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            CareCircles(species: plant.species!),
            const SizedBox(height: 12),
            for (final tip in plant.species!.careTips) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(tip)),
                ],
              ),
              const SizedBox(height: 4),
            ],
            // Legacy Perenual-style guide, if any snapshot still has it.
            for (final e in plant.species!.careGuide.entries) ...[
              Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(e.value),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  /// Expanded species info from the API (description + key facts).
  Widget _aboutCard(BuildContext context, Plant plant) {
    final s = plant.species!;
    final facts = <MapEntry<String, String>>[
      if (s.cycle != null) _row('Syklus', s.cycle!),
      if (s.careLevel != null) _row('Stellnivå', s.careLevel!),
      if (s.wateringWord != null) _row('Vanning', s.wateringWord!),
      if (s.sunlight.isNotEmpty) _row('Sollys', s.sunlight.join(', ')),
      if (s.indoor != null) _row('Innendørs', s.indoor! ? 'Ja' : 'Nei'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Om arten',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (s.description != null) ...[
              Text(s.description!),
              const SizedBox(height: 8),
            ],
            for (final f in facts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 130,
                        child: Text(f.key,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant))),
                    Expanded(child: Text(f.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _receipt(Plant plant) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kvittering',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(plant.receiptPath!),
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Text('Bilde ikke tilgjengelig')),
              ),
            ],
          ),
        ),
      );

  static String _hazard(bool? v) =>
      v == null ? 'Ukjent' : (v ? 'Ja' : 'Nei');

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Plant plant) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Slette ${plant.name}?'),
        content: const Text('Dette kan ikke angres.'),
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
    if (ok == true && context.mounted) {
      await ref.read(plantsProvider.notifier).delete(plant.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

MapEntry<String, String> _row(String k, String v) => MapEntry(k, v);

/// Pests & diseases relevant to the species (from Perenual).
class _PestDiseaseCard extends ConsumerWidget {
  const _PestDiseaseCard({required this.speciesId});
  final int speciesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pestDiseaseProvider(speciesId));
    return async.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Skadedyr & sykdommer',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  'Vanlige for arten. Regionsbasert filtrering er ikke '
                  'tilgjengelig fra API-et ennå.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (final pd in list.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            pd['common_name'],
                            if (pd['type'] != null) '(${pd['type']})',
                          ].where((e) => e != null).join(' '),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (_firstDescription(pd) != null)
                          Text(_firstDescription(pd)!,
                              maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String? _firstDescription(Map<String, dynamic> pd) {
    final desc = pd['description'];
    if (desc is String && desc.isNotEmpty) return desc;
    if (desc is List && desc.isNotEmpty) {
      final first = desc.first;
      if (first is Map) return first['description']?.toString();
    }
    return null;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});
  final String title;
  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 130,
                          child: Text(r.key,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant))),
                      Expanded(child: Text(r.value)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
}
