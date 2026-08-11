import 'package:flutter/material.dart';

import '../../../../shared/widgets/rounded_text_field.dart';

/// Campo simples de formulário (label + RoundedTextField).
class EventFormField extends StatelessWidget {
  const EventFormField({
    required this.hint,
    required this.controller,
    this.readOnly = false,
    this.onTap,
    this.suffix,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    super.key,
  });

  final String hint;
  final TextEditingController controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RoundedTextField(
        hint: hint,
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        suffix: suffix,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        textCapitalization: textCapitalization,
      ),
    );
  }
}
