import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../reminders/presentation/reminders_controller.dart';
import '../data/account_deletion_repository.dart';
import '../data/local_account_data.dart';

enum DeletionStatus {
  idle,

  /// Re-authenticating or waiting for the backend.
  inProgress,

  /// The backend accepted the request (202): it will be processed later.
  pending,

  /// The backend deleted the account (200/204).
  completed,

  /// Nothing was deleted; [AccountDeletionState.message] says why.
  failed,
}

class AccountDeletionState {
  const AccountDeletionState({this.status = DeletionStatus.idle, this.message});
  final DeletionStatus status;
  final String? message;
}

final localAccountDataProvider = Provider((ref) => const LocalAccountData());

/// Requests the deletion of the signed-in account. It never reports a
/// deletion the backend did not confirm, and it only clears the session and
/// the local data once the backend completed or accepted the request.
class AccountDeletionController extends Notifier<AccountDeletionState> {
  @override
  AccountDeletionState build() => const AccountDeletionState();

  Future<void> delete({required String password}) async {
    if (state.status == DeletionStatus.inProgress) return; // repeated taps
    final user = ref.read(authViewModelProvider).user;
    if (user == null) {
      state = const AccountDeletionState(status: DeletionStatus.failed, message: 'Inicia sesión para eliminar tu cuenta.');
      return;
    }
    state = const AccountDeletionState(status: DeletionStatus.inProgress);
    final repository = ref.read(accountDeletionRepositoryProvider);
    try {
      await repository.reauthenticate(userId: user.id, email: user.email, password: password);
      final outcome = await repository.requestDeletion();
      await _forgetAccount(user.id);
      state = AccountDeletionState(status: outcome == DeletionOutcome.completed ? DeletionStatus.completed : DeletionStatus.pending);
    } on DeletionFailure catch (e) {
      state = AccountDeletionState(status: DeletionStatus.failed, message: e.message);
    } catch (_) {
      state = const AccountDeletionState(status: DeletionStatus.failed, message: 'No pudimos completar la solicitud. No se eliminó nada.');
    }
  }

  /// Reminders, tour progress, favourites, session: nothing of the account
  /// stays on this phone.
  Future<void> _forgetAccount(int userId) async {
    try {
      await ref.read(reminderSchedulerProvider).cancelAll();
    } catch (_) {}
    await ref.read(localAccountDataProvider).clear(userId);
    await ref.read(authViewModelProvider.notifier).logout();
  }

  void reset() => state = const AccountDeletionState();
}

final accountDeletionProvider = NotifierProvider<AccountDeletionController, AccountDeletionState>(AccountDeletionController.new);
