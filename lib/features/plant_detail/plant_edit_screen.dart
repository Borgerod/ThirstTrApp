import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/plant_enums.dart';
import '../../data/providers.dart';
import '../../models/plant.dart';
import '../../models/species.dart';
import '../../services/mestergronn_api.dart';

/// Create or edit a plant. Covers the spec's info block: identity, room/window/
/// heat links, light, size/maturity/age, condition, price, receipt, hazards,
/// placement, draft/heat flags, and care-interval overrides.
class PlantEditScreen extends ConsumerStatefulWidget {
  const PlantEditScreen({
    super.key,
    this.existing,
    this.species,
    this.initialName,
    this.receiptPath,
  });

  final Plant? existing;
  final Species? species;
  final String? initialName;
  final String? receiptPath;

  @override
  ConsumerState<PlantEditScreen> createState() => _PlantEditScreenState();
}

class _PlantEditScreenState extends ConsumerState<PlantEditScreen> {
  late Plant _p;
  late bool _isNew;
  final _name = TextEditingController();
  final _height = TextEditingController();
  final _price = TextEditingController();
  final _tips = TextEditingController();
  final _info = TextEditingController();

  /// Care-interval override is OFF by default — the scheduler computes these.
  bool _overrideIntervals = false;

  /// Recommend watering on registration so the schedule starts in sync.
  bool _waterNow = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _isNew = e == null;
    _p = e ??
        Plant(
          id: uuid.v4(),
          name: widget.initialName ?? widget.species?.commonName ?? '',
          species: widget.species,
          receiptPath: widget.receiptPath,
        );
    if (_isNew) {
      // Sensible defaults for a freshly added plant.
      _p.relativeSize ??= RelativeSize.medium;
      _p.maturityBase ??= MaturityStage.mature;
      _p.condition ??= PlantCondition.healthy;
      _p.acquiredDate ??= DateTime.now();

      // Prefill the profile from the catalogue data (`??=` so anything the user
      // already set wins). Price is deliberately left for the user to enter.
      final sp = widget.species;
      if (sp != null) {
        _p.heightCm ??= sp.standardHeightCm; // standard height unless user-set
        if (sp.careTips.isNotEmpty) {
          _p.tips ??= sp.careTips.map((t) => '• $t').join('\n');
        }
        _p.generalInfo ??= sp.description;
      }
    }
    final iv = _p.intervals;
    _overrideIntervals = iv.waterDays != null ||
        iv.fertilizeDays != null ||
        iv.cleanDays != null ||
        iv.mistDays != null;

    _name.text = _p.name;
    _height.text = _p.heightCm?.toString() ?? '';
    _price.text = _p.priceNok?.toString() ?? '';
    _tips.text = _p.tips ?? '';
    _info.text = _p.generalInfo ?? '';
  }

  Future<void> _save() async {
    _p.name = _name.text.trim().isEmpty ? 'Plante' : _name.text.trim();
    _p.heightCm = double.tryParse(_height.text.replaceAll(',', '.'));
    _p.priceNok = double.tryParse(_price.text.replaceAll(',', '.'));
    _p.tips = _tips.text.trim().isEmpty ? null : _tips.text.trim();
    _p.generalInfo = _info.text.trim().isEmpty ? null : _info.text.trim();

    // Placement consistency: drop links that no longer apply so the model
    // never uses stale sources.
    if (_p.placement != RoomPlacement.window) _p.windowId = null;
    if (!_p.nearDraft) _p.draftWindowId = null;
    if (!_p.nearHeatSource) _p.heatSourceIds = const [];

    // If override is off, clear any interval values so the scheduler decides.
    if (!_overrideIntervals) {
      _p.intervals
        ..waterDays = null
        ..fertilizeDays = null
        ..cleanDays = null
        ..mistDays = null;
    }

    // Watering on registration keeps the schedule in sync with reality.
    if (_isNew && _waterNow) _p.lastWatered = DateTime.now();

    await ref.read(plantsProvider.notifier).save(_p);
    if (mounted) Navigator.of(context).pop(_p.id);
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomsProvider);
    final windows = ref
        .watch(windowsProvider)
        .where((w) =>
            _p.roomId == null || w.roomId == null || w.roomId == _p.roomId)
        .toList();
    final heats = ref.watch(heatSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Ny plante' : 'Rediger plante'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Lagre')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_p.species?.imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  MestergronnApi.displayImage(_p.species!.imageUrl)!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
            ),
          _field(_name, 'Kallenavn'),
          if (_p.species != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.eco),
              title: Text(_p.species!.commonName),
              subtitle: Text(_p.species!.scientificName.join(', ')),
            ),

          // --- Watering on registration recommendation ---
          if (_isNew)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Jeg vanner planten nå'),
                      subtitle: const Text(
                          'Anbefalt: vann ved registrering (selv om jorda er fuktig) '
                          'så vanningsplanen starter i synk.'),
                      value: _waterNow,
                      onChanged: (v) => setState(() => _waterNow = v ?? false),
                    ),
                  ],
                ),
              ),
            ),

          _sectionTitle('Plassering'),
          _dropdown<String?>(
            'Rom',
            _p.roomId,
            [
              const DropdownMenuItem(value: null, child: Text('Uten rom')),
              for (final r in rooms)
                DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            (v) => setState(() => _p.roomId = v),
          ),
          _dropdown<RoomPlacement?>(
            'Plassering i rom',
            _p.placement,
            [
              const DropdownMenuItem(value: null, child: Text('Ikke satt')),
              for (final pl in RoomPlacement.values)
                DropdownMenuItem(value: pl, child: Text(pl.label)),
            ],
            (v) => setState(() => _p.placement = v),
          ),
          // The window link only makes sense for a plant standing by one.
          if (_p.placement == RoomPlacement.window)
            _dropdown<String?>(
              'Hvilket vindu?',
              _p.windowId,
              [
                const DropdownMenuItem(value: null, child: Text('Ikke valgt')),
                for (final w in windows)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              (v) => setState(() => _p.windowId = v),
            ),

          // Elevation: a pot on a heated floor is warmed from below.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('Hevet fra gulv'),
                    icon: Icon(Icons.table_bar_outlined)),
                ButtonSegment(
                    value: true,
                    label: Text('På gulvet'),
                    icon: Icon(Icons.south)),
              ],
              selected: {_p.onFloor},
              onSelectionChanged: (s) => setState(() => _p.onFloor = s.first),
            ),
          ),
          if (_p.onFloor &&
              heats.any((h) =>
                  h.roomId == _p.roomId && h.type == HeatType.heatingCable))
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                'Gulvvarmen i rommet varmer pottebunnen — regnes inn i '
                'vanningsestimatet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nær trekk / luftstrøm'),
            value: _p.nearDraft,
            onChanged: (v) => setState(() => _p.nearDraft = v),
          ),
          if (_p.nearDraft)
            _dropdown<String?>(
              'Trekk fra hvilket vindu?',
              _p.draftWindowId,
              [
                const DropdownMenuItem(
                    value: null, child: Text('Annet / ukjent (dør, ventil …)')),
                for (final w in windows)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              (v) => setState(() => _p.draftWindowId = v),
            ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nær varmekilde'),
            subtitle: const Text(
                'Varmekabler telles automatisk med i romtemperaturen og '
                'velges ikke her.'),
            value: _p.nearHeatSource,
            onChanged: (v) => setState(() => _p.nearHeatSource = v),
          ),
          if (_p.nearHeatSource) ...[
            // Pick WHICH radiant sources it stands near — room's own first.
            Builder(builder: (context) {
              final selectable = heats
                  .where((h) =>
                      h.type != HeatType.heatingCable &&
                      (_p.roomId == null || h.roomId == _p.roomId))
                  .toList();
              if (selectable.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    'Ingen varmekilder i dette rommet — legg til under '
                    '«Rom & objekter».',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final h in selectable)
                      FilterChip(
                        label: Text(h.name),
                        selected: _p.heatSourceIds.contains(h.id),
                        onSelected: (sel) => setState(() {
                          final list = [..._p.heatSourceIds];
                          sel ? list.add(h.id) : list.remove(h.id);
                          _p.heatSourceIds = list;
                        }),
                      ),
                  ],
                ),
              );
            }),
          ],

          _sectionTitle('Lys'),
          _dropdown<LightIntensity?>(
            'Lysintensitet',
            _p.lightIntensity,
            [
              const DropdownMenuItem(
                  value: null, child: Text('Estimer automatisk')),
              for (final l in LightIntensity.values)
                DropdownMenuItem(value: l, child: Text(l.label)),
            ],
            (v) => setState(() => _p.lightIntensity = v),
          ),

          _sectionTitle('Størrelse, modenhet og alder'),
          _field(_height, 'Høyde (cm)', keyboard: TextInputType.number),
          _dropdown<RelativeSize>(
            'Relativ størrelse',
            _p.relativeSize ?? RelativeSize.medium,
            [
              for (final s in RelativeSize.values)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            (v) => setState(() => _p.relativeSize = v),
          ),
          _dropdown<MaturityStage>(
            'Modenhet ved anskaffelse',
            _p.maturityBase ?? MaturityStage.mature,
            [
              for (final m in MaturityStage.values)
                DropdownMenuItem(value: m, child: Text(m.label)),
            ],
            (v) => setState(() => _p.maturityBase = v),
          ),
          if (_p.maturity != null && _p.maturity != _p.maturityBase)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                'Nå: ${_p.maturity!.label} (oppdateres automatisk med alder)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Anskaffet'),
            subtitle: Text(_p.acquiredDate == null
                ? 'Ikke satt'
                : '${_p.acquiredDate!.day}.${_p.acquiredDate!.month}.${_p.acquiredDate!.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _p.acquiredDate ?? DateTime.now(),
                firstDate: DateTime(1990),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _p.acquiredDate = d);
            },
          ),

          _sectionTitle('Tilstand, pris og kvittering'),
          _dropdown<PlantCondition?>(
            'Tilstand',
            _p.condition,
            [
              const DropdownMenuItem(value: null, child: Text('Ikke satt')),
              for (final c in PlantCondition.values)
                DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            (v) => setState(() => _p.condition = v),
          ),
          _field(_price, 'Pris (NOK)', keyboard: TextInputType.number),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.receipt_long),
            title: Text(
                _p.receiptPath == null ? 'Ingen kvittering' : 'Kvittering lagret'),
            subtitle: _p.receiptPath == null ? null : Text(_p.receiptPath!),
          ),

          // --- Hazards: read-only, from the species database ---
          _sectionTitle('Farer (fra artsdatabasen)'),
          _hazardRow('Giftig for kjæledyr', _p.species?.poisonousToPets),
          _hazardRow('Farlig for barn', _p.species?.poisonousToHumans),

          // --- Care intervals: discouraged manual override ---
          _sectionTitle('Stell-intervaller'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Anbefalt: la appen beregne dette. Den tar hensyn til lys, '
                      'sesong, vær, romtemperatur, varmekilder og trekk. Overstyr '
                      'kun hvis du vet bedre.',
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Overstyr manuelt'),
                    value: _overrideIntervals,
                    onChanged: (v) => setState(() => _overrideIntervals = v),
                  ),
                  if (_overrideIntervals) ...[
                    _intervalField('Vanning hver (dager)', _p.intervals.waterDays,
                        (v) => _p.intervals.waterDays = v),
                    _intervalField(
                        'Gjødsling hver (dager)',
                        _p.intervals.fertilizeDays,
                        (v) => _p.intervals.fertilizeDays = v),
                    _intervalField(
                        'Rengjøring hver (dager) — la stå tom hvis ikke nødvendig',
                        _p.intervals.cleanDays,
                        (v) => _p.intervals.cleanDays = v),
                    _intervalField('Spraying hver (dager)', _p.intervals.mistDays,
                        (v) => _p.intervals.mistDays = v),
                  ],
                ],
              ),
            ),
          ),

          _sectionTitle('Notater'),
          _field(_info, 'Generell info', maxLines: 3),
          _field(_tips, 'Tips', maxLines: 3),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Lagre plante'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _hazardRow(String label, bool? value) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          value == true ? Icons.warning_amber : Icons.check_circle_outline,
          color: value == true ? Theme.of(context).colorScheme.error : null,
        ),
        title: Text(label),
        trailing: Text(value == null
            ? 'Ukjent'
            : value
                ? 'Ja'
                : 'Nei'),
      );

  Widget _field(TextEditingController c, String label,
          {TextInputType? keyboard, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          maxLines: maxLines,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
        ),
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 4),
        child: Text(t,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold)),
      );

  Widget _dropdown<T>(String label, T value, List<DropdownMenuItem<T>> items,
          ValueChanged<T?> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      );

  Widget _intervalField(String label, int? value, ValueChanged<int?> onSet) {
    final c = TextEditingController(text: value?.toString() ?? '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
            labelText: label,
            hintText: 'Auto',
            border: const OutlineInputBorder()),
        onChanged: (t) => onSet(int.tryParse(t)),
      ),
    );
  }
}
