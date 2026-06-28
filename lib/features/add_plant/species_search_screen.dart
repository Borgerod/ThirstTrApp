import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../models/species.dart';
import '../../services/perenual_api.dart';

/// Search the Perenual species list. Returns the chosen [Species] (enriched
/// with care guide) via Navigator.pop.
class SpeciesSearchScreen extends ConsumerStatefulWidget {
  const SpeciesSearchScreen({super.key});
  @override
  ConsumerState<SpeciesSearchScreen> createState() =>
      _SpeciesSearchScreenState();
}

class _SpeciesSearchScreenState extends ConsumerState<SpeciesSearchScreen> {
  final _c = TextEditingController();
  List<Species> _results = const [];
  bool _loading = false;
  String? _error;

  Future<void> _search() async {
    final api = ref.read(perenualProvider);
    if (!api.hasKey) {
      setState(() => _error =
          'Mangler API-nøkkel. Legg den inn under Innstillinger → Perenual API.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await api.speciesList(query: _c.text.trim());
      setState(() => _results = r);
    } on PerenualAuthException catch (e) {
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
      enriched = await ref.read(perenualProvider).enrichedSpecies(s.id);
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
              hintText: 'Søk art (f.eks. monstera)',
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
                    backgroundImage:
                        s.imageUrl != null ? NetworkImage(s.imageUrl!) : null,
                    child: s.imageUrl == null
                        ? const Icon(Icons.local_florist)
                        : null,
                  ),
                  title: Text(s.commonName),
                  subtitle: Text(s.scientificName.join(', ')),
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
