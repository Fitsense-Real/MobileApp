import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/api/api_error.dart';
import '../../../core/config/app_links.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../data/consents_repository.dart';

/// Shown after signing in only when the backend publishes an approved
/// version of the terms or the privacy policy that this person has not
/// accepted. One checkbox per document, none pre-checked.
class ConsentPage extends ConsumerStatefulWidget {
  const ConsentPage({super.key});
  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> {
  final checked = <ConsentType>{};
  bool saving = false;
  String? error;

  Future<void> _accept(ConsentStatus status) async {
    setState(() { saving = true; error = null; });
    try {
      for (final type in status.pendingDocuments) {
        await ref.read(consentsRepositoryProvider).accept(type, status.currentVersions[type]!);
      }
      if (mounted) context.go(AppRoutes.accountSetup);
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(consentStatusProvider);
    return KoraPage(
      maxWidth: 560,
      child: status.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(apiError(e)))),
        data: (data) {
          final pending = data.pendingDocuments;
          return ListView(padding: const EdgeInsets.all(24), children: [
            const Text('Antes de continuar', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Kora.forest)),
            const SizedBox(height: 10),
            const Text('Se publicaron documentos nuevos de Kora. Léelos y acepta cada uno por separado.', style: TextStyle(color: Kora.muted, height: 1.45)),
            const SizedBox(height: 16),
            for (final type in pending) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: checked.contains(type),
                onChanged: saving ? null : (v) => setState(() => v == true ? checked.add(type) : checked.remove(type)),
                title: Text(type == ConsentType.termsOfService ? 'Acepto las condiciones de uso' : 'He leído la política de privacidad'),
                subtitle: Text('Versión ${data.currentVersions[type]}'),
              ),
              ..._link(type == ConsentType.termsOfService ? AppLinks.termsUrl : AppLinks.privacyPolicyUrl),
              const SizedBox(height: 8),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: TextStyle(color: Colors.red.shade800)),
            ],
            const SizedBox(height: 16),
            KoraButton(
              label: 'Continuar',
              busy: saving,
              onPressed: pending.every(checked.contains) && !saving ? () => _accept(data) : null,
            ),
          ]);
        },
      ),
    );
  }

  List<Widget> _link(String url) => url.isEmpty
      ? const []
      : [
          Row(children: [
            Expanded(child: SelectableText(url, style: const TextStyle(color: Kora.forest, fontWeight: FontWeight.w700))),
            IconButton(tooltip: 'Copiar enlace', icon: const Icon(Icons.copy, size: 18), onPressed: () => Clipboard.setData(ClipboardData(text: url))),
          ]),
        ];
}
