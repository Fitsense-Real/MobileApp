import 'package:fitsense_mobile/features/authentication/domain/password_rules.dart';
import 'package:fitsense_mobile/features/authentication/domain/email_format.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/config/study_config.dart';
import '../../../../shared/widgets/kora_ui.dart';
import '../../../../shared/widgets/fs_text_field.dart';
import '../../../consents/domain/legal_documents.dart';
import '../../../consents/presentation/document_reader_page.dart';
import '../../../plans/domain/plan_eligibility.dart';
import '../../domain/timezones.dart';
import '../providers/auth_provider.dart';

/// Documents of this build, overridable in tests.
final signUpDocumentsProvider = Provider<SignUpDocuments>((ref) => SignUpDocuments.fromConfig());

class KoraAuthForm extends ConsumerStatefulWidget {
  const KoraAuthForm({super.key, this.register = false});
  final bool register;
  @override
  ConsumerState<KoraAuthForm> createState() => _KoraAuthFormState();
}

class _KoraAuthFormState extends ConsumerState<KoraAuthForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  late String _timezone = StudyConfig.defaultTimezone;
  bool _consent = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  /// Documents opened and read to the end in this sign-up.
  final _read = <LegalDocument>{};

  /// Terms and privacy accepted (only after reading them).
  final _accepted = <LegalDocument>{};
  String? _documentsError;

  @override
  void dispose() {
    for (final c in [_name, _lastName, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  SignUpDocuments get _documents => ref.read(signUpDocumentsProvider);

  Future<void> _readDocument(LegalDocument document) async {
    final done = await DocumentReaderPage.open(context, document);
    if (!mounted || !done) return;
    setState(() { _read.add(document); _documentsError = null; });
  }

  /// Without the plans for non-participants, creating the account without
  /// taking part leads nowhere: say it before the account exists.
  Future<bool> _confirmWithoutParticipation() async {
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Crear la cuenta sin participar?'),
        content: const Text('Por ahora Kora prepara rutinas solo para las personas que participan en el estudio. '
            'Si creas la cuenta sin participar, no recibirás una rutina.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Revisar participación')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear sin participar')),
        ],
      ),
    );
    return create == true;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final model = ref.read(authViewModelProvider.notifier);
    if (!widget.register) {
      final ok = await model.login(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      if (ok) {
        context.go(AppRoutes.accountSetup);
      } else {
        _snack(ref.read(authViewModelProvider).errorMessage ?? 'No se pudo conectar. Inténtalo nuevamente.');
      }
      return;
    }
    final documents = _documents;
    if (documents.required.any((d) => !_accepted.contains(d))) {
      setState(() => _documentsError = 'Lee y acepta cada documento para crear la cuenta.');
      return;
    }
    if (!_consent && !ref.read(plansForNonParticipantsProvider) && !await _confirmWithoutParticipation()) return;
    if (!mounted) return;
    final email = _email.text.trim(), password = _password.text;
    final created = await model.register(
      firstName: _name.text.trim(),
      lastName: _lastName.text.trim(),
      timezone: _timezone,
      acceptsStudyParticipation: _consent,
      acceptedTermsVersion: documents.terms?.version,
      acceptedPrivacyVersion: documents.privacy?.version,
      email: email,
      password: password,
    );
    if (!mounted) return;
    if (!created) {
      final message = ref.read(authViewModelProvider).errorMessage;
      if (isOutdatedDocument(message) || isUnpublishedDocument(message)) {
        // The account was not created (same transaction in the backend).
        setState(() { _read.clear(); _accepted.clear(); });
        await showDialog<void>(context: context, builder: (context) => AlertDialog(
          title: const Text('Los documentos cambiaron'),
          content: Text(isOutdatedDocument(message)
              ? 'Se publicó una versión nueva de un documento. Tu cuenta no se creó. Actualiza la aplicación o vuelve a leer la versión vigente antes de aceptarla.'
              : 'Uno de los documentos todavía no está publicado. Tu cuenta no se creó. Inténtalo más tarde o contacta al equipo del estudio.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
        ));
      } else {
        _snack(message ?? 'No se pudo conectar. Inténtalo nuevamente.');
      }
      return;
    }
    // Same credentials, so the person does not type them again.
    final signedIn = await model.login(email: email, password: password);
    if (!mounted) return;
    if (signedIn) {
      context.go(AppRoutes.accountSetup);
    } else {
      context.go(AppRoutes.login);
      _snack('Cuenta creada. Inicia sesión para completar tu perfil.');
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Widget _documentTile(LegalDocument document, bool busy) {
    final read = _read.contains(document);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KoraCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${document.title} · versión ${document.version}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            TextButton(onPressed: busy ? null : () => _readDocument(document), child: Text(read ? 'Volver a leer' : 'Leer')),
          ]),
          Material(type: MaterialType.transparency, child: CheckboxListTile(
            key: Key('accept-${document.type.code}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _accepted.contains(document),
            onChanged: busy || !read ? null : (v) => setState(() { v == true ? _accepted.add(document) : _accepted.remove(document); _documentsError = null; }),
            title: Text(document.type.code == 'TERMS_OF_SERVICE' ? 'Acepto las condiciones de uso' : 'He leído la política de privacidad'),
            subtitle: read ? null : const Text('Primero léelo completo.'),
          )),
        ]),
      ),
    );
  }

  Widget _participation(bool busy) {
    final consentDoc = _documents.studyConsent;
    final mustRead = consentDoc != null && !_read.contains(consentDoc);
    final optional = ref.watch(plansForNonParticipantsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      const Text('Participación en el estudio', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 6),
      Text(
        optional
            ? 'Participar es opcional. Puedes usar Kora sin participar en el estudio.'
            : 'Kora se usa dentro de un estudio de 12 semanas y, por ahora, prepara rutinas solo para quienes participan.',
        style: const TextStyle(color: Kora.muted, fontSize: 14, height: 1.45),
      ),
      if (consentDoc != null) ...[
        const SizedBox(height: 4),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: busy ? null : () => _readDocument(consentDoc),
          icon: const Icon(Icons.description_outlined, size: 20),
          label: Text(mustRead ? 'Leer el consentimiento informado (versión ${consentDoc.version})' : 'Volver a leer el consentimiento informado'),
        )),
      ],
      CheckboxListTile(
        key: const Key('accept-study'),
        contentPadding: EdgeInsets.zero,
        value: _consent,
        onChanged: busy || mustRead ? null : (v) => setState(() => _consent = v ?? false),
        title: const Text('Acepto participar en el estudio'),
        subtitle: Text(mustRead
            ? 'Primero lee el consentimiento informado.'
            : optional ? 'Opcional. Déjalo desmarcado si no deseas participar.' : 'Sin participar podrás crear la cuenta, pero no recibirás una rutina.'),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authViewModelProvider).isLoading;
    final documents = widget.register ? ref.watch(signUpDocumentsProvider) : const SignUpDocuments();
    return KoraPage(
      maxWidth: 520,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.splash),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Volver',
              ),
              const KoraLogo(width: 86),
            ],
          ),
          const SizedBox(height: 38),
          KoraLabel(widget.register ? 'BIENVENIDO A KORA' : 'PORTAL DE ACCESO'),
          const SizedBox(height: 16),
          KoraHeading(
            widget.register ? 'Crear' : 'Entrena con',
            accent: widget.register ? 'Cuenta.' : 'Propósito.',
            subtitle: widget.register
                ? 'Empieza hoy tu camino personalizado hacia un mejor bienestar.'
                : 'Ingresa tus credenciales para acceder a tu panel de entrenamiento personalizado.',
          ),
          const SizedBox(height: 32),
          AutofillGroup(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.register) ...[
                    FSTextField(
                      controller: _name,
                      label: 'Nombres',
                      hint: 'Ej. Juan',
                      prefixIcon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty || (v ?? '').length > 100
                          ? 'Escribe tus nombres (máximo 100 caracteres)'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    FSTextField(controller: _lastName, label: 'Apellidos', prefixIcon: Icons.person_outline, validator: (v) => (v ?? '').length > 150 ? 'Máximo 150 caracteres' : null),
                    const SizedBox(height: 22),
                  ],
                  FSTextField(
                    controller: _email,
                    label: 'Correo electrónico',
                    hint: 'nombre@ejemplo.com',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) => looksLikeEmail(v) ? null : 'Ingresa un correo válido',
                  ),
                  const SizedBox(height: 22),
                  FSTextField(
                    controller: _password,
                    label: 'Contraseña',
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    validator: passwordProblem,
                  ),
                  if (widget.register) ...[
                    const SizedBox(height: 22),
                    FSTextField(
                      controller: _confirm,
                      label: 'Confirmar contraseña',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      validator: (v) => v != _password.text
                          ? 'Las contraseñas no coinciden'
                          : null,
                    ),
                  ],
                  if (!widget.register)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: ApiConstants.passwordRecoveryAvailable
                            ? () => context.push(AppRoutes.forgotPassword)
                            : () => showDialog<void>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Recuperar contraseña'),
                                    content: const Text('La recuperación de contraseña todavía no está disponible. Si no recuerdas tu clave, contacta al equipo del estudio.'),
                                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
                                  ),
                                ),
                        child: const Text('¿Olvidaste la clave?'),
                      ),
                    ),
                  const SizedBox(height: 22),
                  if (widget.register) ...[
                    DropdownButtonFormField<String>(
                      key: const Key('timezone'),
                      initialValue: timezoneOptions.containsKey(_timezone) ? _timezone : timezoneOptions.keys.first,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Zona horaria', prefixIcon: Icon(Icons.public)),
                      items: [for (final e in timezoneOptions.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
                      onChanged: busy ? null : (v) => setState(() => _timezone = v ?? _timezone),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 6, left: 4),
                      child: Text('Define el día de tus entrenamientos y la hora de los recordatorios.', style: TextStyle(color: Kora.muted, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                    if (documents.required.isNotEmpty) ...[
                      const Text('Documentos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 8),
                      for (final document in documents.required) _documentTile(document, busy),
                      if (_documentsError != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_documentsError!, style: TextStyle(color: Colors.red.shade800))),
                    ],
                    _participation(busy),
                    const SizedBox(height: 16),
                  ],
                  KoraButton(
                    label: widget.register ? 'CREAR CUENTA' : 'INICIAR SESIÓN',
                    busy: busy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: KoraLabel(
              widget.register
                  ? '¿YA TIENES UNA CUENTA?'
                  : '¿NO ERES MIEMBRO AÚN?',
            ),
          ),
          TextButton(
            onPressed: () => context.go(
              widget.register ? AppRoutes.login : AppRoutes.register,
            ),
            child: Text(
              widget.register ? 'Iniciar sesión' : 'Únete a la comunidad Kora',
            ),
          ),
        ],
      ),
    );
  }
}
