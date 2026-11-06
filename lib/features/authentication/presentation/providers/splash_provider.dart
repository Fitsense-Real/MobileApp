import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/splash_viewmodel.dart';

final splashProvider =
AsyncNotifierProvider<SplashViewModel, bool>(
  SplashViewModel.new,
);