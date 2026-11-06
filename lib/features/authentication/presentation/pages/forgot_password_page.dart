import 'package:flutter/material.dart';

import '../../../../shared/widgets/kora_ui.dart';
import '../widgets/forgot_password_form.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const KoraPage(child: ForgotPasswordForm());
  }
}
