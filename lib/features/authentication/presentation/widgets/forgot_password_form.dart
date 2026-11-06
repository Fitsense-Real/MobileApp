import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/constants/app_colors.dart';
import '../../../../shared/constants/app_spacing.dart';
import '../../../../shared/widgets/auth_card.dart';
import '../../../../shared/widgets/fs_button.dart';
import '../../../../shared/widgets/fs_text_field.dart';
import '../../../../shared/widgets/page_header.dart';
import '../providers/forgot_password_provider.dart';

class ForgotPasswordForm extends ConsumerStatefulWidget {
  const ForgotPasswordForm({
    super.key,
  });

  @override
  ConsumerState<ForgotPasswordForm> createState() =>
      _ForgotPasswordFormState();
}

class _ForgotPasswordFormState
    extends ConsumerState<ForgotPasswordForm> {

  final _formKey = GlobalKey<FormState>();

  final _emailController =
  TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // ============================================================
  // ENVIAR CORREO DE RECUPERACIÓN
  // ============================================================

  Future<void> _sendEmail() async {

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await ref
        .read(
      forgotPasswordViewModelProvider
          .notifier,
    )
        .sendRecoveryEmail(
      _emailController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      context.go(
        AppRoutes.resetPassword,
      );

      return;
    }

    final error = ref
        .read(
      forgotPasswordViewModelProvider,
    )
        .errorMessage;

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          behavior:
          SnackBarBehavior.floating,
          backgroundColor:
          const Color(0xFF151B1D),
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(error),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {

    final state = ref.watch(
      forgotPasswordViewModelProvider,
    );

    final width =
        MediaQuery.of(context).size.width;

    final isMobile = width < 600;

    return Center(
      child: SingleChildScrollView(
        physics:
        const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal:
          isMobile ? 20 : 24,
          vertical:
          isMobile ? 28 : 40,
        ),
        child: ConstrainedBox(
          constraints:
          const BoxConstraints(
            maxWidth: 460,
          ),
          child: Column(
            children: [

              // ==================================================
              // ICONO SUPERIOR
              // ==================================================

              _RecoveryIcon(
                isMobile: isMobile,
              ),

              const SizedBox(
                height: AppSpacing.xl,
              ),

              // ==================================================
              // TARJETA
              // ==================================================

              AuthCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                    children: [

                      // ==========================================
                      // CABECERA
                      // ==========================================

                      const PageHeader(
                        title:
                        "¿Olvidaste tu contraseña?",
                        subtitle:
                        "No te preocupes. Ingresa el correo asociado a tu cuenta y te enviaremos un enlace para recuperar el acceso.",
                      )
                          .animate()
                          .fade(
                        duration:
                        550.ms,
                      )
                          .slideY(
                        begin: -.12,
                        end: 0,
                        duration:
                        550.ms,
                        curve:
                        Curves.easeOut,
                      ),

                      const SizedBox(
                        height:
                        AppSpacing.xxl,
                      ),

                      // ==========================================
                      // CORREO
                      // ==========================================

                      FSTextField(
                        controller:
                        _emailController,
                        label:
                        "Correo electrónico",
                        hint:
                        "ejemplo@correo.com",
                        prefixIcon:
                        Icons
                            .email_outlined,
                        keyboardType:
                        TextInputType
                            .emailAddress,
                        textInputAction:
                        TextInputAction
                            .done,
                        onFieldSubmitted:
                            (_) {
                          if (!state.isLoading) {
                            _sendEmail();
                          }
                        },
                        validator:
                            (value) {

                          if (value ==
                              null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return
                              "Ingrese su correo electrónico";
                          }

                          if (!RegExp(
                            r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$',
                          ).hasMatch(
                            value.trim(),
                          )) {
                            return
                              "Ingrese un correo válido";
                          }

                          return null;
                        },
                      )
                          .animate(
                        delay: 150.ms,
                      )
                          .fade(
                        duration:
                        500.ms,
                      )
                          .slideX(
                        begin: -.12,
                        end: 0,
                        duration:
                        500.ms,
                        curve:
                        Curves.easeOut,
                      ),

                      const SizedBox(
                        height:
                        AppSpacing.xxl,
                      ),

                      // ==========================================
                      // BOTÓN
                      // ==========================================

                      FSButton(
                        text:
                        "Enviar enlace",
                        isLoading:
                        state.isLoading,
                        onPressed:
                        state.isLoading
                            ? null
                            : _sendEmail,
                      )
                          .animate(
                        delay: 300.ms,
                      )
                          .fade(
                        duration:
                        550.ms,
                      )
                          .scale(
                        begin:
                        const Offset(
                          .96,
                          .96,
                        ),
                        end:
                        const Offset(
                          1,
                          1,
                        ),
                        duration:
                        550.ms,
                        curve:
                        Curves.easeOut,
                      ),

                      const SizedBox(
                        height:
                        AppSpacing.lg,
                      ),

                      // ==========================================
                      // VOLVER AL LOGIN
                      // ==========================================

                      TextButton.icon(
                        onPressed: state.isLoading
                            ? null
                            : () {
                          context.go(
                            AppRoutes.login,
                          );
                        },
                        icon: const Icon(
                          Icons
                              .arrow_back_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          "Volver al inicio de sesión",
                        ),
                        style:
                        TextButton.styleFrom(
                          foregroundColor:
                          AppColors.primary,
                          padding:
                          const EdgeInsets
                              .symmetric(
                            vertical: 14,
                          ),
                        ),
                      )
                          .animate(
                        delay: 450.ms,
                      )
                          .fade(
                        duration:
                        500.ms,
                      )
                          .slideY(
                        begin: .08,
                        end: 0,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // SEGURIDAD
              // ==================================================

              const _SecurityMessage()
                  .animate(
                delay: 600.ms,
              )
                  .fade(
                duration: 500.ms,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ICONO DE RECUPERACIÓN
// ============================================================

class _RecoveryIcon extends StatelessWidget {

  const _RecoveryIcon({
    required this.isMobile,
  });

  final bool isMobile;

  @override
  Widget build(BuildContext context) {

    final size =
    isMobile ? 68.0 : 76.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary
            .withValues(alpha: .10),
        border: Border.all(
          color: AppColors.primary
              .withValues(alpha: .35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary
                .withValues(alpha: .16),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons
            .lock_reset_rounded,
        size: isMobile ? 32 : 36,
        color: AppColors.primary,
      ),
    )
        .animate()
        .fade(
      duration: 600.ms,
    )
        .scale(
      begin:
      const Offset(.75, .75),
      end:
      const Offset(1, 1),
      duration: 650.ms,
      curve: Curves.easeOutBack,
    );
  }
}

// ============================================================
// MENSAJE DE SEGURIDAD
// ============================================================

class _SecurityMessage extends StatelessWidget {

  const _SecurityMessage();

  @override
  Widget build(BuildContext context) {

    return Row(
      mainAxisAlignment:
      MainAxisAlignment.center,
      children: const [

        Icon(
          Icons
              .verified_user_outlined,
          size: 14,
          color: Color(0xFF8D9999),
        ),

        SizedBox(
          width: 7,
        ),

        Text(
          "Tu información está protegida",
          style: TextStyle(
            color: Color(0xFF8D9999),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}