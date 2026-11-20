import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/config/app_links.dart';
import '../../../shared/constants/app_colors.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import 'account_deletion_controller.dart';

/// Perfil → Cuenta → Eliminar mi cuenta. Separate from "Retirarme del
/// estudio": withdrawing keeps the account, deleting asks to remove it.
class AccountDeletionPage extends ConsumerStatefulWidget {
  const AccountDeletionPage({super.key});
  @override
  ConsumerState<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends ConsumerState<AccountDeletionPage> {
  final password = TextEditingController();
  bool understood = false;
  bool hidden = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(accountDeletionProvider.notifier).reset());
  }

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text('Se eliminará tu cuenta y se cerrará tu sesión. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade800),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(accountDeletionProvider.notifier).delete(password: password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountDeletionProvider);
    final user = ref.watch(authViewModelProvider).user;
    return KoraPage(
      maxWidth: 560,
      child: ListView(padding: const EdgeInsets.all(24), children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back),
            onPressed: state.status == DeletionStatus.inProgress ? null : () => context.canPop() ? context.pop() : context.go(AppRoutes.dashboard),
          ),
        ),
        const SizedBox(height: 8),
        ...switch (state.status) {
          DeletionStatus.completed => _done(
              'Tu cuenta fue eliminada',
              'El servidor confirmó la eliminación. Se cerró tu sesión y se borraron de este teléfono tus datos de Kora.',
            ),
          DeletionStatus.pending => _done(
              'Solicitud recibida',
              '${state.alreadyRequested ? 'Ya habías solicitado la eliminación. ' : ''}'
                  'Tu cuenta quedó desactivada: ya no se puede iniciar sesión con ella. '
                  'El servidor completará la eliminación automáticamente; todavía no está terminada y no necesitas hacer nada más. '
                  'Si quieres confirmar que terminó, escribe al equipo del estudio. '
                  'Se cerró tu sesión y se borraron de este teléfono tus datos de Kora.',
            ),
          DeletionStatus.gone => _done(
              state.inferred ? 'Tu cuenta probablemente ya se eliminó' : 'Tu cuenta ya no existe',
              '${state.message ?? ''} Se cerró tu sesión y se borraron de este teléfono tus datos de Kora.',
            ),
          _ when user == null => _signedOut(),
          _ => _form(state),
        },
      ]),
    );
  }

  List<Widget> _done(String title, String message) => [
        Semantics(header: true, liveRegion: true, child: Text(title, style: _title)),
        const SizedBox(height: 12),
        Text(message, style: _body),
        const SizedBox(height: 28),
        KoraButton(label: 'Salir', onPressed: () => context.go(AppRoutes.login)),
      ];

  List<Widget> _signedOut() => [
        Text('Eliminar mi cuenta', style: _title),
        const SizedBox(height: 12),
        Text('Inicia sesión para eliminar tu cuenta desde la app.', style: _body),
        ..._link('También puedes solicitarlo sin la app en:', AppLinks.accountDeletionWebUrl),
        const SizedBox(height: 24),
        KoraButton(label: 'Iniciar sesión', onPressed: () => context.go(AppRoutes.login)),
      ];

  List<Widget> _form(AccountDeletionState state) {
    final busy = state.status == DeletionStatus.inProgress;
    final blocked = state.blockedAt(ref.read(deletionClockProvider)());
    return [
      Semantics(header: true, child: Text('Eliminar mi cuenta', style: _title)),
      const SizedBox(height: 16),
      _point('Se eliminará tu cuenta de Kora en el servidor y se cerrará tu sesión en este teléfono.'),
      _point('Desde ese momento no podrás volver a entrar con esta cuenta.'),
      _point('No se puede deshacer.'),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
        child: const Text(
          'Retirarte del estudio es distinto: dejas de participar y conservas tu cuenta. Está en Perfil → Cuenta.',
          style: TextStyle(color: Kora.forest, height: 1.4),
        ),
      ),
      const SizedBox(height: 16),
      Text('Tus datos', style: _subtitle),
      const SizedBox(height: 6),
      Text(
        'Lo que ocurre con los datos ya recolectados para el estudio se rige por el consentimiento informado que aceptaste y por la política de privacidad de Kora.',
        style: _body,
      ),
      ..._link('Política de privacidad:', AppLinks.privacyPolicyUrl),
      ..._link('También puedes solicitar la eliminación sin la app en:', AppLinks.accountDeletionWebUrl),
      const SizedBox(height: 20),
      TextField(
        controller: password,
        enabled: !busy,
        obscureText: hidden,
        autofillHints: const [AutofillHints.password],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Tu contraseña',
          helperText: 'Para confirmar que eres tú.',
          suffixIcon: IconButton(
            tooltip: hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
            icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => hidden = !hidden),
          ),
        ),
      ),
      const SizedBox(height: 8),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: understood,
        onChanged: busy ? null : (v) => setState(() => understood = v ?? false),
        title: const Text('Entiendo que esta acción no se puede deshacer'),
      ),
      if (state.status == DeletionStatus.failed && state.message != null) ...[
        const SizedBox(height: 8),
        Semantics(liveRegion: true, child: Text(state.message!, style: TextStyle(color: Colors.red.shade800, height: 1.4))),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: busy || blocked || !understood || password.text.isEmpty ? null : _confirm,
        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)),
        child: busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : const Text('Eliminar mi cuenta'),
      ),
    ];
  }

  List<Widget> _link(String label, String url) => url.isEmpty
      ? const []
      : [
          const SizedBox(height: 10),
          Text(label, style: _body),
          Row(children: [
            Expanded(child: SelectableText(url, style: const TextStyle(color: Kora.forest, fontWeight: FontWeight.w700))),
            IconButton(
              tooltip: 'Copiar enlace',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enlace copiado')));
              },
            ),
          ]),
        ];

  Widget _point(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('•  ', style: TextStyle(color: Kora.forest, fontWeight: FontWeight.w900)),
          Expanded(child: Text(text, style: _body)),
        ]),
      );

  static const _title = TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Kora.forest, letterSpacing: -.6);
  static const _subtitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Kora.forest);
  static const _body = TextStyle(color: Kora.muted, height: 1.45);
}
