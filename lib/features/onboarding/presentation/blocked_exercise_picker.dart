import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/json.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../../catalog/data/catalog_repository.dart';

/// Searches the active catalog (`GET /catalog/exercises?search=`) and returns
/// the chosen ids for `blockedExerciseIds`, the backend's exclusion list.
class BlockedExercisePicker extends ConsumerStatefulWidget {
  const BlockedExercisePicker({super.key, required this.selected});
  final Map<int, String> selected;
  @override
  ConsumerState<BlockedExercisePicker> createState() => _BlockedExercisePickerState();
}

class _BlockedExercisePickerState extends ConsumerState<BlockedExercisePicker> {
  late final chosen = Map<int, String>.of(widget.selected);
  List<Json> results = [];
  bool loading = false;
  String? error;
  Timer? debounce;
  int request = 0;

  @override
  void initState() {
    super.initState();
    search('');
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  void onQuery(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () => search(value));
  }

  Future<void> search(String value) async {
    final id = ++request;
    setState(() { loading = true; error = null; });
    try {
      final rows = await ref.read(catalogRepositoryProvider).exercises(search: value, limit: 40);
      if (mounted && id == request) setState(() => results = rows);
    } catch (e) {
      if (mounted && id == request) setState(() => error = apiError(e));
    } finally {
      if (mounted && id == request) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(
    padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(children: [
      Row(children: [
        const Expanded(child: Text('Ejercicios a evitar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22))),
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Cancelar'),
      ]),
      const Text('Los ejercicios marcados no aparecerán en tus planes.', style: TextStyle(color: Kora.muted)),
      const SizedBox(height: 16),
      TextField(decoration: const InputDecoration(hintText: 'Buscar por nombre', prefixIcon: Icon(Icons.search)), onChanged: onQuery),
      const SizedBox(height: 8),
      if (loading) const LinearProgressIndicator(),
      if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(error!)),
      Expanded(child: results.isEmpty && !loading && error == null
          ? const Center(child: Text('No hay resultados'))
          : ListView.builder(itemCount: results.length, itemBuilder: (_, i) {
              final item = results[i];
              final id = (item['exerciseId'] as num).toInt();
              final name = '${item['name'] ?? 'Ejercicio #$id'}';
              return CheckboxListTile(
                value: chosen.containsKey(id),
                title: Text(name),
                subtitle: item['targetMuscle'] == null ? null : Text('${item['targetMuscle']}'),
                onChanged: (v) => setState(() => v == true ? chosen[id] = name : chosen.remove(id)),
              );
            })),
      KoraButton(label: 'LISTO · ${chosen.length} EXCLUIDOS', onPressed: () => Navigator.pop(context, chosen)),
    ]),
  ));
}
