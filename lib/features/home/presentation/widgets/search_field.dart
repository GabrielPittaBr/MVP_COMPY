import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';

/// Campo de busca da home / mapa. Abre a tela de busca de eventos
/// (por nome ou modalidade) ao ser tocado.
class SearchField extends StatelessWidget {
  const SearchField({this.hint = AppStrings.homeSearchHint, super.key});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: true,
      onTap: () => context.go(AppRoutes.search),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceMuted),
      ),
    );
  }
}
