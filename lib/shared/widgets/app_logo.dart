import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({
    super.key,
    this.size = 90,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,

      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size / 2),

        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 25,
            offset: Offset(0, 10),
          ),
        ],
      ),

      child: Icon(
        Icons.fitness_center_rounded,
        color: Colors.white,
        size: size * .45,
      ),
    );
  }
}