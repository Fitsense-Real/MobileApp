import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import 'kora_ui.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const KoraLogo(width: 110),

        const SizedBox(
          height: AppSpacing.lg,
        ),

        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(
          height: AppSpacing.sm,
        ),

        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
