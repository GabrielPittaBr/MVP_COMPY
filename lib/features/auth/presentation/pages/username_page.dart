import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/entities/auth_user.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';

/// Tela intermediária exibida após login com Google pela primeira vez.
///
/// Mostra Nome e E-mail pré-preenchidos (read-only, vindos do provedor Google)
/// e pede que o usuário escolha um username exclusivo.
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

  @override
  void dispose() {
    _usernameController.dispose();
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

                // Nome (read-only, vindo do Google)
                AuthTextField(
                  hint: AppStrings.authName,
                  initialValue: widget.user.displayName,
                  readOnly: true,
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
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? AppStrings.authErrorUsernameEmpty : null,
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
          name: widget.user.displayName,
          email: widget.user.email,
        );
  }
}
