import 'package:flutter/material.dart';

class AIRecommendationCard extends StatelessWidget {
  const AIRecommendationCard({super.key});

  @override
  Widget build(BuildContext context) {

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: const [

            Row(
              children: [

                Icon(Icons.auto_awesome),

                SizedBox(width: 8),

                Text(
                  "FitSense AI",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            Text(
              "Hoy tu rendimiento será mejor si aumentas ligeramente el peso y reduces el descanso entre series.",
            ),
          ],
        ),
      ),
    );
  }
}