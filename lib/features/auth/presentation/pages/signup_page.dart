import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';

/// Tela de cadastro manual — Nome, Username, E-mail e Senha.
class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
      appBar: AppBar(
        title: Text(AppStrings.authSignupTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Nome
                AuthTextField(
                  hint: AppStrings.authName,
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? AppStrings.authErrorNameEmpty : null,
                ),
                const SizedBox(height: 12),

                // Username
                AuthTextField(
                  hint: AppStrings.authUsername,
                  controller: _usernameController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? AppStrings.authErrorUsernameEmpty : null,
                ),
                const SizedBox(height: 12),

                // E-mail
                AuthTextField(
                  hint: AppStrings.authEmail,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return AppStrings.authErrorEmailInvalid;
                    if (!v.contains('@')) return AppStrings.authErrorEmailInvalid;
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Senha
                AuthTextField(
                  hint: AppStrings.authPassword,
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      (v == null || v.length < 6) ? AppStrings.authErrorPasswordShort : null,
                ),

                const SizedBox(height: 28),

                // Botão Cadastrar
                PrimaryButton(
                  label: isLoading ? AppStrings.authLoading : AppStrings.authSignupButton,
                  onPressed: isLoading ? null : _submit,
                ),

                const SizedBox(height: 16),

                // Já tenho conta
                Center(
                  child: TextButton(
                    onPressed: isLoading ? null : () => context.pop(),
                    child: Text(
                      AppStrings.authAlreadyHaveAccount,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            decoration: TextDecoration.underline,
                            color: AppColors.onSurfaceMuted,
                          ),
                    ),
                  ),
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
    await ref.read(authControllerProvider.notifier).signUpWithEmail(
          name: _nameController.text.trim(),
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }
}
