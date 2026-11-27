// Spanish labels for the catalog codes that reach the app in English
// (`bodyPart`, `targetMuscle`, `secondaryMuscles` of the exercise catalog,
// from the ExerciseDB dataset). Closed tables: an unknown code is omitted,
// never shown raw. Equipment names come from the catalog itself
// (`GET /catalog/equipment-types` → `nameEs`).

const bodyPartLabels = <String, String>{
  'back': 'Espalda',
  'cardio': 'Cardio',
  'chest': 'Pecho',
  'lower arms': 'Antebrazos',
  'lower legs': 'Piernas (pantorrillas)',
  'neck': 'Cuello',
  'shoulders': 'Hombros',
  'upper arms': 'Brazos',
  'upper legs': 'Piernas (muslos)',
  'waist': 'Abdomen y cintura',
};

const muscleLabels = <String, String>{
  'abductors': 'abductores',
  'abs': 'abdominales',
  'adductors': 'aductores',
  'biceps': 'bíceps',
  'calves': 'pantorrillas',
  'cardiovascular system': 'sistema cardiovascular',
  'delts': 'deltoides',
  'deltoids': 'deltoides',
  'rear deltoids': 'deltoides posteriores',
  'forearms': 'antebrazos',
  'glutes': 'glúteos',
  'hamstrings': 'isquiotibiales',
  'lats': 'dorsales',
  'latissimus dorsi': 'dorsales',
  'levator scapulae': 'elevador de la escápula',
  'pectorals': 'pectorales',
  'chest': 'pecho',
  'upper chest': 'parte superior del pecho',
  'quads': 'cuádriceps',
  'quadriceps': 'cuádriceps',
  'serratus anterior': 'serrato anterior',
  'spine': 'zona lumbar',
  'lower back': 'zona lumbar',
  'back': 'espalda',
  'upper back': 'parte alta de la espalda',
  'traps': 'trapecios',
  'trapezius': 'trapecios',
  'rhomboids': 'romboides',
  'triceps': 'tríceps',
  'shoulders': 'hombros',
  'rotator cuff': 'manguito rotador',
  'core': 'zona media (core)',
  'obliques': 'oblicuos',
  'hip flexors': 'flexores de la cadera',
  'groin': 'ingle',
  'inner thighs': 'cara interna del muslo',
  'brachialis': 'braquial',
  'soleus': 'sóleo',
  'shins': 'espinillas',
  'ankles': 'tobillos',
  'ankle stabilizers': 'estabilizadores del tobillo',
  'feet': 'pies',
  'hands': 'manos',
  'wrists': 'muñecas',
  'wrist flexors': 'flexores de la muñeca',
  'wrist extensors': 'extensores de la muñeca',
  'grip muscles': 'músculos de la prensión',
  'sternocleidomastoid': 'esternocleidomastoideo',
};

String? bodyPartLabel(Object? code) => bodyPartLabels['${code ?? ''}'.trim().toLowerCase()];

String? muscleLabel(Object? code) => muscleLabels['${code ?? ''}'.trim().toLowerCase()];

/// Known muscles in Spanish, without repetitions; unknown codes are dropped.
List<String> muscleList(Iterable<Object?> codes) {
  final out = <String>[];
  for (final code in codes) {
    final label = muscleLabel(code);
    if (label != null && !out.contains(label)) out.add(label);
  }
  return out;
}

/// «Descanso: 90 s» was read as a total; this says it is between series and
/// uses minutes when it is a minute or more.
String restLabel(num seconds) {
  final s = seconds.round();
  if (s < 60) return '$s s';
  final m = s ~/ 60, r = s % 60;
  return r == 0 ? '$m min' : '$m min $r s';
}
