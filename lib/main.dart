import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

final class Logger extends ProviderObserver {
  @override
  void didAddProvider(
      ProviderObserverContext context,
      Object? value,
      ) {
    debugPrint("Provider agregado: ${context.provider}");
  }

  @override
  void providerDidFail(
      ProviderObserverContext context,
      Object error,
      StackTrace stackTrace,
      ) {
    debugPrint("ERROR EN PROVIDER");
    debugPrint(error.toString());
    debugPrint(stackTrace.toString());
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      observers: [Logger()],
      child: const FitSenseApp(),
    ),
  );
}