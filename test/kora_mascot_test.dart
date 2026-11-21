import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/shared/widgets/mascot/kora_mascot.dart';

void main() {
  test('every mood has its vector asset in the official palette', () {
    const official = {'#0F2E25', '#D9FF59', '#F7F5ED', '#7A9A7E', '#5E7865', '#F0F6D4'};
    const depth = {'#A3BCA6', '#C9D8C9', '#B6DB2E'}; // lighter/darker steps of sage and lime
    for (final mood in MascotMood.values) {
      final file = File(mood.asset);
      expect(file.existsSync(), isTrue, reason: mood.asset);
      final colors = RegExp(r'#[0-9A-Fa-f]{6}').allMatches(file.readAsStringSync()).map((m) => m.group(0)!.toUpperCase()).toSet();
      expect(colors.difference({...official, ...depth}), isEmpty, reason: '${mood.name} uses only Kora colours');
      expect(colors.containsAll({'#7A9A7E', '#D9FF59', '#0F2E25'}), isTrue, reason: 'sage body, lime, forest details');
    }
  });

  testWidgets('renders each expression with an accessible label', (tester) async {
    for (final mood in MascotMood.values) {
      await tester.pumpWidget(MaterialApp(home: Center(child: KoraMascot(mood: mood, size: 80))));
      await tester.pump(const Duration(milliseconds: 400)); // cross-fade from the previous mood ends
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.bySemanticsLabel(mood.semanticLabel), findsOneWidget);
    }
  });

  testWidgets('animates gently, and is static with reduced motion', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: KoraMascot(mood: MascotMood.waiting))));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const MaterialApp(home: MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: Center(child: KoraMascot(mood: MascotMood.waiting)),
    )));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('message bubble fits a 320 px screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: MediaQuery(
      data: MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.3), disableAnimations: true),
      child: Scaffold(body: Padding(padding: EdgeInsets.all(16), child: MascotMessage(
        mood: MascotMood.welcome,
        title: '¡Hola! Soy Kapi',
        message: 'Mientras preparamos tu primera rutina, te muestro cómo funciona Kora.',
      ))),
    )));
    expect(find.text('¡Hola! Soy Kapi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
