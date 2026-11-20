/// One rule for every e-mail field (sign-up, login and password recovery).
///
/// The recovery screen used a stricter pattern than sign-up: it rejected `+`
/// and top-level domains longer than four letters, so someone registered as
/// `ana+kora@correo.com` could log in but never ask for a recovery code. The
/// backend decides whether the account exists; the app only filters typos.
bool looksLikeEmail(String? value) {
  final email = (value ?? '').trim();
  return email.length <= 254 && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
}
