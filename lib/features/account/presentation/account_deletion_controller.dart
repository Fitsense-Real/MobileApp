import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../reminders/presentation/reminders_controller.dart';
import '../data/account_deletion_repository.dart';
import '../data/local_account_data.dart';

enum DeletionStatus {
  idle,

  /// Waiting for the backend.
  inProgress,

  /// 202: the account is deactivated and the backend completes the deletion.
  pending,

  /// 200: the backend deleted the account.
  completed,

  /// 404: the account no longer exists on the server.
  gone,

  /// Nothing was deleted; [AccountDeletionState.message] says why.
  failed,
}

class AccountDeletionState {
  const AccountDeletionState({this.status = DeletionStatus.idle, this.message, this.blockedUntil, this.alreadyRequested = false});
  final DeletionStatus status;
  final String? message;

  /// After a 429 the button stays disabled until this moment (`Retry-After`).
  final DateTime? blockedUntil;
  final bool alreadyRequested;

  bool blockedAt(DateTime now) => blockedUntil != null && now.isBefore(blockedUntil!);
}

final localAccountDataProvider = Provider((ref) => const LocalAccountData());

/// Clock of the controller, replaceable in tests.
final deletionClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Requests the deletion of the signed-in account with one `DELETE /users/me`.
/// It never reports a deletion the backend did not confirm, and it clears the
/// session and the local data only when the account is gone or deactivated
/// (200, 202, 404).
class AccountDeletionController extends Notifier<AccountDeletionState> {
  @override
  AccountDeletionState build() => const AccountDeletionState();

  Future<void> delete({required String password}) async {
    if (state.status == DeletionStatus.inProgress) return; // repeated taps
    final now = ref.read(deletionClockProvider)();
    if (state.blockedAt(now)) return; // respect the backend's Retry-After
    final user = ref.read(authViewModelProvider).user;
    if (user == null) {
      state = const AccountDeletionState(status: DeletionStatus.failed, message: 'Inicia sesión para eliminar tu cuenta.');
      return;
    }
    state = AccountDeletionState(status: DeletionStatus.inProgress, blockedUntil: state.blockedUntil);
    try {
      final result = await ref.read(accountDeletionRepositoryProvider).requestDeletion(password: password);
      await _forgetAccount(user.id);
      state = AccountDeletionState(
        status: result.outcome == DeletionOutcome.completed ? DeletionStatus.completed : DeletionStatus.pending,
        alreadyRequested: result.alreadyRequested,
      );
    } on DeletionFailure catch (e) {
      if (e.kind == DeletionFailureKind.alreadyGone) {
        await _forgetAccount(user.id);
        state = AccountDeletionState(status: DeletionStatus.gone, message: e.message);
        return;
      }
      state = AccountDeletionState(
        status: DeletionStatus.failed,
        message: e.message,
        blockedUntil: e.retryAfter == null ? null : now.add(e.retryAfter!),
      );
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
