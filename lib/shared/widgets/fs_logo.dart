import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class FSLogo extends StatelessWidget {
  const FSLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Icon(
          Icons.fitness_center,
          size: 72,
          color: AppColors.primary,
        ),
        SizedBox(height: 12),
        Text(
          "FitSense",
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}