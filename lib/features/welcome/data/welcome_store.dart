import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum TourStatus { notStarted, inProgress, completed }

/// What the welcome flow needs to survive closing the app, per user.
class WelcomeProgress {
  const WelcomeProgress({this.tourStatus = TourStatus.notStarted, this.tourStep = 0, this.operationId});
  final TourStatus tourStatus;
  final int tourStep;

  /// First-plan generation operation to resume polling.
  final String? operationId;

  WelcomeProgress copyWith({TourStatus? tourStatus, int? tourStep, String? operationId, bool clearOperation = false}) =>
      WelcomeProgress(
        tourStatus: tourStatus ?? this.tourStatus,
        tourStep: tourStep ?? this.tourStep,
        operationId: clearOperation ? null : operationId ?? this.operationId,
      );

  Map<String, Object?> toJson() => {'tourStatus': tourStatus.name, 'tourStep': tourStep, 'operationId': operationId};

  factory WelcomeProgress.fromJson(Map<String, dynamic> json) => WelcomeProgress(
    tourStatus: TourStatus.values.where((s) => s.name == json['tourStatus']).firstOrNull ?? TourStatus.notStarted,
    tourStep: (json['tourStep'] as num?)?.toInt() ?? 0,
    operationId: json['operationId'] as String?,
  );
}

/// Persists the welcome progress in the secure storage, keyed by user id, so
/// two accounts on the same phone never share it.
class WelcomeStore {
  WelcomeStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  String _key(int userId) => 'kora_welcome_$userId';

  Future<WelcomeProgress> load(int userId) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      return raw == null ? const WelcomeProgress() : WelcomeProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const WelcomeProgress();
    }
  }

  Future<void> save(int userId, WelcomeProgress progress) async {
    try {
      await _storage.write(key: _key(userId), value: jsonEncode(progress.toJson()));
    } catch (_) {/* best effort: the next step saves again */}
  }

  /// Pending updates per user. The tour and the generation controller both
  /// read-modify-write the same entry at the same time; chaining them stops
  /// one from overwriting the other (e.g. the tour step being lost).
  final _queues = <int, Future<void>>{};

  Future<WelcomeProgress> update(int userId, WelcomeProgress Function(WelcomeProgress) change) {
    final done = Completer<WelcomeProgress>();
    _queues[userId] = (_queues[userId] ?? Future<void>.value()).then((_) async {
      try {
        final next = change(await load(userId));
        await save(userId, next);
        done.complete(next);
      } catch (e, stack) {
        done.completeError(e, stack);
      }
    });
    return done.future;
  }
}

final welcomeStoreProvider = Provider((ref) => WelcomeStore());
