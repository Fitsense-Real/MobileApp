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

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({
    super.key,
  });

  @override
  ConsumerState<LoginForm> createState() =>
      _LoginFormState();
}

class _LoginFormState
    extends ConsumerState<LoginForm> {
  final _formKey =
  GlobalKey<FormState>();

  final _emailController =
  TextEditingController();

  final _passwordController =
  TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success =
    await ref
        .read(
      authViewModelProvider
          .notifier,
    )
        .login(
      email:
      _emailController.text.trim(),
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
          // ENCABEZADO
          // ======================================================

          const _LoginHeader()
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
                return 'Ingrese su correo electrónico';
              }

              if (!RegExp(
                r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$',
              ).hasMatch(
                value.trim(),
              )) {
                return 'Ingrese un correo válido';
              }

              return null;
            },
          )
              .animate()
              .fade(
            delay: 120.ms,
            duration: 500.ms,
          )
              .slideX(
            begin: -.12,
            end: 0,
            duration: 500.ms,
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
            TextInputAction.done,
            validator: (value) {
              if (value == null ||
                  value.isEmpty) {
                return 'Ingrese su contraseña';
              }

              if (value.length < 8) {
                return
                  'La contraseña debe tener al menos 8 caracteres';
              }

              return null;
            },
          )
              .animate()
              .fade(
            delay: 220.ms,
            duration: 500.ms,
          )
              .slideX(
            begin: .12,
            end: 0,
            duration: 500.ms,
            curve:
            Curves.easeOutCubic,
          ),

          // ======================================================
          // OLVIDÉ CONTRASEÑA
          // ======================================================

          Align(
            alignment:
            Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                context.push(
                  AppRoutes
                      .forgotPassword,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor:
                AppColors.primary,
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
              ),
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
          )
              .animate()
              .fade(
            delay: 300.ms,
            duration: 450.ms,
          ),

          const SizedBox(
            height: 12,
          ),

          // ======================================================
          // BOTÓN LOGIN
          // ======================================================

          FSButton(
            text:
            'Iniciar sesión',
            isLoading:
            state.isLoading,
            onPressed:
            state.isLoading
                ? null
                : _login,
          )
              .animate()
              .fade(
            delay: 380.ms,
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
            delay: 450.ms,
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
            '¿No tienes una cuenta?',
            actionText:
            'Regístrate',
            onPressed: () {
              context.push(
                AppRoutes.register,
              );
            },
          )
              .animate()
              .fade(
            delay: 520.ms,
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
// HEADER LOGIN
// ============================================================

class _LoginHeader
    extends StatelessWidget {
  const _LoginHeader();

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
                text: 'Bienvenido a ',
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
                text: 'FitSense',
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
          'Continúa con tu entrenamiento inteligente.',
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