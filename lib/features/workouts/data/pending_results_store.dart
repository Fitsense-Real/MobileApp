import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/json.dart';
import '../../../core/storage/secure_storage.dart';

/// P1 · results kept on the phone until the backend confirms them.
///
/// What it keeps: the exact body of a `PUT /sessions/{s}/exercises/{pe}` that could not be sent (no answer
/// from the backend, the answer was lost) or that the routine no longer allows (held). Never the JWT, the
/// email or anything else of the account; entries are tied to the account by its numeric id, never by the
/// token.
///
/// Where: the app's secure storage (Android Keystore / iOS Keychain), under its own key per account
/// (`kora_pending_results_<userId>`), separate from the session token's key and lifecycle.
///
/// Policy:
/// - Nothing is ever sent from here: the screen shows the results and only sends them through its own
///   flow (routine confirmed with the backend, exercise allowed, session checked if it may have arrived).
/// - Expiry: [maxAge] after it was entered. Expired entries are dropped when read.
/// - Another account on the same phone never sees them (own key, and every entry carries its user id).
/// - Logout keeps them for that same account, within [maxAge], so the person can recover them after
///   signing in again. Deleting the account removes them (LocalAccountData).
/// - A damaged or incomplete entry is dropped and reported; it is never sent.
class PendingResultsStore {
  const PendingResultsStore([this._storage = appSecureStorage, this._now = DateTime.now]);
  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  static const maxAge = Duration(hours: 48);
  static String keyOf(int userId) => 'kora_pending_results_$userId';

  /// The account's valid entries. Damaged or expired ones are dropped (and the store rewritten).
  /// Throws [PendingStoreException] when the storage cannot be read at all.
  Future<PendingLoad> load(int userId) async {
    final String? raw;
    try {
      raw = await _storage.read(key: keyOf(userId));
    } catch (_) {
      throw const PendingStoreException('No se pudieron leer los resultados guardados en este teléfono.');
    }
    if (raw == null || raw.isEmpty) return const PendingLoad([]);
    final entries = <PendingResult>[];
    var damaged = false, expired = 0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException();
      for (final item in decoded) {
        final entry = item is Map ? PendingResult.tryParse(Map<String, dynamic>.from(item)) : null;
        if (entry == null || entry.userId != userId) {
          damaged = true;
        } else if (_now().difference(entry.savedAt) > maxAge) {
          expired++;
        } else {
          entries.add(entry);
        }
      }
    } catch (_) {
      damaged = true;
      entries.clear();
    }
    if (damaged || expired > 0) await save(userId, entries);
    return PendingLoad(entries, damaged: damaged, expired: expired);
  }

  /// Replaces the account's entries. Throws [PendingStoreException] when the storage cannot be written.
  Future<void> save(int userId, List<PendingResult> entries) async {
    try {
      if (entries.isEmpty) {
        await _storage.delete(key: keyOf(userId));
      } else {
        await _storage.write(key: keyOf(userId), value: jsonEncode([for (final e in entries) e.toJson()]));
      }
    } catch (_) {
      throw const PendingStoreException('No se pudo guardar el resultado en este teléfono.');
    }
  }

  Future<void> clear(int userId) => save(userId, const []);
}

final pendingResultsStoreProvider = Provider((ref) => const PendingResultsStore());

class PendingStoreException implements Exception {
  const PendingStoreException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PendingLoad {
  const PendingLoad(this.entries, {this.damaged = false, this.expired = 0});
  final List<PendingResult> entries;

  /// Some entry could not be read: it was dropped and must be reported, never sent.
  final bool damaged;

  /// Entries dropped because they were older than [PendingResultsStore.maxAge].
  final int expired;
}

/// Where a kept result stands. Mirrors the screen's maps.
enum PendingState {
  /// Not sent: the routine could not be confirmed.
  pending,

  /// Its request may have reached the backend (answer lost): looked up in the session before repeating.
  maybeSent,

  /// Will never be sent: the routine no longer allows it. Only for review or discarding.
  held,
}

class PendingResult {
  const PendingResult({required this.userId, required this.sessionId, required this.plannedWorkoutId,
      required this.plannedExerciseId, required this.body, required this.state, required this.savedAt});

  final int userId;
  final int sessionId;
  final int plannedWorkoutId;
  final int plannedExerciseId;

  /// Exactly what would be sent (`actualSets`, `actualRepsTotal`, `actualDurationSeconds`, `actualLoadKg`,
  /// `skipReason`), so partial results keep their real amounts (D-M1).
  final Json body;
  final PendingState state;
  final DateTime savedAt;

  static const bodyKeys = {'actualSets', 'actualRepsTotal', 'actualDurationSeconds', 'actualLoadKg', 'skipReason'};

  Json toJson() => {
    'v': 1, 'userId': userId, 'sessionId': sessionId, 'plannedWorkoutId': plannedWorkoutId,
    'plannedExerciseId': plannedExerciseId, 'body': body, 'state': state.name, 'savedAt': savedAt.toUtc().toIso8601String(),
  };

  /// Null for anything incomplete or unexpected: such an entry is dropped, never sent.
  static PendingResult? tryParse(Json json) {
    int? id(Object? v) => v is int ? v : null;
    final body = json['body'];
    final state = PendingState.values.where((s) => s.name == json['state']).firstOrNull;
    final savedAt = DateTime.tryParse('${json['savedAt']}');
    if (json['v'] != 1 || id(json['userId']) == null || id(json['sessionId']) == null || id(json['plannedWorkoutId']) == null ||
        id(json['plannedExerciseId']) == null || body is! Map || state == null || savedAt == null) {
      return null;
    }
    final values = Map<String, dynamic>.from(body);
    if (values.keys.any((k) => !bodyKeys.contains(k))) return null;
    for (final k in ['actualSets', 'actualRepsTotal', 'actualDurationSeconds']) {
      final v = values[k];
      if (v != null && (v is! num || v < 0)) return null;
    }
    if (values['actualLoadKg'] != null && values['actualLoadKg'] is! num) return null;
    if (values['skipReason'] != null && values['skipReason'] is! String) return null;
    return PendingResult(userId: json['userId'] as int, sessionId: json['sessionId'] as int, plannedWorkoutId: json['plannedWorkoutId'] as int,
        plannedExerciseId: json['plannedExerciseId'] as int, body: values, state: state, savedAt: savedAt);
  }
}
