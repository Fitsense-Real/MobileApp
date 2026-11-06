import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/kora_ui.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Kora.forest,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/kora/welcome.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x350F2E25), Color(0x700F2E25), Kora.forest],
                  stops: [0, .52, 1],
                ),
              ),
            ),
            Positioned(
              top: 30,
              left: 0,
              right: 0,
              height: 150,
              child: CustomPaint(
                painter: KoraPattern(color: Kora.lime.withValues(alpha: .18)),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 30,
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: constraints.maxHeight > 650
                                  ? constraints.maxHeight * .21
                                  : 65,
                            ),
                            Text.rich(
                              const TextSpan(
                                text: 'Tu rutina\n',
                                children: [
                                  TextSpan(
                                    text: 'también\ncuenta.',
                                    style: TextStyle(color: Kora.lime),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: constraints.maxWidth < 360 ? 44 : 56,
                                height: 1.04,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2,
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Pequeños pasos,\ngrandes cambios sostenibles.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFE1E6DE),
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                                height: 1.7,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 55),
                            SizedBox(
                              height: 76,
                              child: KoraButton(
                                label: 'COMENZAR AHORA',
                                lime: true,
                                onPressed: () =>
                                    context.push(AppRoutes.register),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const KoraLabel(
                                  '¿YA ERES PARTE?',
                                  color: Color(0xFFB0BDA5),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      context.push(AppRoutes.login),
                                  child: const Text(
                                    'INICIA SESIÓN',
                                    style: TextStyle(
                                      color: Kora.lime,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
