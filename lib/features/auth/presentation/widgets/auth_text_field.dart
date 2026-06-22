import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Campo de texto para os formulários de autenticação.
///
/// Estende o padrão do [RoundedTextField] adicionando:
/// - suporte a `obscureText` (campo de senha com toggle de visibilidade);
/// - `validator` para uso dentro de um [Form] + [TextFormField];
/// - label opcional exibida acima do campo.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    required this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.readOnly = false,
    this.initialValue,
    super.key,
  });

  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool readOnly;
  final String? initialValue;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      keyboardType: widget.keyboardType,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      readOnly: widget.readOnly,
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: widget.hint,
        suffixIcon: widget.obscureText
            ? IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.onSurfaceMuted,
                  size: 20,
                ),
              )
            : null,
      ),
    );
  }
}
