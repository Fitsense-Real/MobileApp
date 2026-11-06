import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/presentation/providers/auth_provider.dart';
import '../services/session_service.dart';

final sessionServiceProvider =
Provider<SessionService>((ref) {
  return SessionService(
    ref.read(currentUserUseCaseProvider),
  );
});