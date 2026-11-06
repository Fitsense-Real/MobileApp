import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/constants/app_spacing.dart';
import '../../../../shared/widgets/auth_card.dart';
import '../../../../shared/widgets/fs_button.dart';
import '../../../../shared/widgets/fs_text_field.dart';
import '../../../../shared/widgets/page_header.dart';
import '../providers/forgot_password_provider.dart';

class ResetPasswordForm extends ConsumerStatefulWidget {
  const ResetPasswordForm({super.key});

  @override
  ConsumerState<ResetPasswordForm> createState() =>
      _ResetPasswordFormState();
}

class _ResetPasswordFormState
    extends ConsumerState<ResetPasswordForm> {

final _formKey = GlobalKey<FormState>();

final _codeController = TextEditingController();

final _passwordController = TextEditingController();

final _confirmPasswordController =
TextEditingController();

@override
void dispose() {
_codeController.dispose();
_passwordController.dispose();
_confirmPasswordController.dispose();
super.dispose();
}

Future<void> _resetPassword() async {

if (!_formKey.currentState!.validate()) {
return;
}

final success = await ref
.read(forgotPasswordViewModelProvider.notifier)
.resetPassword(
code: _codeController.text.trim(),
password: _passwordController.text,
);

if (!mounted) return;

if (success) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
"Contraseña actualizada correctamente.",
),
),
);

context.go(AppRoutes.login);
return;
}

final error = ref
.read(forgotPasswordViewModelProvider)
.errorMessage;

if (error != null) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(error),
),
);
}
}

@override
Widget build(BuildContext context) {

final state =
ref.watch(forgotPasswordViewModelProvider);

return Center(
child: SingleChildScrollView(
padding: const EdgeInsets.symmetric(
horizontal: 24,
vertical: 32,
),
child: ConstrainedBox(
constraints: const BoxConstraints(
maxWidth: 430,
),
child: AuthCard(
child: Form(
key: _formKey,
child: Column(
crossAxisAlignment:
CrossAxisAlignment.stretch,
children: [                   const PageHeader(
title: "Restablecer contraseña",
subtitle:
"Ingresa el código recibido y crea una nueva contraseña segura.",
)
.animate()
.fade(duration: 500.ms)
.slideY(
begin: -.15,
end: 0,
),

const SizedBox(
height: AppSpacing.xxl,
),

FSTextField(
controller: _codeController,
label: "Código de verificación",
hint: "123456",
prefixIcon: Icons.pin_outlined,
keyboardType: TextInputType.number,
validator: (value) {
if (value == null ||
value.trim().isEmpty) {
return "Ingrese el código";
}

if (value.length != 6) {
return "El código debe tener 6 dígitos";
}

return null;
},
)
.animate(delay: 100.ms)
.fade()
.slideX(begin: -.15),

const SizedBox(
height: AppSpacing.lg,
),

FSTextField(
controller: _passwordController,
label: "Nueva contraseña",
hint: "********",
prefixIcon: Icons.lock_outline,
isPassword: true,
validator: (value) {
if (value == null ||
value.isEmpty) {
return "Ingrese una contraseña";
}

if (value.length < 8) {
return "Debe contener al menos 8 caracteres";
}

return null;
},
)
.animate(delay: 200.ms)
.fade()
.slideX(begin: .15),

const SizedBox(
height: AppSpacing.lg,
),

FSTextField(
controller:
_confirmPasswordController,
label: "Confirmar contraseña",
hint: "********",
prefixIcon:
Icons.lock_reset_outlined,
isPassword: true,
validator: (value) {

if (value == null ||
value.isEmpty) {
return "Confirme su contraseña";
}

if (value !=
_passwordController.text) {
return "Las contraseñas no coinciden";
}

return null;
},
)
.animate(delay: 300.ms)
.fade()
.slideX(begin: -.15),

const SizedBox(
height: AppSpacing.xxl,
),

FSButton(
text: "Actualizar contraseña",
isLoading: state.isLoading,
onPressed: state.isLoading
? null
: _resetPassword,
)
.animate(delay: 400.ms)
.fade()
.scale(),

const SizedBox(
height: AppSpacing.lg,
),

OutlinedButton.icon(
onPressed: () {
context.go(AppRoutes.login);
},
icon: const Icon(Icons.arrow_back),
label: const Text(
"Volver al inicio de sesión",
),
).animate(delay: 500.ms).fade(),
],
),
),
),
),
),
);
}
}