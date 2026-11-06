import 'package:flutter/material.dart';

class AchievementCard extends StatelessWidget {
  const AchievementCard({super.key});

  @override
  Widget build(BuildContext context) {

    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.emoji_events,
          size: 40,
        ),
        title: const Text(
          "7 días consecutivos",
        ),
        subtitle: const Text(
          "¡Sigue así!",
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
        ),
      ),
    );
  }
}