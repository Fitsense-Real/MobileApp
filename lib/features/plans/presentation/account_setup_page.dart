import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/api/api_error.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../../onboarding/data/profile_repository.dart';
import '../../onboarding/presentation/generating_plan.dart';
import '../data/plan_repository.dart';

/// Checks server state on every login, before allowing entry to the home page.
class AccountSetupPage extends ConsumerStatefulWidget {
  const AccountSetupPage({super.key});
  @override
  ConsumerState<AccountSetupPage> createState() => _AccountSetupPageState();
}

class _AccountSetupPageState extends ConsumerState<AccountSetupPage> {
  bool generating = false;
  String? error;

  @override
  void initState() {
    super.initState();
    Future.microtask(checkAccount);
  }

  Future<void> checkAccount() async {
    if (!mounted) return;
    setState(() { error = null; generating = false; });
    try {
      final profile = await ref.read(profileRepositoryProvider).fetch();
      if (!mounted) return;
      if (profile == null) {
        context.go('/onboarding');
        return;
      }
      final repository = ref.read(planRepositoryProvider);
      var plan = await repository.current();
      if (!mounted) return;
      if (plan == null) {
        setState(() => generating = true);
        try {
          plan = await repository.generate();
        } on DioException catch (e) {
          if (!isPlanConflict(e)) rethrow;
          plan = await repository.current();
          if (plan == null) rethrow;
        }
      }
      if (!mounted) return;
      if (plan['planId'] == null) {
        throw const FormatException('El servidor no devolvió un plan válido.');
      }
      ref.read(generatedPlanProvider.notifier).setPlan(plan);
      ref.invalidate(currentPlanProvider);
      context.go(AppRoutes.dashboard);
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error == null && generating) return const GeneratingPlan(saving: false);
    return PopScope(canPop: false, child: Scaffold(
      backgroundColor: Kora.forest,
      body: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (error == null) ...[
            const CircularProgressIndicator(color: Kora.lime),
            const SizedBox(height: 24),
            const Text('Preparando tu cuenta…', style: TextStyle(color: Colors.white, fontSize: 22)),
          ] else ...[
            const Text('No pudimos preparar tu entrenamiento', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22)),
            const SizedBox(height: 16),
            Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 24),
            KoraButton(label: 'Reintentar', lime: true, onPressed: checkAccount),
            TextButton(onPressed: () => context.go(AppRoutes.login), child: const Text('Volver al inicio de sesión', style: TextStyle(color: Kora.lime))),
          ],
        ]),
      ))),
    ));
  }
}
