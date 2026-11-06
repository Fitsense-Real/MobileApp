import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

class AuthCard extends StatelessWidget {
  final Widget child;

  const AuthCard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(
        24,
        26,
        24,
        24,
      ),

      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,

        borderRadius: BorderRadius.circular(
          AppRadius.xl,
        ),

        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
        ),

        boxShadow: isDark
            ? const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ]
            : const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 25,
            offset: Offset(0, 10),
          ),
        ],
      ),

      child: child,
    );
  }
}