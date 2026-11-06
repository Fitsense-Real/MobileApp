import 'package:flutter/material.dart';

import '../constants/app_radius.dart';

class FSCard extends StatelessWidget {
  final Widget child;

  const FSCard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(
          AppRadius.lg,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: child,
    );
  }
}