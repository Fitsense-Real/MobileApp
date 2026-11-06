import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

class FSTextField extends StatefulWidget {
  final TextEditingController controller;

  final String label;

  final String? hint;

  final IconData prefixIcon;

  final bool isPassword;

  final TextInputType keyboardType;

  final TextInputAction? textInputAction;

  final String? Function(String?)? validator;

  final void Function(String)? onChanged;

  final void Function(String)? onFieldSubmitted;

  const FSTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.hint,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted
  });

  @override
  State<FSTextField> createState() => _FSTextFieldState();
}

class _FSTextFieldState extends State<FSTextField> {
  bool _obscureText = true;
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final border = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    final textColor = isDark
        ? AppColors.darkText
        : AppColors.lightText;

    final surfaceColor = isDark
        ? AppColors.darkSurfaceElevated
        : Colors.white;

    return Focus(
      onFocusChange: (focused) {
        setState(() {
          _hasFocus = focused;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            AppRadius.lg,
          ),
          boxShadow: _hasFocus
              ? [
            BoxShadow(
              color: AppColors.primary.withValues(
                alpha: 0.10,
              ),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ]
              : null,
        ),
        child: TextFormField(
          controller: widget.controller,

          keyboardType: widget.keyboardType,

          textInputAction: widget.textInputAction,

          onFieldSubmitted:
          widget.onFieldSubmitted,

          validator: widget.validator,

          onChanged: widget.onChanged,

          enableSuggestions: !widget.isPassword,

          autocorrect: !widget.isPassword,

          obscureText: widget.isPassword
              ? _obscureText
              : false,

          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),

          cursorColor: AppColors.primary,

          decoration: InputDecoration(
            labelText: widget.label,

            hintText: widget.hint,

            prefixIcon: AnimatedContainer(
              duration: const Duration(
                milliseconds: 200,
              ),
              child: Icon(
                widget.prefixIcon,
                color: _hasFocus
                    ? AppColors.primary
                    : null,
              ),
            ),

            suffixIcon: widget.isPassword
                ? IconButton(
              tooltip: _obscureText
                  ? 'Mostrar contraseña'
                  : 'Ocultar contraseña',
              onPressed: () {
                setState(() {
                  _obscureText =
                  !_obscureText;
                });
              },
              icon: AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 180,
                ),
                transitionBuilder:
                    (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Icon(
                  _obscureText
                      ? Icons
                      .visibility_off_outlined
                      : Icons
                      .visibility_outlined,
                  key: ValueKey(
                    _obscureText,
                  ),
                ),
              ),
            )
                : null,

            filled: true,

            fillColor: surfaceColor,

            contentPadding:
            const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 18,
            ),

            labelStyle: TextStyle(
              color: _hasFocus
                  ? AppColors.primary
                  : null,
              fontWeight: FontWeight.w500,
            ),

            hintStyle: TextStyle(
              color: isDark
                  ? const Color(0xFF6F7A7A)
                  : const Color(0xFF929999),
              fontSize: 14,
            ),

            prefixIconColor: _hasFocus
                ? AppColors.primary
                : null,

            enabledBorder: OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                AppRadius.lg,
              ),
              borderSide: BorderSide(
                color: border,
                width: 1,
              ),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                AppRadius.lg,
              ),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.6,
              ),
            ),

            errorBorder: OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                AppRadius.lg,
              ),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1,
              ),
            ),

            focusedErrorBorder:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(
                AppRadius.lg,
              ),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}