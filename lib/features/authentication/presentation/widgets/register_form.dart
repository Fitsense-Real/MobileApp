import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/constants/app_colors.dart';
import '../../../../shared/constants/app_spacing.dart';
import '../../../../shared/widgets/fs_button.dart';
import '../../../../shared/widgets/fs_text_field.dart';
import '../providers/auth_provider.dart';
import 'auth_footer.dart';

class RegisterForm
    extends ConsumerStatefulWidget {
  const RegisterForm({
    super.key,
  });

  @override
  ConsumerState<RegisterForm> createState() =>
      _RegisterFormState();
}

class _RegisterFormState
    extends ConsumerState<RegisterForm> {
  final _formKey =
  GlobalKey<FormState>();

  final _firstNameController =
  TextEditingController();

  final _lastNameController =
  TextEditingController();

  final _emailController =
  TextEditingController();

  final _passwordController =
  TextEditingController();

  final _confirmPasswordController =
  TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // REGISTRO
  // ============================================================

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text !=
        _confirmPasswordController.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Las contraseñas no coinciden',
          ),
        ),
      );

      return;
    }

    final success =
    await ref
        .read(
      authViewModelProvider
          .notifier,
    )
        .register(
      firstName:
      _firstNameController
          .text
          .trim(),
      lastName:
      _lastNameController
          .text
          .trim(),
      email:
      _emailController
          .text
          .trim(),
      password:
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      context.go(
        AppRoutes.dashboard,
      );

      return;
    }

    final error =
        ref
            .read(
          authViewModelProvider,
        )
            .errorMessage;

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          behavior:
          SnackBarBehavior.floating,
          margin:
          const EdgeInsets.all(20),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
          ),
          content: Text(error),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final state =
    ref.watch(
      authViewModelProvider,
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: [

          // ======================================================
          // HEADER
          // ======================================================

          const _RegisterHeader()
              .animate()
              .fade(
            duration: 500.ms,
          )
              .slideY(
            begin: -.15,
            end: 0,
            duration: 500.ms,
            curve:
            Curves.easeOutCubic,
          ),

          const SizedBox(
            height: 30,
          ),

          // ======================================================
          // NOMBRE
          // ======================================================

          FSTextField(
            controller:
            _firstNameController,
            label:
            'Nombre',
            hint:
            'Ingresa tu nombre',
            prefixIcon:
            Icons.person_outline_rounded,
            textInputAction:
            TextInputAction.next,
            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Ingrese su nombre';
              }

              if (value.trim().length < 2) {
                return 'Nombre demasiado corto';
              }

              return null;
            },
          )
              .animate()
              .fade(
            delay: 100.ms,
            duration: 450.ms,
          )
              .slideX(
            begin: -.12,
            end: 0,
            duration: 450.ms,
            curve:
            Curves.easeOutCubic,
          ),

          const SizedBox(
            height: AppSpacing.lg,
          ),

          // ======================================================
          // APELLIDO
          // ======================================================

          FSTextField(
            controller:
            _lastNameController,
            label:
            'Apellido',
            hint:
            'Ingresa tu apellido',
            prefixIcon:
            Icons.badge_outlined,
            textInputAction:
            TextInputAction.next,
            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Ingrese su apellido';
              }

              if (value.trim().length < 2) {
                return 'Apellido demasiado corto';
              }

              return null;
            },
          )
              .animate()
              .fade(
            delay: 160.ms,
            duration: 450.ms,
          )
              .slideX(
            begin: .12,
            end: 0,
            duration: 450.ms,
            curve:
            Curves.easeOutCubic,
          ),

          const SizedBox(
            height: AppSpacing.lg,
          ),

          // ======================================================
          // CORREO
          // ======================================================

          FSTextField(
            controller:
            _emailController,
            label:
            'Correo electrónico',
            hint:
            'ejemplo@correo.com',
            prefixIcon:
            Icons.email_outlined,
            keyboardType:
            TextInputType.emailAddress,
            textInputAction:
            TextInputAction.next,
            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Ingrese su correo';
              }

              if (!RegExp(
                r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$',
              ).hasMatch(
                value.trim(),
              )) {
                return 'Correo electrónico inválido';
              }

              return null;
            },
          )
              .animate()
              .fade(
            delay: 220.ms,
            duration: 450.ms,
          )
              .slideX(
            begin: -.12,
            end: 0,
            duration: 450.ms,
            curve:
            Curves.easeOutCubic,
          ),

          const SizedBox(
            height: AppSpacing.lg,
          ),

          // ======================================================
          // CONTRASEÑA
          // ======================================================

          FSTextField(
            controller:
            _passwordController,
            label:
            'Contraseña',
            hint:
            '••••••••',
            prefixIcon:
            Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction:
            TextInputAction.next,
            validator: (value) {
              if (value == null ||
                  value.isEmpty) {
                return 'Ingrese una contraseña';
              }

              if (value.length < 8) {
                return
                  'Debe contener al menos 8 caracteres';
              }

              return null;
            },
          )
              .animate()
              .fade(
            delay: 280.ms,
            duration: 450.ms,
          )
              .slideX(
            begin: .12,
            end: 0,
            duration: 450.ms,
            curve:
            Curves.easeOutCubic,
          ),

          const SizedBox(
            height: AppSpacing.lg,
          ),

          // ======================================================
          // CONFIRMAR CONTRASEÑA
          // ======================================================

          FSTextField(
            controller:
            _confirmPasswordController,
            label:
            'Confirmar contraseña',
            hint:
            '••••••••',
            prefixIcon:
            Icons.lock_reset_outlined,
            isPassword: true,
            textInputAction:
            TextInputAction.done,
            validator: (value) {
              if (value == null ||
                  value.isEmpty) {
                return
                  'Confirme su contraseña';
              }

              if (value !=
                  _passwordController.text) {
                return
                  'Las contraseñas no coinciden';
              }

              return null;
            },
          )
              .animate()
              .fade(
            delay: 340.ms,
            duration: 450.ms,
          )
              .slideX(
            begin: -.12,
            end: 0,
            duration: 450.ms,
            curve:
            Curves.easeOutCubic,
          ),

          const SizedBox(
            height: AppSpacing.xl,
          ),

          // ======================================================
          // INDICADOR DE SEGURIDAD
          // ======================================================

          const _PasswordSecurityHint()
              .animate()
              .fade(
            delay: 390.ms,
            duration: 400.ms,
          ),

          const SizedBox(
            height: AppSpacing.lg,
          ),

          // ======================================================
          // BOTÓN
          // ======================================================

          FSButton(
            text:
            'Crear cuenta',
            isLoading:
            state.isLoading,
            onPressed:
            state.isLoading
                ? null
                : _register,
          )
              .animate()
              .fade(
            delay: 440.ms,
            duration: 500.ms,
          )
              .scale(
            begin:
            const Offset(
              .94,
              .94,
            ),
            end:
            const Offset(
              1,
              1,
            ),
            duration: 500.ms,
            curve:
            Curves.easeOutBack,
          ),

          const SizedBox(
            height: AppSpacing.xl,
          ),

          // ======================================================
          // DIVISOR
          // ======================================================

          const _OrDivider()
              .animate()
              .fade(
            delay: 500.ms,
            duration: 400.ms,
          ),

          const SizedBox(
            height: AppSpacing.xl,
          ),

          // ======================================================
          // FOOTER
          // ======================================================

          AuthFooter(
            question:
            '¿Ya tienes una cuenta?',
            actionText:
            'Inicia sesión',
            onPressed: () {
              context.go(
                AppRoutes.login,
              );
            },
          )
              .animate()
              .fade(
            delay: 560.ms,
            duration: 500.ms,
          )
              .slideY(
            begin: .10,
            end: 0,
            duration: 450.ms,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HEADER REGISTER
// ============================================================

class _RegisterHeader
    extends StatelessWidget {
  const _RegisterHeader();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [

        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Crear ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight:
                  FontWeight.w800,
                  letterSpacing:
                  -.7,
                ),
              ),
              TextSpan(
                text: 'tu cuenta',
                style: TextStyle(
                  color:
                  AppColors.primary,
                  fontSize: 30,
                  fontWeight:
                  FontWeight.w800,
                  letterSpacing:
                  -.7,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 9,
        ),

        const Text(
          'Únete a FitSense y comienza\ntu entrenamiento inteligente.',
          style: TextStyle(
            color:
            Color(0xFF9EA9A9),
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        Container(
          width: 46,
          height: 3,
          decoration:
          BoxDecoration(
            color:
            AppColors.primary,
            borderRadius:
            BorderRadius.circular(
              50,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// INDICADOR DE CONTRASEÑA
// ============================================================

class _PasswordSecurityHint
    extends StatelessWidget {
  const _PasswordSecurityHint();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      children: [

        Container(
          width: 28,
          height: 28,
          decoration:
          BoxDecoration(
            color:
            AppColors.primary.withValues(
              alpha: .10,
            ),
            borderRadius:
            BorderRadius.circular(
              9,
            ),
          ),
          child: const Icon(
            Icons.shield_outlined,
            size: 16,
            color:
            AppColors.primary,
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        const Expanded(
          child: Text(
            'Usa al menos 8 caracteres para mantener tu cuenta segura.',
            style: TextStyle(
              color:
              Color(0xFF7F8A8A),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// DIVISOR
// ============================================================

class _OrDivider
    extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      children: [

        Expanded(
          child: Container(
            height: 1,
            color:
            const Color(
              0xFF293032,
            ),
          ),
        ),

        const Padding(
          padding:
          EdgeInsets.symmetric(
            horizontal: 14,
          ),
          child: Text(
            'o',
            style: TextStyle(
              color:
              Color(0xFF6F7A7A),
              fontSize: 13,
            ),
          ),
        ),

        Expanded(
          child: Container(
            height: 1,
            color:
            const Color(
              0xFF293032,
            ),
          ),
        ),
      ],
    );
  }
}