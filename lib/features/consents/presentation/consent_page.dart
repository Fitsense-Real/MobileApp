import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/api/api_error.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../data/consents_repository.dart';
import '../domain/legal_documents.dart';
import 'document_acceptance.dart';
import 'document_reader_page.dart';

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
  /// Documents that could not be shown: they cannot be accepted.
  final unavailable = <ConsentType>{};
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
    // Address and title of each pending document, as the backend publishes it.
    final published = ref.watch(publishedDocumentsProvider).asData?.value ?? const PublishedDocuments();
    return KoraPage(
      maxWidth: 560,
      child: status.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(apiError(e), textAlign: TextAlign.center), const SizedBox(height: 16), KoraButton(label: 'Reintentar', onPressed: () => ref.invalidate(consentStatusProvider))]))),
        data: (data) {
          final pending = data.pendingDocuments;
          return ListView(padding: const EdgeInsets.all(24), children: [
            const Text('Antes de continuar', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Kora.forest)),
            const SizedBox(height: 10),
            const Text('Se publicaron versiones nuevas de estos documentos. Puedes leerlos pulsando su nombre y aceptar cada uno por separado.', style: TextStyle(color: Kora.muted, height: 1.45)),
            const SizedBox(height: 16),
            for (final type in pending) ...[
              Builder(builder: (context) {
                final version = '${data.currentVersions[type]}';
                final found = published.find(type, version);
                final doc = found != null && found.readable ? found : null;
                return DocumentAcceptance(
                  type: type,
                  before: type == ConsentType.termsOfService
                      ? 'Acepto los '
                      : published.privacyRecord == PrivacyRecord.acknowledgement ? 'He leído la ' : 'Acepto la ',
                  after: ' (versión $version)',
                  value: checked.contains(type),
                  checkboxKey: Key('accept-${type.code}'),
                  onChanged: doc == null || unavailable.contains(type) || saving ? null : (v) => setState(() => v ? checked.add(type) : checked.remove(type)),
                  onOpen: doc == null || saving ? null : () async {
                    final shown = await DocumentReaderPage.open(context, doc);
                    if (!mounted || shown == null) return;
                    setState(() {
                      if (shown) {
                        unavailable.remove(type);
                      } else {
                        unavailable.add(type);
                        checked.remove(type);
                      }
                    });
                  },
                  note: doc == null
                      ? 'Este documento no está publicado para leerlo en la app. Contacta al equipo del estudio antes de aceptarlo.'
                      : unavailable.contains(type)
                          ? 'No se pudo abrir el documento, así que no se puede aceptar. Pulsa «${DocumentReaderPage.titleOf(type)}» para intentarlo de nuevo.'
                          : null,
                  noteIsError: doc != null,
                );
              }),
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

}
