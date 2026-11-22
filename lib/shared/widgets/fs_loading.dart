import 'package:material_ui/material_ui.dart';

class FSLoading extends StatelessWidget {
  const FSLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}