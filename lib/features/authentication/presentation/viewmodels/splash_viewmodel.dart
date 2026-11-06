import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';

class SplashViewModel extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(sessionServiceProvider).isAuthenticated();
  }
}