import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

/// The signed-in account, for providers that read data of that account.
///
/// Watching it resets them when the account changes (no data of another
/// account is ever shown). When it is null the session has ended: they must
/// send nothing, because the token is already gone and the request could only
/// answer 401 (incidence I-01, three late requests after «Cerrar sesión»).
int? watchAccount(Ref ref) => ref.watch(authViewModelProvider.select((s) => s.user?.id));
