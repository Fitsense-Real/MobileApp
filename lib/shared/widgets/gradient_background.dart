import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,

        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
            Color(0xFF050606),
            Color(0xFF0B0E0E),
          ]
              : const [
            Color(0xFFF5F7F7),
            Color(0xFFFFFFFF),
          ],
        ),
      ),

      child: child,
    );
  }
}