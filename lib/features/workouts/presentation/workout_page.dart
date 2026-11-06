import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/kora_ui.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({
    super.key,
    this.title = 'Full body suave',
    this.strength = false,
  });
  final String title;
  final bool strength;
  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  Timer? timer;
  int remaining = 720, exercise = 0, sets = 0;
  bool playing = true;
  final weight = TextEditingController(text: '40');
  final reps = TextEditingController(text: '12');
  final form = GlobalKey<FormState>();
  final records = <({double weight, int reps})>[];
  static const exercises = [
    'Zancadas laterales',
    'Plancha alta',
    'Sentadillas',
    'Estiramiento',
  ];
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (playing && remaining > 0) {
        setState(() {
          remaining--;
          if (remaining == 0) playing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    weight.dispose();
    reps.dispose();
    super.dispose();
  }

  void registerSet() {
    if (!form.currentState!.validate()) return;
    setState(() {
      records.add((
        weight: double.parse(weight.text.replaceAll(',', '.')),
        reps: int.parse(reps.text),
      ));
      sets++;
      if (sets == 4) {
        playing = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final complete = remaining == 0 || sets == 4;
    final time =
        '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';
    return KoraPage(
      maxWidth: 560,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver',
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      widget.strength ? widget.title : 'En movimiento',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const KoraLabel('SESIÓN DE DEMOSTRACIÓN'),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('A tu ritmo'),
                    content: const Text(
                      'Puedes pausar la sesión en cualquier momento. Los registros de esta sesión se guardan solo mientras esta pantalla está abierta.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Entendido'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.info_outline),
                tooltip: 'Información',
              ),
            ],
          ),
          const SizedBox(height: 48),
          Center(
            child: SizedBox(
              width: 230,
              height: 230,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: remaining / 720,
                      strokeWidth: 9,
                      backgroundColor: const Color(0xFFE8EFD3),
                      color: Kora.forest,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        complete ? '¡Listo!' : time,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: Kora.forest,
                          letterSpacing: -2,
                        ),
                      ),
                      KoraLabel(
                        complete ? 'SESIÓN COMPLETADA' : 'TIEMPO RESTANTE',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: KoraLabel(
              widget.strength
                  ? 'SERIE ${sets < 4 ? sets + 1 : 4} DE 4'
                  : '30 SEG · MOVILIDAD',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.strength ? 'Press de banca' : exercises[exercise],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Kora.forest,
            ),
          ),
          const SizedBox(height: 24),
          if (!complete)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: exercise == 0
                      ? null
                      : () => setState(() => exercise--),
                  icon: const Icon(Icons.skip_previous),
                  tooltip: 'Anterior',
                ),
                const SizedBox(width: 24),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Kora.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(22),
                  ),
                  onPressed: () => setState(() => playing = !playing),
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  tooltip: playing ? 'Pausar' : 'Reanudar',
                ),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: () => setState(() {
                    if (exercise < exercises.length - 1) {
                      exercise++;
                    } else {
                      remaining = 0;
                      playing = false;
                    }
                  }),
                  icon: const Icon(Icons.skip_next),
                  tooltip: 'Siguiente',
                ),
              ],
            ),
          const SizedBox(height: 30),
          if (widget.strength && !complete)
            KoraCard(
              child: Form(
                key: form,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: weight,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Peso (kg)',
                            ),
                            validator: (v) {
                              final n = double.tryParse(
                                (v ?? '').replaceAll(',', '.'),
                              );
                              return n == null ||
                                      !n.isFinite ||
                                      n < 0 ||
                                      n > 500
                                  ? 'Peso inválido'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: reps,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Reps',
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return n == null || n < 1 || n > 200
                                  ? 'Reps inválidas'
                                  : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    KoraButton(
                      label: 'REGISTRAR SERIE',
                      onPressed: registerSet,
                    ),
                  ],
                ),
              ),
            ),
          if (!widget.strength && !complete)
            KoraCard(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/kora/mobility.jpg',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const KoraLabel('SIGUIENTE'),
                        const SizedBox(height: 6),
                        Text(
                          exercises[(exercise + 1) % exercises.length],
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Text(
                          '30 seg',
                          style: TextStyle(color: Kora.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          for (final (i, record) in records.indexed)
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Kora.sage),
              title: Text('Serie ${i + 1}'),
              trailing: Text('${record.weight} kg · ${record.reps} reps'),
            ),
          if (complete) ...[
            const Text(
              'Tu rutina también cuenta.\n¡Buen trabajo!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            KoraButton(
              label: 'VOLVER A RUTINAS',
              onPressed: () => context.pop(),
            ),
          ],
        ],
      ),
    );
  }
}
