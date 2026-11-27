import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/config/app_links.dart';
import '../../../core/config/study_config.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../domain/plan_eligibility.dart';

/// Shown instead of the profile setup or the first-plan generation when the
/// backend will not prepare a plan for this account (not a participant, or
/// withdrawn). Explains why, says who to contact and lets the person sign out:
/// never a "retry" that can only fail.
class NoPlanAvailableView extends ConsumerWidget {
  const NoPlanAvailableView({super.key, required this.reason, required this.onCheckAgain});
  final PlanIneligibility reason;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authViewModelProvider).user;
    final withdrawn = user?.withdrawnAt;
    final explanation = switch (reason) {
      PlanIneligibility.notParticipant =>
        'Por ahora Kora prepara rutinas solo para las personas que participan en el estudio, y tu cuenta no está inscrita como participante.',
      PlanIneligibility.withdrawn =>
        'Te retiraste del estudio${withdrawn == null ? '' : ' el ${withdrawn.toLocal().day.toString().padLeft(2, '0')}/${withdrawn.toLocal().month.toString().padLeft(2, '0')}/${withdrawn.toLocal().year}'}. '
            'Desde entonces Kora no prepara rutinas nuevas. Los datos que ya registraste se conservan.',
    };
    return KoraPage(
      maxWidth: 560,
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const KoraLogo(width: 86),
        const SizedBox(height: 32),
        const KoraHeading('Por ahora no hay', accent: 'una rutina para ti.'),
        const SizedBox(height: 20),
        Text(explanation, style: const TextStyle(fontSize: 16, height: 1.5)),
        const SizedBox(height: 16),
        KoraCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('¿Quieres participar o crees que es un error?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            StudyConfig.contact.trim().isEmpty
                ? 'Escribe al equipo del estudio que te invitó, indicando el correo de tu cuenta${user == null ? '' : ' (${user.email})'}.'
                : 'Escribe al equipo del estudio: ${StudyConfig.contact.trim()}. Indica el correo de tu cuenta${user == null ? '' : ' (${user.email})'}.',
            style: const TextStyle(fontSize: 15, height: 1.45),
          ),
        ])),
        const SizedBox(height: 24),
        KoraButton(label: 'Volver a comprobar', onPressed: onCheckAgain),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () async {
            await ref.read(authViewModelProvider.notifier).logout();
            if (context.mounted) context.go(AppRoutes.login);
          },
          child: const Text('Cerrar sesión'),
        ),
        if (AppLinks.accountDeletionEnabled)
          TextButton(onPressed: () => context.push(AppRoutes.deleteAccount), child: const Text('Eliminar mi cuenta')),
      ]),
    );
  }
}
