import 'package:flutter/material.dart';

/// Campo de texto arredondado padrão dos formulários (ex.: tela "Criar evento").
///
/// Encapsula o estilo definido no [InputDecorationTheme] mas adiciona
/// suporte a leitura sem foco (campos só de "exibição" como "Selecionar
/// esporte" / "Data" / "Horário" no mockup).
class RoundedTextField extends StatelessWidget {
  const RoundedTextField({
    required this.hint,
    this.controller,
    this.readOnly = false,
    this.onTap,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.suffix,
    super.key,
  });

  final String hint;
  final TextEditingController? controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: suffix,
      ),
    );
  }
}
