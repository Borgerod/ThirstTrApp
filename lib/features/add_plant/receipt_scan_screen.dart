import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/providers.dart';
import '../../models/species.dart';
import '../../services/ocr_api.dart';
import 'species_search_screen.dart';

/// OCRs a receipt photo, lists the plausible product lines and lets the user
/// pick one; the line pre-fills a catalogue search whose chosen [Species] is
/// popped back to the caller.
class ReceiptScanScreen extends ConsumerStatefulWidget {
  const ReceiptScanScreen({super.key, required this.image});
  final XFile image;

  @override
  ConsumerState<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends ConsumerState<ReceiptScanScreen> {
  bool _loading = true;
  String? _error;
  List<String> _lines = const [];

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await widget.image.readAsBytes();
      final text = await ref.read(ocrProvider).recognizeReceipt(bytes);
      setState(() => _lines = OcrApi.candidateLines(text));
    } on OcrException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Skanning feilet: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchFor(String? line) async {
    final species = await Navigator.of(context).push<Species>(MaterialPageRoute(
        builder: (_) => SpeciesSearchScreen(initialQuery: line)));
    if (species != null && mounted) Navigator.of(context).pop(species);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Varer på kvitteringen')),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Leser kvitteringen …'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_error != null) ...[
                  Text(_error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _run,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Prøv igjen'),
                  ),
                ] else if (_lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Fant ingen varelinjer på kvitteringen.'),
                  )
                else ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Trykk på varen som er planten din:'),
                  ),
                  for (final line in _lines)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_florist),
                        title: Text(line),
                        trailing: const Icon(Icons.search),
                        onTap: () => _searchFor(line),
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _searchFor(null),
                  icon: const Icon(Icons.search),
                  label: const Text('Søk manuelt i stedet'),
                ),
              ],
            ),
    );
  }
}
