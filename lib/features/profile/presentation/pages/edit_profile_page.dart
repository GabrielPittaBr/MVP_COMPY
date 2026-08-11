import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/rounded_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/profile_providers.dart';

/// Edição do perfil — hoje, o username em modo somente-leitura e a exclusão
/// de conta.
///
/// O campo de username aparece apagado em vez de ausente de propósito: quem
/// abre "Editar perfil" vem procurar exatamente por ele, e uma tela sem o
/// campo parece quebrada. Apagado, com o aviso embaixo, responde a pergunta.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final TextEditingController _usernameCtrl = TextEditingController();

  /// Vive na página, e não dentro do diálogo, pelo mesmo motivo do
  /// `_customDurationCtrl` da criação de evento: descartá-lo assim que o
  /// `showDialog` retorna estoura enquanto a rota ainda anima a saída.
  final TextEditingController _passwordCtrl = TextEditingController();

  /// Sem isto, uma reemissão do perfil sobrescreveria o campo já preenchido.
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();

    // Chegando pela aba Perfil o documento já está em cache — é o caso normal.
    final UserProfile? cached = ref.read(currentProfileProvider).valueOrNull;
    if (cached != null) {
      _usernameCtrl.text = cached.summary.handle;
      _prefilled = true;
      return;
    }

    ref.listenManual<AsyncValue<UserProfile>>(currentProfileProvider,
        (_, AsyncValue<UserProfile> next) {
      final UserProfile? profile = next.valueOrNull;
      if (_prefilled || profile == null || !mounted) return;
      setState(() {
        _usernameCtrl.text = profile.summary.handle;
        _prefilled = true;
      });
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sucesso não precisa de tratamento: o controller fecha com `null`, o
    // guard do router vê que não há mais usuário e leva para /login sozinho.
    ref.listen<AsyncValue<Object?>>(authControllerProvider,
        (_, AsyncValue<Object?> next) {
      next.whenOrNull(
        error: (Object error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(firebaseAuthErrorMessage(error)),
              backgroundColor: AppColors.error,
            ),
          );
        },
      );
    });

    final bool isDeleting = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profileEdit)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: <Widget>[
            const _Label(AppStrings.authUsernameField),
            const SizedBox(height: 8),
            IgnorePointer(
              child: Opacity(
                opacity: 0.5,
                child: RoundedTextField(
                  hint: AppStrings.authUsernameField,
                  controller: _usernameCtrl,
                  readOnly: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _Hint(AppStrings.profileUsernameLocked),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            const _Label(AppStrings.profileAccountSection),
            const SizedBox(height: 8),
            const _Hint(AppStrings.profileDeleteAccountHint),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isDeleting ? null : _deleteAccount,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  isDeleting
                      ? AppStrings.authLoading
                      : AppStrings.profileDeleteAccount,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final bool needsPassword =
        ref.read(authRepositoryProvider).signedInWithPassword();
    _passwordCtrl.clear();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text(AppStrings.profileDeleteAccountTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(AppStrings.profileDeleteAccountBody),
            const SizedBox(height: 16),
            if (needsPassword)
              TextField(
                controller: _passwordCtrl,
                autofocus: true,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: AppStrings.profileDeleteAccountPasswordHint,
                ),
              )
            else
              const _Hint(AppStrings.profileDeleteAccountGoogleHint),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              AppStrings.profileDeleteAccountConfirm,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    final String password = _passwordCtrl.text;
    if (needsPassword && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.profileDeleteAccountPasswordEmpty),
        ),
      );
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .deleteAccount(password: needsPassword ? password : null);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        height: 1.4,
        color: AppColors.onSurfaceMuted,
      ),
    );
  }
}
