import 'package:fitsense_mobile/features/authentication/domain/password_rules.dart';
import 'package:fitsense_mobile/features/authentication/domain/email_format.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/config/study_config.dart';
import '../../../../shared/widgets/kora_ui.dart';
import '../../../../shared/widgets/fs_text_field.dart';
import '../../../consents/data/consents_repository.dart';
import '../../../consents/data/document_text_repository.dart';
import '../../../consents/domain/legal_documents.dart';
import '../../../consents/presentation/document_acceptance.dart';
import '../../../consents/presentation/document_reader_page.dart';
import '../../domain/timezones.dart';
import '../providers/auth_provider.dart';

class KoraAuthForm extends ConsumerStatefulWidget {
  const KoraAuthForm({super.key, this.register = false, this.initialEmail});
  final bool register;
  final String? initialEmail;
  @override
  ConsumerState<KoraAuthForm> createState() => _KoraAuthFormState();
}

class _KoraAuthFormState extends ConsumerState<KoraAuthForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  late String _timezone = StudyConfig.defaultTimezone;

  /// Option A: the account exists only for people who accept to take part.
  bool _consent = false;
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  /// Terms and privacy accepted with their checkbox (never automatically).
  final _accepted = <LegalDocument>{};

  /// Documents that could not be shown: they cannot be accepted.
  final _unavailable = <ConsentType>{};
  String? _documentsError;
  bool _checking = false;

  @override
  void dispose() {
    for (final c in [_name, _lastName, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Opens the document only to read it: it never ticks the box. A document
  /// that cannot be shown cannot be accepted.
  Future<void> _openDocument(LegalDocument document) async {
    final shown = await DocumentReaderPage.open(context, document);
    if (!mounted || shown == null) return;
    setState(() => _setAvailable(document, shown));
  }

  void _setAvailable(LegalDocument document, bool available) {
    if (available) {
      _unavailable.remove(document.type);
      return;
    }
    _unavailable.add(document.type);
    if (document.type == ConsentType.studyParticipation) {
      _consent = false;
    } else {
      _accepted.remove(document);
    }
  }

  /// The person does not want to take part: Kora is only for participants, so
  /// no account is created and nothing typed is kept.
  Future<void> _decline() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No participar en el estudio'),
        content: const Text('Kora es exclusiva para las personas que participan en el estudio. '
            'Si no deseas participar, no se creará ninguna cuenta y no se guardará nada de lo que escribiste. '
            'Gracias por tu tiempo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver al registro')),
          TextButton(key: const Key('leave-sign-up'), onPressed: () => Navigator.pop(context, true), child: const Text('Salir del registro')),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    for (final c in [_name, _lastName, _email, _password, _confirm]) {
      c.clear();
    }
    setState(() { _consent = false; _accepted.clear(); _unavailable.clear(); });
    context.go(AppRoutes.splash);
  }

  /// The documents changed (or stopped being published) while the person was
  /// signing up: nothing was created; read them again as they are now.
  Future<void> _documentsChanged({required bool unpublished}) async {
    setState(() { _accepted.clear(); _unavailable.clear(); _consent = false; });
    ref.invalidate(publishedDocumentsProvider);
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Los documentos cambiaron'),
      content: Text(unpublished
          ? 'Uno de los documentos ya no está publicado. Tu cuenta no se creó. Inténtalo más tarde o contacta al equipo del estudio.'
          : 'Se publicó una versión nueva de un documento. Tu cuenta no se creó. Vuelve a leer la versión vigente y acéptala si estás de acuerdo.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
    ));
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
    final documents = ref.read(publishedDocumentsProvider).asData?.value;
    if (documents == null || !documents.signUpOpen) return;
    final shown = documents.toRead;
    if ([documents.terms!, documents.privacy!].any((d) => !_accepted.contains(d))) {
      setState(() => _documentsError = 'Para crear la cuenta marca la aceptación de los Términos y condiciones y de la Política de privacidad.');
      return;
    }
    if (!_consent) {
      setState(() => _documentsError = 'Kora es solo para participantes: marca «Acepto participar» o elige «No deseo participar».');
      return;
    }
    // What the person read must still be exactly what is published.
    setState(() => _checking = true);
    PublishedDocuments current;
    try {
      current = await ref.read(legalDocumentsRepositoryProvider).current();
    } catch (e) {
      if (mounted) { setState(() => _checking = false); _snack('No se pudo comprobar los documentos: ${apiError(e)} Tu cuenta no se creó.'); }
      return;
    }
    if (!mounted) return;
    setState(() => _checking = false);
    if (!current.signUpOpen || current.changedSince(shown)) {
      await _documentsChanged(unpublished: !current.signUpOpen);
      return;
    }
    // A document that cannot be shown cannot be accepted, even if its box was
    // ticked without opening it.
    final texts = ref.read(documentTextRepositoryProvider);
    final failed = <LegalDocument>[];
    setState(() => _checking = true);
    await Future.wait([for (final d in shown) texts.fetch(d.url).then((_) {}, onError: (_) => failed.add(d))]);
    if (!mounted) return;
    setState(() => _checking = false);
    if (failed.isNotEmpty) {
      setState(() {
        for (final d in failed) {
          _setAvailable(d, false);
        }
        _documentsError = 'No se pudo abrir: ${[for (final d in failed) DocumentReaderPage.titleOf(d.type)].join(', ')}. '
            'Un documento que no se puede mostrar no se puede aceptar. Tu cuenta no se creó; inténtalo de nuevo o contacta al equipo del estudio.';
      });
      return;
    }
    final email = _email.text.trim(), password = _password.text;
    final created = await model.register(
      firstName: _name.text.trim(),
      lastName: _lastName.text.trim(),
      timezone: _timezone,
      acceptsStudyParticipation: true,
      acceptedTermsVersion: documents.terms!.version,
      acceptedPrivacyVersion: documents.privacy!.version,
      acceptedStudyConsentVersion: documents.studyConsent!.version,
      email: email,
      password: password,
    );
    if (!mounted) return;
    if (!created) {
      final auth = ref.read(authViewModelProvider);
      final message = auth.errorMessage;
      if (isDocumentProblem(message, code: auth.errorCode)) {
        // The account was not created (same transaction in the backend).
        await _documentsChanged(unpublished: isUnpublishedDocument(message, code: auth.errorCode));
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

  Widget _acceptance(LegalDocument document, bool busy, {required String before, bool study = false}) {
    final unavailable = _unavailable.contains(document.type);
    return DocumentAcceptance(
      type: document.type,
      before: before,
      value: study ? _consent : _accepted.contains(document),
      checkboxKey: Key(study ? 'accept-study' : 'accept-${document.type.code}'),
      onOpen: busy ? null : () => _openDocument(document),
      onChanged: busy || unavailable ? null : (v) => setState(() {
        if (study) {
          _consent = v;
        } else {
          v ? _accepted.add(document) : _accepted.remove(document);
        }
        _documentsError = null;
      }),
      note: unavailable ? 'No se pudo abrir el documento, así que no se puede aceptar. Pulsa «${DocumentReaderPage.titleOf(document.type)}» para intentarlo de nuevo.' : null,
      noteIsError: true,
    );
  }

  /// Option A, said before anything is typed.
  Widget _studyIntro() => const KoraCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Kora es parte de un estudio', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          SizedBox(height: 6),
          Text('Kora se usa dentro de un estudio de tesis de 12 semanas y es exclusiva para las personas que aceptan participar. '
              'Antes de crear tu cuenta podrás leer los términos y condiciones, la política de privacidad y el consentimiento informado. '
              'Participar es voluntario: si no deseas hacerlo, no se crea ninguna cuenta.',
              style: TextStyle(color: Kora.muted, fontSize: 14, height: 1.45)),
        ]),
      );

  Widget _documentsBlock(PublishedDocuments documents, bool busy) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _acceptance(documents.terms!, busy, before: 'Acepto los '),
        _acceptance(documents.privacy!, busy, before: documents.privacyRecord == PrivacyRecord.acknowledgement ? 'He leído la ' : 'Acepto la '),
        _acceptance(documents.studyConsent!, busy, before: 'Acepto participar voluntariamente en el estudio según el ', study: true),
        if (_documentsError != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_documentsError!, style: TextStyle(color: Colors.red.shade800))),
        Align(alignment: Alignment.centerLeft, child: TextButton(
          key: const Key('decline-study'),
          onPressed: busy ? null : _decline,
          child: const Text('No deseo participar'),
        )),
      ]);

  /// Sign-up cannot go on: documents not available or not published yet.
  Widget _signUpUnavailable({required String title, required String text, VoidCallback? retry}) => KoraCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 15, height: 1.45)),
          if (retry != null) ...[
            const SizedBox(height: 12),
            KoraButton(label: 'Reintentar', onPressed: retry),
          ],
        ]),
      );

  static String _missingName(ConsentType type) => switch (type) {
        ConsentType.termsOfService => 'las condiciones de uso',
        ConsentType.privacyPolicy => 'la política de privacidad',
        ConsentType.studyParticipation => 'el consentimiento informado',
      };

  String get _contactLine => StudyConfig.contact.trim().isEmpty
      ? 'Si te invitaron al estudio, escribe al equipo que te invitó.'
      : 'Si te invitaron al estudio, escribe al equipo: ${StudyConfig.contact.trim()}.';

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authViewModelProvider).isLoading || _checking;
    final published = widget.register ? ref.watch(publishedDocumentsProvider) : null;
    final documents = published?.asData?.value;
    final open = !widget.register || (documents?.signUpOpen ?? false);
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
          if (widget.register) ...[
            _studyIntro(),
            const SizedBox(height: 16),
            if (published != null && published.hasError && !published.isLoading)
              _signUpUnavailable(
                title: 'No pudimos consultar los documentos',
                text: 'Para crear la cuenta necesitas leer los documentos vigentes del estudio. ${apiError(published.error!)}',
                retry: () => ref.invalidate(publishedDocumentsProvider),
              )
            else if (published == null || published.isLoading)
              const KoraCard(child: Row(children: [
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                SizedBox(width: 14),
                Expanded(child: Text('Consultando los documentos del estudio…', style: TextStyle(fontSize: 15))),
              ]))
            else if (!open)
              _signUpUnavailable(
                title: 'El registro todavía no está abierto',
                text: 'Para crear una cuenta tienen que estar publicados los tres documentos del estudio, y todavía falta${documents!.missing.length == 1 ? '' : 'n'}: '
                    '${[for (final t in documents.missing) _missingName(t)].join(', ')}. Hasta entonces no se pueden crear cuentas. $_contactLine',
                retry: () => ref.invalidate(publishedDocumentsProvider),
              ),
            const SizedBox(height: 16),
          ],
          if (open) AutofillGroup(
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
                    _documentsBlock(documents!, busy),
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
