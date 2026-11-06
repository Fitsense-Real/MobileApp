import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../shared/widgets/kora_ui.dart';
import '../../../../shared/widgets/fs_text_field.dart';
import '../providers/auth_provider.dart';

class KoraAuthForm extends ConsumerStatefulWidget {
  const KoraAuthForm({super.key, this.register = false});
  final bool register;
  @override
  ConsumerState<KoraAuthForm> createState() => _KoraAuthFormState();
}

class _KoraAuthFormState extends ConsumerState<KoraAuthForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  final _timezone = TextEditingController(text: 'America/Lima');
  bool _consent = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  @override
  void dispose() {
    for (final c in [_name, _lastName, _timezone, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final model = ref.read(authViewModelProvider.notifier);
    final success = widget.register
        ? await model.register(
            firstName: _name.text.trim(),
            lastName: _lastName.text.trim(),
            timezone: _timezone.text.trim(),
            acceptsStudyParticipation: _consent,
            email: _email.text.trim(),
            password: _password.text,
          )
        : await model.login(
            email: _email.text.trim(),
            password: _password.text,
          );
    if (!mounted) return;
    if (success) {
      if (widget.register) {
        context.go(AppRoutes.login);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta creada. Inicia sesión para completar tu perfil.')));
      } else {
        context.go(AppRoutes.accountSetup);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(authViewModelProvider).errorMessage ??
                'No se pudo conectar. Inténtalo nuevamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authViewModelProvider).isLoading;
    return KoraPage(
      maxWidth: 520,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.splash),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Volver',
              ),
              const KoraLogo(width: 86),
            ],
          ),
          const SizedBox(height: 38),
          KoraLabel(widget.register ? 'BIENVENIDO A KORA' : 'PORTAL DE ACCESO'),
          const SizedBox(height: 16),
          KoraHeading(
            widget.register ? 'Crear' : 'Entrena con',
            accent: widget.register ? 'Cuenta.' : 'Propósito.',
            subtitle: widget.register
                ? 'Empieza hoy tu camino personalizado hacia un mejor bienestar.'
                : 'Ingresa tus credenciales para acceder a tu panel de entrenamiento personalizado.',
          ),
          const SizedBox(height: 32),
          AutofillGroup(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.register) ...[
                    FSTextField(
                      controller: _name,
                      label: 'Nombres',
                      hint: 'Ej. Juan',
                      prefixIcon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty || (v ?? '').length > 100
                          ? 'Escribe tus nombres (máximo 100 caracteres)'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    FSTextField(controller: _lastName, label: 'Apellidos', prefixIcon: Icons.person_outline, validator: (v) => (v ?? '').length > 150 ? 'Máximo 150 caracteres' : null),
                    const SizedBox(height: 22),
                  ],
                  FSTextField(
                    controller: _email,
                    label: 'Correo electrónico',
                    hint: 'nombre@ejemplo.com',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v ?? '').length <= 254 && RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch((v ?? '').trim())
                        ? null
                        : 'Ingresa un correo válido',
                  ),
                  const SizedBox(height: 22),
                  FSTextField(
                    controller: _password,
                    label: 'Contraseña',
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    validator: (v) => (v ?? '').length < 8 || (v ?? '').length > 72
                        ? 'Usa entre 8 y 72 caracteres'
                        : null,
                  ),
                  if (widget.register) ...[
                    const SizedBox(height: 22),
                    FSTextField(
                      controller: _confirm,
                      label: 'Confirmar contraseña',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      validator: (v) => v != _password.text
                          ? 'Las contraseñas no coinciden'
                          : null,
                    ),
                  ],
                  if (!widget.register)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: ApiConstants.passwordRecoveryAvailable
                            ? () => context.push(AppRoutes.forgotPassword)
                            : () => showDialog<void>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Recuperar contraseña'),
                                    content: const Text('La recuperación de contraseña todavía no está disponible. Si no recuerdas tu clave, contacta al equipo del estudio.'),
                                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
                                  ),
                                ),
                        child: const Text('¿Olvidaste la clave?'),
                      ),
                    ),
                  const SizedBox(height: 22),
                  if (widget.register) ...[
                    FSTextField(controller: _timezone, label: 'Zona horaria', hint: 'America/Lima', prefixIcon: Icons.public, validator: (v) => (v ?? '').trim().isEmpty || (v ?? '').length > 64 ? 'Escribe una zona horaria válida' : null),
                    CheckboxListTile(contentPadding: EdgeInsets.zero, value: _consent, onChanged: busy ? null : (v) => setState(() => _consent = v ?? false), title: const Text('Acepto participar en el estudio'), subtitle: const Text('Opcional. Déjalo desmarcado si no deseas participar.'), controlAffinity: ListTileControlAffinity.leading),
                    const SizedBox(height: 16),
                  ],
                  KoraButton(
                    label: widget.register ? 'CREAR CUENTA' : 'INICIAR SESIÓN',
                    busy: busy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
          if (!widget.register) ...[
            const SizedBox(height: 28),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: KoraLabel('O CONTINÚA CON'),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: null,
                    child: Text('G  GOOGLE'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: null,
                    child: Text('●  APPLE'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Acceso social próximamente',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Kora.muted),
            ),
          ],
          const SizedBox(height: 28),
          Center(
            child: KoraLabel(
              widget.register
                  ? '¿YA TIENES UNA CUENTA?'
                  : '¿NO ERES MIEMBRO AÚN?',
            ),
          ),
          TextButton(
            onPressed: () => context.go(
              widget.register ? AppRoutes.login : AppRoutes.register,
            ),
            child: Text(
              widget.register ? 'Iniciar sesión' : 'Únete a la comunidad Kora',
            ),
          ),
        ],
      ),
    );
  }
}
