import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../providers/auth_providers.dart';

/// Tela de carregamento inicial — e único lugar onde a falha de leitura do
/// perfil aparece para o usuário.
///
/// O guard do router manda para cá quando o estado de autenticação está em
/// erro: há alguém logado, mas não deu para saber se ele já tem perfil.
/// Mandar para `/login` deslogaria quem está autenticado, e mandar para
/// `/username` faria recadastrar quem já tem conta — por isso a saída é uma
/// nova tentativa, não um redirecionamento.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool failed = ref.watch(authStateProvider).hasError;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: failed
            ? _ProfileLookupFailed(
                onRetry: () => ref.invalidate(authStateProvider),
              )
            : const CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _ProfileLookupFailed extends StatelessWidget {
  const _ProfileLookupFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off, size: 48, color: AppColors.onSurfaceMuted),
          const SizedBox(height: 16),
          Text(
            AppStrings.authErrorProfileLookup,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: AppStrings.authRetry, onPressed: onRetry),
        ],
      ),
    );
  }
}
