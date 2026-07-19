import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/format.dart';
import '../../core/plant_enums.dart';
import '../../data/providers.dart';
import '../../models/plant.dart';
import '../../models/species.dart';
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

    // Profile is the simple quick view; detail lives in the two extra tabs.
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
          bottom: const TabBar(tabs: [
            Tab(text: 'Profil'),
            Tab(text: 'Stelletips'),
            Tab(text: 'Om arten'),
          ]),
        ),
        body: TabBarView(children: [
          _profileTab(context, ref, plant, plans, rooms),
          _StelletipsTab(species: plant.species),
          _aboutTab(context, plant),
        ]),
      ),
    );
  }

  // ------------------------------- Profil (quick view) ---------------------

  Widget _profileTab(BuildContext context, WidgetRef ref, Plant plant,
      List<CarePlan> plans, Map<String, String> rooms) {
    return ListView(
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

        // User-only notes: the app never writes here, only displays.
        if (plant.generalInfo != null || plant.tips != null)
          _SectionCard(title: 'Mine notater', rows: [
            if (plant.generalInfo != null) _row('Info', plant.generalInfo!),
            if (plant.tips != null) _row('Tips', plant.tips!),
          ]),
        const SizedBox(height: 32),
      ],
    );
  }

  // ------------------------------- Om arten (+ farer) ----------------------

  Widget _aboutTab(BuildContext context, Plant plant) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (plant.species != null) _aboutCard(context, plant),

        _SectionCard(title: 'Farer (fra artsdatabasen)', rows: [
          _row('Giftig for kjæledyr',
              _hazard(plant.species?.poisonousToPets)),
          _row('Farlig for barn', _hazard(plant.species?.poisonousToHumans)),
        ]),

        if (plant.species != null)
          _PestDiseaseCard(speciesId: plant.species!.id),
        const SizedBox(height: 32),
      ],
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

/// The "Stelletips" tab: the four mini circles stay the quick overview at the
/// top; below them each care dimension is expanded into a descriptive,
/// instructional paragraph derived from the species data.
class _StelletipsTab extends StatelessWidget {
  const _StelletipsTab({required this.species});
  final Species? species;

  @override
  Widget build(BuildContext context) {
    final s = species;
    if (s == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Ingen artsdata for denne planten ennå.\n'
            'Koble planten til en art for å få stelletips.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kort oppsummert',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                CareCircles(species: s),
              ],
            ),
          ),
        ),
        _instruction(context,
            icon: Icons.wb_sunny_outlined,
            title: 'Lys',
            body: _lightText(s)),
        _instruction(context,
            icon: Icons.water_drop_outlined,
            title: 'Vanning',
            body: _waterText(s)),
        _instruction(context,
            icon: Icons.eco_outlined,
            title: 'Gjødsling',
            body: _fertilizeText(s)),
        _instruction(context,
            icon: s.careTag.icon,
            title: s.careTag.label,
            body: _tagText(s.careTag)),
        if (s.careTips.isNotEmpty)
          _instruction(context,
              icon: Icons.tips_and_updates_outlined,
              title:
                  'Fra ${s.source == 'plantasjen' ? 'Plantasjen' : 'Mestergrønn'}',
              body: s.careTips.map((t) => '• $t').join('\n')),
        // Legacy Perenual-style guide, if any snapshot still has it.
        for (final e in s.careGuide.entries)
          _instruction(context,
              icon: Icons.menu_book_outlined, title: e.key, body: e.value),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _instruction(BuildContext context,
      {required IconData icon, required String title, required String body}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }

  static String _lightText(Species s) => switch (s.lightExposure) {
        LightIntensity.direct =>
          'Denne planten trives med direkte sollys. Gi den en plass helt '
              'inntil et sør- eller vestvendt vindu der solen treffer bladene '
              'flere timer om dagen. Snu potten av og til så veksten blir jevn.',
        LightIntensity.indirect =>
          'Denne planten foretrekker lyst, men indirekte lys. Plasser den '
              'nær et vindu, men unngå sterk middagssol rett på bladene — et '
              'øst-vindu eller litt inne i rommet fra et sør-vindu er ideelt. '
              'For lite lys gir blek og strukket vekst.',
        LightIntensity.shaded =>
          'Denne planten tåler skygge godt og klarer seg lengre inn i rommet '
              'eller mot nordvendte vinduer. Unngå direkte sol, som kan svi '
              'bladene. Vokser saktere i lite lys — det er normalt.',
      };

  static String _waterText(Species s) {
    final level = switch (s.wateringLevel) {
      Level.high =>
        'Planten drikker mye og vil ha jevnt fuktig jord. La bare det '
            'øverste laget tørke mellom hver vanning, og sjekk oftere i '
            'varme og lyse perioder.',
      Level.medium =>
        'Planten har et moderat vannbehov. Vann når de øverste par '
            'centimeterne av jorden kjennes tørre, og la overflødig vann '
            'renne ut — den skal ikke stå i vann.',
      Level.low =>
        'Planten trenger lite vann og tåler tørke bedre enn overvanning. '
            'La jorden tørke godt ut mellom hver vanning, og vann heller for '
            'sjelden enn for ofte.',
    };
    return '$level\n\nSom utgangspunkt ca. hver ${s.baseWateringDays}. dag — '
        'appens vanningsplan justerer dette automatisk etter rom, lys og '
        'klima.';
  }

  static String _fertilizeText(Species s) => switch (s.fertilizingLevel) {
        Level.high =>
          'Rask vekst krever næring: gjødsle regelmessig i vekstsesongen '
              '(vår–sommer) med flytende gjødsel i vanlig dose. Trapp ned '
              'utover høsten og hopp over vinteren.',
        Level.medium =>
          'Gi litt flytende gjødsel omtrent hver 3.–4. uke i vekstsesongen '
              '(vår–sommer). Om vinteren hviler planten og klarer seg uten.',
        Level.low =>
          'Nøysom plante — gjødsle sparsomt, et par ganger i løpet av '
              'vekstsesongen holder. For mye gjødsel gjør mer skade enn for '
              'lite.',
      };

  static String _tagText(CareTag tag) => switch (tag) {
        CareTag.easyCare =>
          'En robust og tilgivende plante som tåler litt glemsel. Følg '
              'vanningsplanen, så ordner resten seg stort sett selv.',
        CareTag.hardCare =>
          'Dette er en krevende plante. Følg vanningsplanen nøye, hold '
              'stabile forhold (unngå flytting, trekk og brå '
              'temperaturendringer), og sjekk bladene jevnlig for tidlige '
              'tegn på mistrivsel.',
        CareTag.needsShower =>
          'Planten setter pris på en dusj i ny og ne: skyll bladene med '
              'lunkent vann for å fjerne støv og holde bladverket friskt. '
              'Støvfrie blader tar også opp mer lys.',
        CareTag.lovesSoaking =>
          'Planten elsker bløtlegging: senk potten i lunkent vann til det '
              'slutter å boble, og la den renne godt av før den settes '
              'tilbake. Fin metode når jorden har tørket helt ut.',
        CareTag.humidityLover =>
          'Planten trives med høy luftfuktighet. Dusj bladene med en '
              'forstøver, sett den på et brett med fuktig leca, eller '
              'plasser den på badet. Unngå plassering rett over en varm ovn.',
        CareTag.droughtTolerant =>
          'Planten tåler tørke godt — den lagrer vann og tilgir en glemt '
              'vanning. Den største risikoen er råte fra overvanning, så la '
              'jorden tørke ordentlig ut mellom hver gang.',
        CareTag.toxic =>
          'Planten er giftig. Plasser den utilgjengelig for barn og '
              'kjæledyr, og vask hendene etter stell og beskjæring.',
      };
}

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
