import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/providers.dart';
import '../../models/species.dart';
import '../plant_detail/plant_edit_screen.dart';
import 'barcode_scan_screen.dart';
import 'receipt_scan_screen.dart';
import 'species_search_screen.dart';

/// Hub for the four ways to add a plant (per spec):
/// search, barcode scan, receipt scan, manual name.
class AddPlantScreen extends ConsumerWidget {
  const AddPlantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legg til plante')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Option(
            icon: Icons.search,
            title: 'Søk i plantekatalogen',
            subtitle: 'Finn planten via Mestergrønn og fyll inn info automatisk',
            onTap: () => _fromSpecies(context),
          ),
          _Option(
            icon: Icons.qr_code_scanner,
            title: 'Skann strekkode',
            subtitle: 'Skann etiketten på potten',
            onTap: () => _fromBarcode(context, ref),
          ),
          _Option(
            icon: Icons.receipt_long,
            title: 'Skann kvittering',
            subtitle: 'Ta bilde av kvitteringen og knytt den til planten',
            onTap: () => _fromReceipt(context),
          ),
          _Option(
            icon: Icons.edit,
            title: 'Legg til med navn',
            subtitle: 'Registrer manuelt uten artsdata',
            onTap: () => _fromName(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openEdit(BuildContext context,
      {Species? species, String? name, String? receiptPath}) async {
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => PlantEditScreen(
          species: species, initialName: name, receiptPath: receiptPath),
    ));
    if (id != null && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _fromSpecies(BuildContext context) async {
    final species = await Navigator.of(context).push<Species>(
        MaterialPageRoute(builder: (_) => const SpeciesSearchScreen()));
    if (species != null && context.mounted) {
      await _openEdit(context, species: species);
    }
  }

  Future<void> _fromBarcode(BuildContext context, WidgetRef ref) async {
    final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const BarcodeScanScreen()));
    if (code == null || !context.mounted) return;

    // Pot labels carry three kinds of codes:
    //  * QR with a Mestergrønn product URL (…/<pid>.html) → fetch it directly.
    //  * numeric EAN → resolved via Plantasjen (Mestergrønn has no EAN index).
    //  * text (plant name printed in the code) → search the catalogue by it.
    final catalog = ref.read(catalogProvider);
    final pidMatch = RegExp(r'/(\d+)\.html').firstMatch(code);
    final isEan = RegExp(r'^\d{8,14}$').hasMatch(code.trim());
    Species? species;
    try {
      if (pidMatch != null) {
        species = await catalog.fillMissingFacts(await ref
            .read(mestergronnProvider)
            .enrichedSpecies(int.parse(pidMatch.group(1)!)));
      } else if (isEan) {
        species = await catalog.byEan(code);
      } else {
        final hits = await catalog.search(code);
        if (hits.isNotEmpty) species = await catalog.enrich(hits.first);
      }
    } catch (_) {/* offline or unknown code — fall through to manual search */}

    if (!context.mounted) return;
    if (species == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Fant ikke koden i katalogen — søk på navn.')));
      // A text code is likely the plant's name: pre-fill the search with it.
      species = await Navigator.of(context).push<Species>(MaterialPageRoute(
          builder: (_) =>
              SpeciesSearchScreen(initialQuery: isEan ? null : code)));
      if (species == null || !context.mounted) return; // søk avbrutt
    }
    await _openEdit(context, species: species, name: species.commonName);
  }

  Future<void> _fromReceipt(BuildContext context) async {
    final picker = ImagePicker();
    // maxWidth/quality keep the upload under OCR.space's 1 MB free-tier cap.
    final shot = await picker.pickImage(
        source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
    if (shot == null || !context.mounted) return;

    // OCR the receipt and let the user match a line against the catalogue;
    // backing out keeps the old behavior (attach photo, name manually).
    final species = await Navigator.of(context).push<Species>(
        MaterialPageRoute(builder: (_) => ReceiptScanScreen(image: shot)));
    if (!context.mounted) return;
    await _openEdit(context,
        species: species,
        receiptPath: shot.path,
        name: species?.commonName ?? 'Ny plante');
  }

  Future<void> _fromName(BuildContext context) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plantenavn'),
        content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'F.eks. Monstera')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Avbryt')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Neste')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      await _openEdit(context, name: name);
    }
  }
}

class _Option extends StatelessWidget {
  const _Option(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
