import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/kora_ui.dart';
import '../widgets/reset_password_form.dart';

class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const KoraPage(child: ResetPasswordForm());
  }
}
