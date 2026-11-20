/// Same rules as the backend (`@NotBlank @Size(min = 8, max = 72)`) for sign-up
/// and password recovery. A password made only of spaces passed the app and
/// the backend rejected it; in recovery that 400 read as "invalid code".
String? passwordProblem(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Ingresa una contraseña';
  if (password.trim().isEmpty) return 'La contraseña no puede ser solo espacios';
  if (password.length < 8 || password.length > 72) return 'Usa entre 8 y 72 caracteres';
  return null;
}
