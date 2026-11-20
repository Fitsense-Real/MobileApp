import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/api_error.dart';
import 'package:fitsense_mobile/features/onboarding/data/profile_repository.dart';
import 'package:fitsense_mobile/features/onboarding/domain/minimum_age.dart';

/// 422 copied from backend 5977d28 (POST /users/me/profile with a 17-year-old).
class AgeBackend implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? stream, Future<void>? cancel) async =>
      ResponseBody.fromString(jsonEncode({'status': 422, 'error': 'Unprocessable Entity', 'message': 'Debes tener al menos 18 anos para usar la aplicacion.', 'details': []}), 422,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  @override
  void close({bool force = false}) {}
}

void main() {
  final today = DateTime(2026, 11, 20, 15, 30);

  group('ageOn', () {
    test('turning 18 today counts as 18 (from 00:00)', () {
      expect(ageOn(DateTime(2008, 11, 20), today), 18);
      expect(ageOn(DateTime(2008, 11, 20), DateTime(2026, 11, 20)), 18);
    });
    test('the day before the 18th birthday is still 17', () {
      expect(ageOn(DateTime(2008, 11, 21), today), 17);
      expect(ageOn(DateTime(2009, 11, 20), today), 17);
    });
    test('an adult and someone born on February 29', () {
      expect(ageOn(DateTime(1990, 3, 10), today), 36);
      expect(ageOn(DateTime(2008, 2, 29), DateTime(2026, 2, 28)), 17);
      expect(ageOn(DateTime(2008, 2, 29), DateTime(2026, 3, 1)), 18);
    });
  });

  test('the minimum age is the backend one and the message is clear Spanish', () {
    expect(minimumAge, 18);
    expect(minimumAgeMessage, 'Para participar en Kora debes tener al menos 18 años.');
  });

  test('the backend 422 for a minor becomes the clear message, not "18 anos"', () async {
    final repository = ProfileRepository(Dio(BaseOptions(baseUrl: 'http://localhost:8080/api/v1'))..httpClientAdapter = AgeBackend());
    await expectLater(
      repository.save({'birthDate': '2009-11-20'}, exists: false),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', minimumAgeMessage).having((e) => e.statusCode, 'status', 422)),
    );
  });

  test('other 422s keep their own handling', () {
    expect(isMinimumAgeRejection(422, 'El perfil ya existe.'), isFalse);
    expect(isMinimumAgeRejection(400, 'Debes tener al menos 18 anos para usar la aplicacion.'), isFalse);
  });
}
