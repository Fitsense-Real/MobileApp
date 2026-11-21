import 'package:material_ui/material_ui.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/kora_ui.dart';

/// Shown instead of Kora when a release was built without a valid backend
/// URL. It makes the mistake visible at once and connects nowhere.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.problem});
  final String problem;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          backgroundColor: Kora.ivory,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_outlined, size: 56, color: Kora.forest),
                  const SizedBox(height: 18),
                  const Text('Kora no está configurada', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Kora.forest)),
                  const SizedBox(height: 10),
                  Text(problem, textAlign: TextAlign.center, style: const TextStyle(color: Kora.muted, height: 1.5)),
                  const SizedBox(height: 10),
                  const Text('Esta versión no puede conectarse con el servidor de Kora.', textAlign: TextAlign.center,
                      style: TextStyle(color: Kora.muted, height: 1.5)),
                ]),
              ),
            ),
          ),
        ),
      );
}
