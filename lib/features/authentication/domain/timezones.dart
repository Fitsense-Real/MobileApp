/// Time zones offered when signing up (IANA identifiers the backend accepts,
/// `UserTimezone`). A closed list: nothing typed by hand can reach the backend
/// (a free field let "Lima" through and the backend answered 400).
const timezoneOptions = <String, String>{
  'America/Lima': 'Perú (Lima)',
  'America/Bogota': 'Colombia (Bogotá)',
  'America/Guayaquil': 'Ecuador (Guayaquil)',
  'America/La_Paz': 'Bolivia (La Paz)',
  'America/Santiago': 'Chile (Santiago)',
  'America/Argentina/Buenos_Aires': 'Argentina (Buenos Aires)',
  'America/Sao_Paulo': 'Brasil (São Paulo)',
  'America/Caracas': 'Venezuela (Caracas)',
  'America/Panama': 'Panamá',
  'America/Mexico_City': 'México (Ciudad de México)',
  'America/New_York': 'Estados Unidos (Nueva York)',
  'Europe/Madrid': 'España (Madrid)',
};
