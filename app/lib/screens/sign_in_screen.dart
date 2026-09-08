import 'package:flutter/material.dart';

import '../widgets/auth_scaffold.dart';
import '../widgets/branding.dart';
import '../widgets/inputs.dart';

/// Pantalla de inicio de sesión.
///
/// Implementa el diseño de Figma ("HACKA", nodo 47:1064). Comparte todo el andamiaje con la de
/// registro — es el mismo diseño con dos campos en vez de cinco — así que aquí solo viven los
/// campos, la validación y el título.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    this.onBack,
    this.onSubmit,
    this.onRegister,
    this.onGoogle,
    this.onApple,
  });

  final VoidCallback? onBack;

  /// Recibe las credenciales capturadas. La autenticación real no vive aquí.
  final void Function(SignInCredentials credentials)? onSubmit;

  final VoidCallback? onRegister;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class SignInCredentials {
  const SignInCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    widget.onSubmit?.call(
      SignInCredentials(
        email: _email.text.trim(),
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      formKey: _formKey,
      title: 'Iniciar sesión',
      titleDesignSize: 32,
      promptBuilder:
          (width) => AuthPrompt.register(
            width: width,
            designSize: 12,
            onTap: widget.onRegister,
          ),
      ctaLabel: 'Entrar',
      onSubmit: _submit,
      onBack: widget.onBack,
      onGoogle: widget.onGoogle,
      onApple: widget.onApple,
      fieldsBuilder:
          (width, s) => [
            FieldLabel(text: 'Correo', width: width),
            PillTextField(
              width: width,
              // El diseño dice "Escribe tu nombre..." en este campo, heredado de la pantalla
              // de registro. Aquí el campo es el correo.
              hint: 'Escribe tu correo...',
              controller: _email,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              validator: (value) {
                final text = value?.trim() ?? '';
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
                    ? null
                    : 'Escribe un correo válido';
              },
            ),
            SizedBox(height: 20 * s),

            FieldLabel(text: 'Contraseña', width: width),
            PillPasswordField(
              width: width,
              hint: '•••••••••••',
              controller: _password,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              // Al entrar no se valida la fortaleza — eso es cosa del registro. Aquí solo
              // importa que el campo no vaya vacío; si la contraseña es incorrecta lo dice
              // el servidor.
              validator:
                  (value) =>
                      (value == null || value.isEmpty)
                          ? 'Escribe tu contraseña'
                          : null,
            ),
          ],
    );
  }
}
