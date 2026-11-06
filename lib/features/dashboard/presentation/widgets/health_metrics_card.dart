import 'package:flutter/material.dart';

class HealthMetricsCard extends StatelessWidget {
  const HealthMetricsCard({super.key});

  Widget metric(
      String title,
      String value,
      IconData icon,
      ) {

    return Expanded(
      child: Column(
        children: [

          Icon(icon),

          const SizedBox(height: 8),

          Text(title),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [

            metric(
              "Peso",
              "78 kg",
              Icons.monitor_weight,
            ),

            metric(
              "IMC",
              "24.3",
              Icons.favorite,
            ),

            metric(
              "Kcal",
              "2350",
              Icons.local_fire_department,
            ),
          ],
        ),
      ),
    );
  }
}