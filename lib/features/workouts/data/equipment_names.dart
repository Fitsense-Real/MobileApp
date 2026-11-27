import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../onboarding/data/profile_repository.dart';

/// Spanish names of the equipment codes, from the catalog
/// (`GET /catalog/equipment-types`, field `nameEs`). Empty when the catalog
/// cannot be read: the equipment line is then omitted, never shown in English.
final equipmentNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  try {
    final items = await ref.watch(profileRepositoryProvider).equipment();
    return {for (final e in items) e.code.trim().toLowerCase(): e.name};
  } catch (_) {
    return const {};
  }
});

String? equipmentName(Object? code, Map<String, String> names) {
  final key = '${code ?? ''}'.trim().toLowerCase();
  if (key.isEmpty) return null;
  return names[key] ?? (key == bodyWeightCode ? 'Peso corporal' : null);
}
