import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../models/species.dart';
import '../../services/mestergronn_api.dart';
import '../../services/plantasjen_api.dart';

/// Search the Mestergrønn product catalogue by name. Returns the chosen
/// [Species] (enriched with full product data) via Navigator.pop.
///
/// Pass [initialQuery] (e.g. an OCR'd receipt line) to pre-fill the field and
/// search immediately.
class SpeciesSearchScreen extends ConsumerStatefulWidget {
  const SpeciesSearchScreen({super.key, this.initialQuery});
  final String? initialQuery;
  @override
  ConsumerState<SpeciesSearchScreen> createState() =>
      _SpeciesSearchScreenState();
}

class _SpeciesSearchScreenState extends ConsumerState<SpeciesSearchScreen> {
  final _c = TextEditingController();
  List<Species> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      _c.text = q;
      _search();
    }
  }

  Future<void> _search() async {
    final catalog = ref.read(catalogProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await catalog.search(_c.text.trim());
      setState(() {
        _results = r;
        if (r.isEmpty) _error = 'Ingen treff.';
      });
    } on MestergronnException catch (e) {
      setState(() => _error = e.message);
    } on PlantasjenException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Søk feilet: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(Species s) async {
    setState(() => _loading = true);
    Species enriched = s;
    try {
      enriched = await ref.read(catalogProvider).enrich(s);
    } catch (_) {/* fall back to list snapshot */}
    if (mounted) Navigator.of(context).pop(enriched);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _c,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
              hintText: 'Søk plante (f.eks. monstera)',
              border: InputBorder.none),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _search),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final s = _results[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: s.imageUrl != null
                        ? NetworkImage(
                            MestergronnApi.displayImage(s.imageUrl)!)
                        : null,
                    child: s.imageUrl == null
                        ? const Icon(Icons.local_florist)
                        : null,
                  ),
                  title: Text(s.commonName),
                  // Empty subtitle would push the title off-center vertically.
                  subtitle: s.scientificName.isEmpty
                      ? null
                      : Text(s.scientificName.join(', ')),
                  trailing: s.wateringWord == null
                      ? null
                      : Chip(label: Text(s.wateringWord!)),
                  onTap: () => _pick(s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
