import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Destino honesto para funcionalidade que ainda não existe.
///
/// Um botão que não faz nada é pior que um botão ausente: o usuário toca,
/// nada acontece, e passa a desconfiar do resto da tela. Enquanto
/// Configurações e Insígnias não saem do papel, é melhor dizer isso na cara.
///
/// Recebe o [title] em vez de fixar um: a tela é a mesma, mas o cabeçalho
/// precisa confirmar de onde o usuário veio.
class UnderConstructionPage extends StatelessWidget {
  const UnderConstructionPage({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.construction_outlined,
                  size: 64,
                  color: AppColors.onSurfaceMuted,
                ),
                SizedBox(height: 20),
                Text(
                  AppStrings.underConstructionTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  AppStrings.underConstructionBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
