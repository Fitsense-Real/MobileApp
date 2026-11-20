/// Minimum age of the study, enforced by the backend when the profile is
/// created (`fitsense.profile.minimum-age=18`, backend 5977d28). The app checks
/// it first to explain it clearly; the backend remains the authority.
const minimumAge = 18;

const minimumAgeMessage = 'Para participar en Kora debes tener al menos $minimumAge años.';

/// Full years on [today] (calendar days, so a birthday counts from 00:00).
int ageOn(DateTime birth, DateTime today) {
  var years = today.year - birth.year;
  if (today.month < birth.month || (today.month == birth.month && today.day < birth.day)) years--;
  return years;
}

/// The backend's 422 for an under-age profile. Its text has no «ñ»
/// ("anos"), so the app shows [minimumAgeMessage] instead.
bool isMinimumAgeRejection(int? status, Object? message) =>
    status == 422 && '$message'.contains('al menos') && '$message'.contains('para usar la aplicacion');
