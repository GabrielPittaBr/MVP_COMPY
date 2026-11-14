import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_providers.dart';

/// Confirma e exclui a conta do usuário logado.
///
/// Mora aqui porque três telas oferecem a exclusão: Editar perfil,
/// Configurações (que a Play pede como caminho fácil de achar) e o aceite de
/// quem tem menos de 16 anos. Quem entrou com senha a digita no diálogo;
/// quem entrou com Google confirma pelo seletor do Google. O fim é o mesmo do
/// logout: o controller fecha com `null` e o guard leva para `/login`.
Future<void> confirmAndDeleteAccount(BuildContext context, WidgetRef ref) async {
  final bool needsPassword = ref.read(authRepositoryProvider).signedInWithPassword();
  final String? password = await showDialog<String>(
    context: context,
    builder: (_) => _DeleteAccountDialog(needsPassword: needsPassword),
  );
  if (password == null || !context.mounted) return;

  if (needsPassword && password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.profileDeleteAccountPasswordEmpty)),
    );
    return;
  }

  await ref
      .read(authControllerProvider.notifier)
      .deleteAccount(password: needsPassword ? password : null);
}

/// Devolve a senha digitada (vazia para quem entrou com Google) ou `null`
/// quando a pessoa cancela.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.needsPassword});

  final bool needsPassword;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.profileDeleteAccountTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(AppStrings.profileDeleteAccountBody),
          const SizedBox(height: 16),
          if (widget.needsPassword)
            TextField(
              controller: _password,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: AppStrings.profileDeleteAccountPasswordHint,
              ),
            )
          else
            const Text(
              AppStrings.profileDeleteAccountGoogleHint,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.onSurfaceMuted,
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_password.text),
          child: const Text(
            AppStrings.profileDeleteAccountConfirm,
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}
