import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dio_provider.dart';

import '../../data/datasource/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';

import '../../domain/usecases/get_current_user_use_case.dart';
import '../../domain/usecases/login_use_case.dart';
import '../../domain/usecases/logout_use_case.dart';
import '../../domain/usecases/register_use_case.dart';

import '../state/auth_state.dart';
import '../viewmodels/auth_viewmodel.dart';

final authRemoteDataSourceProvider =
Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(
    ref.read(dioProvider),
  );
});

final authRepositoryProvider =
Provider<AuthRepositoryImpl>((ref) {

  return AuthRepositoryImpl(
    ref.read(authRemoteDataSourceProvider),
  );
});

final loginUseCaseProvider =
Provider<LoginUseCase>((ref) {
  return LoginUseCase(
    ref.read(authRepositoryProvider),
  );
});

final registerUseCaseProvider =
Provider<RegisterUseCase>((ref) {
  return RegisterUseCase(
    ref.read(authRepositoryProvider),
  );
});

final logoutUseCaseProvider =
Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(
    ref.read(authRepositoryProvider),
  );
});

final currentUserUseCaseProvider =
Provider<GetCurrentUserUseCase>((ref) {
  return GetCurrentUserUseCase(
    ref.read(authRepositoryProvider),
  );
});

final authViewModelProvider =
NotifierProvider<AuthViewModel, AuthState>(
  AuthViewModel.new,
);