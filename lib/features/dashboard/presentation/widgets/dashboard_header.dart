import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    return Row(
      children: [

        const CircleAvatar(
          radius: 28,
          child: Icon(
            Icons.person,
            size: 30,
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [

              Text(
                "Buenos días 👋",
                style: theme.textTheme.bodyMedium,
              ),

              Text(
                "Daniel",
                style: theme.textTheme.headlineSmall,
              ),

              Text(
                "Continúa tu entrenamiento.",
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),

        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.notifications_none,
          ),
        ),
      ],
    );
  }
}