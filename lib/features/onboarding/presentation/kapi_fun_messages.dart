import 'dart:math';
import '../../../shared/widgets/mascot/kora_mascot.dart';

/// What Kapi says on the generation screen. It only entertains: it never
/// talks about the plan being made, the server, AI, algorithms or how long
/// anything takes (the progress UI is the only place that says «Generando»).
/// `test/generation_screen_test.dart` rejects any message that does.
const kapiFunMessages = <(MascotMood, String)>[
  (MascotMood.explain, '¿Sabías que la constancia es más importante que la perfección?'),
  (MascotMood.motivate, '¡Un pequeño paso también cuenta!'),
  (MascotMood.welcome, '¿Team entrenamiento con música o en silencio?'),
  (MascotMood.explain, 'Cada persona tiene su propio ritmo. ¡Encuentra el tuyo!'),
  (MascotMood.welcome, '¡Tengo curiosidad! ¿Qué canción te motiva más?'),
  (MascotMood.success, 'Dato capibara: me encanta estirarme al despertar. ¿Y a ti?'),
  (MascotMood.motivate, 'Beber agua también es parte de entrenar. ¡Salud!'),
  (MascotMood.welcome, '¿Mañana, tarde o noche? Cada momento tiene su encanto.'),
  (MascotMood.explain, 'Respirar profundo un par de veces se siente genial. ¿Probamos?'),
  (MascotMood.success, 'Celebrar los avances pequeños hace que los grandes lleguen.'),
  (MascotMood.explain, '¿Sabías que dormir bien ayuda a que tus músculos se recuperen?'),
  (MascotMood.motivate, 'Moverse un poco cada día suma muchísimo.'),
  (MascotMood.success, '¡Choca esa pata! Hoy vamos con todo.'),
  (MascotMood.welcome, '¿Qué te gusta más: saltar, correr o bailar?'),
];

/// Hands out [kapiFunMessages] in a shuffled order without repeating one
/// until all were shown; a new round never starts with the last message.
class KapiMessageDeck {
  KapiMessageDeck([Random? random]) : _random = random ?? Random();
  final Random _random;
  final _queue = <int>[];
  int? _last;

  (MascotMood, String) next() {
    if (_queue.isEmpty) {
      _queue.addAll(List.generate(kapiFunMessages.length, (i) => i)..shuffle(_random));
      if (_queue.length > 1 && _queue.first == _last) _queue.add(_queue.removeAt(0));
    }
    _last = _queue.removeAt(0);
    return kapiFunMessages[_last!];
  }
}
