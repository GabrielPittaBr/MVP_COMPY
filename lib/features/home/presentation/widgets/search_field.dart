import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

/// Campo de busca da home / mapa. Hoje é estático (placeholder) — quando o
/// matchmaking (RF03) for implementado, conectar a um filterProvider.
class SearchField extends StatelessWidget {
  const SearchField({this.hint = AppStrings.homeSearchHint, super.key});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceMuted),
      ),
    );
  }
}
