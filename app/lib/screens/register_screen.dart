import 'package:flutter/material.dart';

import '../widgets/auth_scaffold.dart';
import '../widgets/branding.dart';
import '../widgets/inputs.dart';

/// Pantalla de registro.
///
/// Implementa el diseño de Figma ("HACKA", nodo 47:1030). El lienzo original mide 402x1000 con
/// todo en coordenadas absolutas; aquí el formulario es una columna desplazable, que es lo que
/// necesita de verdad: con el teclado abierto, en un teléfono chico, cinco campos no caben en
/// pantalla por más que el diseño los muestre completos.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.onBack,
    this.onSubmit,
    this.onSignIn,
    this.onGoogle,
    this.onApple,
  });

  final VoidCallback? onBack;

  /// Recibe los datos capturados. La creación real de la cuenta no vive aquí.
  final void Function(RegistrationDraft draft)? onSubmit;

  final VoidCallback? onSignIn;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// Lo que el formulario entrega cuando pasa validación.
class RegistrationDraft {
  const RegistrationDraft({
    required this.fullName,
    required this.email,
    required this.birthDate,
    required this.password,
  });

  final String fullName;
  final String email;
  final DateTime? birthDate;
  final String password;
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  DateTime? _birthDate;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    widget.onSubmit?.call(
      RegistrationDraft(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        birthDate: _birthDate,
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      formKey: _formKey,
      title: 'Registrarse',
      promptBuilder:
          (width) => AuthPrompt.signIn(
            width: width,
            designSize: 12,
            onTap: widget.onSignIn,
          ),
      // El diseño dice "Entrar" en este botón, heredado de la pantalla inicial; en un
      // formulario de alta eso confunde.
      ctaLabel: 'Registrarse',
      onSubmit: _submit,
      onBack: widget.onBack,
      onGoogle: widget.onGoogle,
      onApple: widget.onApple,
      fieldsBuilder: _fields,
    );
  }

  List<Widget> _fields(double width, double s) {
    final gap = SizedBox(height: 20 * s);

    return [
      FieldLabel(text: 'Nombre completo', width: width),
      PillTextField(
        width: width,
        hint: 'Escribe tu nombre...',
        controller: _name,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.name,
        autofillHints: const [AutofillHints.name],
        validator:
            (value) =>
                (value == null || value.trim().length < 3)
                    ? 'Escribe tu nombre completo'
                    : null,
      ),
      gap,

      FieldLabel(text: 'Correo', width: width),
      PillTextField(
        width: width,
        hint: 'Escribe tu correo...',
        controller: _email,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        validator: (value) {
          final text = value?.trim() ?? '';
          // Validación deliberadamente laxa: rechazar correos raros pero válidos molesta
          // más de lo que ayuda. El servidor es quien confirma que exista.
          return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
              ? null
              : 'Escribe un correo válido';
        },
      ),
      gap,

      FieldLabel(text: 'Fecha de nacimiento', width: width),
      PillDateField(
        width: width,
        value: _birthDate,
        onChanged: (date) => setState(() => _birthDate = date),
      ),
      gap,

      FieldLabel(text: 'Contraseña', width: width),
      PillPasswordField(
        width: width,
        hint: '•••••••••••',
        controller: _password,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.newPassword],
        validator:
            (value) =>
                (value == null || value.length < 8)
                    ? 'Mínimo 8 caracteres'
                    : null,
      ),
      gap,

      FieldLabel(text: 'Confirmar contraseña', width: width),
      PillPasswordField(
        width: width,
        hint: '•••••••••••',
        controller: _confirm,
        textInputAction: TextInputAction.done,
        validator:
            (value) =>
                value != _password.text ? 'Las contraseñas no coinciden' : null,
      ),
    ];
  }
}
