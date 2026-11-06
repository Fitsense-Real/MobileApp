import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  /// Emulador Android
  static String get baseUrl => const String.fromEnvironment('API_BASE_URL').isNotEmpty
      ? const String.fromEnvironment('API_BASE_URL')
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8080/api/v1'
          : 'http://localhost:8080/api/v1';

  // Authentication
  static const String login = "/auth/login";
  static const String register = "/auth/register";
  static const String me = "/users/me";
  static const profile = '/users/me/profile';
  static const equipment = '/catalog/equipment-types';
  static const forgotPassword = "/auth/forgot-password";
  static const resetPassword = "/auth/reset-password";
}
