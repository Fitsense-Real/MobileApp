import 'package:flutter/material.dart';

class TodayWorkoutCard extends StatelessWidget {
  const TodayWorkoutCard({super.key});

  @override
  Widget build(BuildContext context) {

    return Card(
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [

            const Text(
              "🔥 Rutina de hoy",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              "Piernas y Glúteos",
              style: TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 8),

            const Text(
              "35 minutos",
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                child: const Text(
                  "Comenzar entrenamiento",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}