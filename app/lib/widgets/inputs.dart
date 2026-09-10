/// Controles de formulario del diseño MTAPP.
///
/// Todos los campos son píldoras grises sobre fondo blanco, con la etiqueta encima en gris. Se
/// definen una vez aquí para que un ajuste de altura o de radio no haya que repetirlo en cada
/// pantalla.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// CTA principal: píldora magenta a todo lo ancho.
class PrimaryPillButton extends StatelessWidget {
  const PrimaryPillButton({
    super.key,
    required this.label,
    required this.width,
    this.onPressed,
    this.designHeight = 68,
  });

  final String label;
  final double width;
  final VoidCallback? onPressed;

  /// El diseño usa 68-73 px en los formularios de acceso y 44 px en las hojas sobre el mapa,
  /// donde el espacio vertical es escaso.
  final double designHeight;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);

    return SizedBox(
      width: double.infinity,
      // Nunca por debajo del objetivo táctil mínimo recomendado, aunque el diseño encoja.
      height: math.max(designHeight * s, 48),
      child: FilledButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.button,
            fontFamilyFallback: AppFonts.buttonFallback,
            fontSize: fluid(width, designSize: 24, min: 18, max: 26),
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Etiqueta gris que va encima de cada campo.
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.text, required this.width});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // El diseño la separa 8 px del borde izquierdo del campo.
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.bodyFallback,
          fontSize: fluid(width, designSize: 15, min: 13, max: 17),
          color: AppColors.muted,
        ),
      ),
    );
  }
}

/// Campo de texto en forma de píldora.
class PillTextField extends StatelessWidget {
  const PillTextField({
    super.key,
    required this.width,
    required this.hint,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofillHints,
    this.validator,
    this.suffix,
  });

  final double width;
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final fontSize = fluid(width, designSize: 15, min: 13, max: 17);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autofillHints: autofillHints,
      validator: validator,
      style: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.bodyFallback,
        fontSize: fontSize,
        color: Colors.black,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.bodyFallback,
          fontSize: fontSize,
          color: AppColors.placeholder,
        ),
        filled: true,
        fillColor: AppColors.field,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 21 * s,
          vertical: 16 * s,
        ),
        suffixIcon: suffix,
        suffixIconConstraints: BoxConstraints(
          minWidth: 46 * s,
          minHeight: 46 * s,
        ),
        border: _border,
        enabledBorder: _border,
        focusedBorder: _border.copyWith(
          borderSide: const BorderSide(color: AppColors.magenta, width: 1.6),
        ),
        errorBorder: _border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.4),
        ),
        focusedErrorBorder: _border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.6),
        ),
        errorStyle: TextStyle(fontSize: fontSize - 2),
      ),
    );
  }

  static final OutlineInputBorder _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(40),
    borderSide: BorderSide.none,
  );
}

/// Campo de contraseña con el ojo para revelarla.
class PillPasswordField extends StatefulWidget {
  const PillPasswordField({
    super.key,
    required this.width,
    required this.hint,
    this.controller,
    this.textInputAction,
    this.autofillHints,
    this.validator,
  });

  final double width;
  final String hint;
  final TextEditingController? controller;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;

  @override
  State<PillPasswordField> createState() => _PillPasswordFieldState();
}

class _PillPasswordFieldState extends State<PillPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(widget.width);

    return PillTextField(
      width: widget.width,
      hint: widget.hint,
      controller: widget.controller,
      obscureText: _obscured,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      suffix: Semantics(
        button: true,
        label: _obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
        child: IconButton(
          onPressed: () => setState(() => _obscured = !_obscured),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 46 * s, minHeight: 46 * s),
          icon: Opacity(
            // Atenuado cuando la contraseña está oculta, sólido cuando se está mostrando:
            // el icono comunica el estado, no solo la acción.
            opacity: _obscured ? 0.55 : 1,
            child: SvgPicture.asset(
              'assets/icons/eye.svg',
              width: 26 * s,
              height: 26 * s,
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de fecha: píldora angosta con el icono de calendario.
///
/// En el diseño es notoriamente más corto que los demás campos (137 de 326), porque una fecha
/// no necesita el ancho completo. Al tocarlo abre el selector nativo.
class PillDateField extends StatelessWidget {
  const PillDateField({
    super.key,
    required this.width,
    required this.value,
    required this.onChanged,
    this.placeholder = 'dd/mm/aa',
  });

  final double width;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String placeholder;

  String _format(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = (date.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
      locale: const Locale('es', 'MX'),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = scaleFor(width);
    final fontSize = fluid(width, designSize: 15, min: 13, max: 17);
    final hasValue = value != null;

    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'Fecha de nacimiento',
        value: hasValue ? _format(value!) : 'sin definir',
        child: Material(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(40),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _pick(context),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 18 * s,
                vertical: 16 * s,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/calendar.svg',
                    width: 22 * s,
                    height: 22 * s,
                  ),
                  SizedBox(width: 12 * s),
                  Text(
                    hasValue ? _format(value!) : placeholder,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontFamilyFallback: AppFonts.bodyFallback,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      color: hasValue ? AppColors.muted : AppColors.placeholder,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
