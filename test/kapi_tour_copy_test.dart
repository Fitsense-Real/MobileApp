import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/welcome/presentation/tour/tour_steps.dart';

/// Kapi accompanies, entertains and motivates: in the welcome tour it never
/// talks about the plan being generated, prepared or synced, internal
/// processes or waiting times (same rule as on the generation screen).
void main() {
  const forbidden = [
    'prepar', 'genera', 'sincroniz', 'proces', 'esper', 'cuando esté lista', 'aparecerá', 'primera rutina',
    'backend', 'servidor', 'inteligencia', 'algoritm', 'segundo', 'minuto', 'tardar', 'cargando',
  ];

  test('no tour message (first time or replay) mentions generation, processes or waiting', () {
    for (final step in welcomeTourSteps) {
      for (final text in [step.title, step.message, if (step.replayMessage != null) step.replayMessage!]) {
        final lower = text.toLowerCase();
        for (final word in forbidden) {
          expect(RegExp('(^|[^a-záéíóúñü])$word').hasMatch(lower), isFalse, reason: '«$text» contains «$word»');
        }
        expect(RegExp(r'\bia\b').hasMatch(lower), isFalse, reason: '«$text» mentions IA');
      }
    }
  });

  test('Kapi still greets in first person and keeps the tour short and friendly', () {
    expect(welcomeTourSteps.first.title, '¡Hola! Soy Kapi');
    expect(welcomeTourSteps.first.message, contains('Te acompaño'));
  });
}
