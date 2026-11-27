import 'package:material_ui/material_ui.dart';
import '../widgets/kora_auth_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.initialEmail});

  /// Prefilled after changing the password (`/login?correo=`).
  final String? initialEmail;
  @override
  Widget build(BuildContext context) => KoraAuthForm(initialEmail: initialEmail);
}
