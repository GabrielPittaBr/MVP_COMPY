import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/username_rules.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/entities/auth_user.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';

/// Tela intermediária exibida após login com Google pela primeira vez.
///
/// Nome e e-mail chegam pré-preenchidos pelo provedor Google. O **nome é
/// editável** — quem configurou o Google como "joao123" precisa poder
/// corrigir antes de o valor virar `users/{uid}.name`. O **e-mail é
/// read-only**: é a chave da credencial Google, e mudá-lo aqui só criaria
/// divergência entre o que o Firebase Auth sabe e o que o Firestore guarda.
class UsernamePage extends ConsumerStatefulWidget {
  const UsernamePage({required this.user, super.key});

  /// Usuário autenticado recém-criado (sem username ainda).
  final AuthUser user;

  @override
  ConsumerState<UsernamePage> createState() => _UsernamePageState();
}

class _UsernamePageState extends ConsumerState<UsernamePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.user.displayName);

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      next.whenOrNull(
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(firebaseAuthErrorMessage(e)),
              backgroundColor: AppColors.error,
            ),
          );
        },
      );
    });

    final bool isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(AppStrings.authChooseUsername)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  AppStrings.authChooseUsernameHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                ),
                const SizedBox(height: 24),

                // Nome (editável, pré-preenchido pelo Google)
                AuthTextField(
                  hint: AppStrings.authName,
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  maxLength: kMaxDisplayNameLength,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? AppStrings.authErrorNameEmpty
                      : null,
                ),
                const SizedBox(height: 12),

                // E-mail (read-only, vindo do Google)
                AuthTextField(
                  hint: AppStrings.authEmail,
                  initialValue: widget.user.email,
                  readOnly: true,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),

                // Username (editável)
                AuthTextField(
                  hint: AppStrings.authUsernameField,
                  controller: _usernameController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  maxLength: UsernameRules.maxLength,
                  inputFormatters: UsernameRules.inputFormatters,
                  validator: UsernameRules.validate,
                ),

                const SizedBox(height: 28),

                PrimaryButton(
                  label: isLoading ? AppStrings.authLoading : AppStrings.authConfirmUsername,
                  onPressed: isLoading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authControllerProvider.notifier).setUsername(
          uid: widget.user.uid,
          username: _usernameController.text.trim(),
          name: _nameController.text.trim(),
          email: widget.user.email,
        );
  }
}
