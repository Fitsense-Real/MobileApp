import 'package:material_ui/material_ui.dart';
import '../widgets/kora_auth_form.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});
  @override
  Widget build(BuildContext context) => const KoraAuthForm(register: true);
}
