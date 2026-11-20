import 'package:fitsense_mobile/core/api/api_error.dart';
import 'package:fitsense_mobile/features/authentication/domain/password_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Independent review: a password of only spaces passed the app; the backend
  // (@NotBlank) rejected it and recovery showed "invalid code".
  test('passwords follow the backend rules (@NotBlank, 8-72)', () {
    expect(passwordProblem(null), isNotNull);
    expect(passwordProblem(''), isNotNull);
    expect(passwordProblem(' ' * 10), 'La contraseña no puede ser solo espacios');
    expect(passwordProblem('corta'), 'Usa entre 8 y 72 caracteres');
    expect(passwordProblem('x' * 73), 'Usa entre 8 y 72 caracteres');
    expect(passwordProblem('clave con espacios'), isNull);
    expect(passwordProblem('x' * 72), isNull);
  });

  test('release builds do not tell participants about port 8080', () {
    expect(connectionErrorMessage(debug: false), isNot(contains('8080')));
    expect(connectionErrorMessage(debug: false), contains('conexión'));
    expect(connectionErrorMessage(debug: true), contains('8080'));
  });
}
