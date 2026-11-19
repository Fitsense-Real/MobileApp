import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/config_error_app.dart';
import 'core/api/api_config.dart';

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

  // A release without a valid HTTPS backend URL never starts the real app.
  final api = ApiConfig.current;
  if (!api.isValid) {
    runApp(ConfigErrorApp(problem: api.problem!));
    return;
  }

  runApp(
    ProviderScope(
      // The provider log prints errors with their details: debug builds only,
      // never in the logcat of a published app.
      observers: [if (kDebugMode) Logger()],
      child: const FitSenseApp(),
    ),
  );
}