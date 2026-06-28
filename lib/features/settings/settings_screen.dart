import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/enums.dart';
import '../../data/providers.dart';
import '../../services/weather_api.dart';

/// Preferences: units, home location (drives weather), Perenual API key,
/// notification options.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final weather = ref.watch(weatherProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Innstillinger')),
      body: ListView(
        children: [
          const _Header('Generelt'),
          ListTile(
            title: const Text('Enheter'),
            subtitle: Text(s.units.label),
            trailing: DropdownButton<UnitSystem>(
              value: s.units,
              onChanged: (v) =>
                  v == null ? null : ctrl.update(s.copyWith(units: v)),
              items: [
                for (final u in UnitSystem.values)
                  DropdownMenuItem(value: u, child: Text(u.label)),
              ],
            ),
          ),

          const _Header('Hjemsted (vær & klima)'),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(s.locationName ?? 'Ikke satt'),
            subtitle: weather.when(
              data: (w) => w == null
                  ? const Text('Sett sted for værbaserte justeringer')
                  : Text(
                      '${w.temperatureC.round()}°C · ${w.humidityPct.round()}% fukt · ${w.windKmh.round()} km/t vind'),
              loading: () => const Text('Henter vær …'),
              error: (_, _) => const Text('Kunne ikke hente vær'),
            ),
            trailing: const Icon(Icons.edit),
            onTap: () => _pickLocation(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('Bruk min posisjon'),
            subtitle: const Text('Hent hjemsted fra GPS'),
            onTap: () => _useCurrentLocation(context, ref),
          ),
          SwitchListTile(
            title: const Text('Bruk vær til å justere vanning'),
            value: s.useWeatherAdjustment,
            onChanged: (v) =>
                ctrl.update(s.copyWith(useWeatherAdjustment: v)),
          ),

          const _Header('Perenual API'),
          ListTile(
            leading: Icon(s.hasApiKey ? Icons.key : Icons.key_off,
                color: s.hasApiKey ? Colors.green : null),
            title: const Text('API-nøkkel'),
            subtitle: Text(s.hasApiKey
                ? 'Satt (•••${s.perenualApiKey.length > 3 ? s.perenualApiKey.substring(s.perenualApiKey.length - 3) : ''})'
                : 'Mangler — søk i artsdatabasen krever nøkkel'),
            trailing: const Icon(Icons.edit),
            onTap: () => _editApiKey(context, ref),
          ),

          const _Header('Varsler'),
          SwitchListTile(
            title: const Text('Påminnelser'),
            value: s.notificationsEnabled,
            onChanged: (v) async {
              await ctrl.update(s.copyWith(notificationsEnabled: v));
              await ref.read(tasksProvider.notifier).rebuildAll();
            },
          ),
          ListTile(
            title: const Text('Varslingstidspunkt'),
            subtitle: Text('${s.notifyHour.toString().padLeft(2, '0')}:00'),
            trailing: const Icon(Icons.schedule),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: s.notifyHour, minute: 0),
              );
              if (t != null) {
                await ctrl.update(s.copyWith(notifyHour: t.hour));
                await ref.read(tasksProvider.notifier).rebuildAll();
              }
            },
          ),
          const SizedBox(height: 24),
          const Center(
              child: Text('ThirstTrApp · V1',
                  style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _editApiKey(BuildContext context, WidgetRef ref) async {
    final s = ref.read(settingsProvider);
    final c = TextEditingController(text: s.perenualApiKey);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Perenual API-nøkkel'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
              hintText: 'Lim inn nøkkel fra perenual.com'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Avbryt')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Lagre')),
        ],
      ),
    );
    if (result != null) {
      await ref
          .read(settingsProvider.notifier)
          .update(s.copyWith(perenualApiKey: result));
    }
  }

  Future<void> _pickLocation(BuildContext context, WidgetRef ref) async {
    final place = await showDialog<GeoPlace>(
      context: context,
      builder: (_) => const _LocationDialog(),
    );
    if (place != null) {
      final s = ref.read(settingsProvider);
      await ref.read(settingsProvider.notifier).update(s.copyWith(
            locationName: place.name,
            latitude: place.latitude,
            longitude: place.longitude,
          ));
      ref.invalidate(weatherProvider);
      await ref.read(tasksProvider.notifier).rebuildAll();
    }
  }

  /// Get home location from GPS. Shows a GDPR rationale first (why we need it),
  /// then requests permission and resolves coordinates → place name.
  Future<void> _useCurrentLocation(BuildContext context, WidgetRef ref) async {
    final consent = await _locationRationale(context);
    if (consent != true) return;

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (context.mounted) {
        _toast(context, 'Slå på posisjonstjenester på enheten.');
      }
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (context.mounted) {
        _toast(context, 'Posisjon avslått. Du kan endre dette i innstillinger.');
      }
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    String? name;
    try {
      name = await ref
          .read(weatherApiProvider)
          .reverseGeocode(pos.latitude, pos.longitude);
    } catch (_) {}

    final s = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).update(s.copyWith(
          locationName: name ?? 'Min posisjon',
          latitude: pos.latitude,
          longitude: pos.longitude,
        ));
    ref.invalidate(weatherProvider);
    await ref.read(tasksProvider.notifier).rebuildAll();
    if (context.mounted) _toast(context, 'Hjemsted oppdatert.');
  }

  /// GDPR: clearly inform the user why location is used before requesting it.
  Future<bool?> _locationRationale(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hvorfor posisjon?'),
          content: const Text(
            'Vi bruker posisjonen din til å:\n\n'
            '• hente lokalt vær (temperatur, luftfuktighet, vind) som justerer '
            'vanningsplanen.\n'
            '• på sikt: kun varsle deg når du faktisk er hjemme.\n\n'
            'Posisjonen lagres kun på enheten og deles ikke. For hjemme-'
            'varsling senere trengs «Tillat alltid». Du kan når som helst '
            'trekke tilbake tilgangen i systeminnstillingene.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Avbryt')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Forstått, fortsett')),
          ],
        ),
      );

  void _toast(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold)),
      );
}

/// City search via Open-Meteo geocoding.
class _LocationDialog extends ConsumerStatefulWidget {
  const _LocationDialog();
  @override
  ConsumerState<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends ConsumerState<_LocationDialog> {
  final _c = TextEditingController();
  List<GeoPlace> _results = const [];
  bool _loading = false;

  Future<void> _search() async {
    if (_c.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final r = await ref.read(weatherApiProvider).geocode(_c.text.trim());
    if (mounted) {
      setState(() {
        _results = r;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Finn hjemsted'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _c,
              decoration: InputDecoration(
                hintText: 'By eller poststed',
                suffixIcon: IconButton(
                    icon: const Icon(Icons.search), onPressed: _search),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in _results)
                    ListTile(
                      title: Text(p.name),
                      onTap: () => Navigator.pop(context, p),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt')),
      ],
    );
  }
}
