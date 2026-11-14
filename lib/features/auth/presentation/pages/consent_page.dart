import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/age_rules.dart';
import '../../../../core/utils/external_links.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/legal_consent.dart';
import '../providers/auth_providers.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/legal_consent_fields.dart';

/// Aceite dos Termos de Uso e da Política de Privacidade para quem já tem
/// conta (chore/lgpd): contas anteriores à LGPD, que ainda não informaram a
/// data de nascimento, e todo mundo quando a versão dos Termos muda.
///
/// Quem informa que tem menos de 16 anos não entra: a tela explica e oferece
/// a exclusão da conta.
class ConsentPage extends ConsumerStatefulWidget {
  const ConsentPage({super.key});

  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> {
  final _formKey = GlobalKey<FormState>();
  final _birthDateController = TextEditingController();
  bool _underage = false;

  @override
  void dispose() {
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthUser?> authState = ref.watch(authControllerProvider);
    final AuthUser? user =
        authState.valueOrNull ?? ref.watch(authStateProvider).valueOrNull;
    final bool needsBirthDate = user?.birthDate == null;
    final bool isLoading = authState.isLoading;

    ref.listen(authControllerProvider, (_, next) {
      next.whenOrNull(
        error: (Object error, _) {
          if (error is UnderageException) {
            setState(() => _underage = true);
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(firebaseAuthErrorMessage(error)),
              backgroundColor: AppColors.error,
            ),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.consentTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: _underage
              ? _UnderagePanel(busy: isLoading)
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        AppStrings.consentHeadline,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        needsBirthDate
                            ? AppStrings.consentBodyFirst
                            : AppStrings.consentBodyRenew,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceMuted,
                            ),
                      ),
                      const SizedBox(height: 24),
                      if (needsBirthDate) ...<Widget>[
                        BirthDateField(
                          controller: _birthDateController,
                          textInputAction: TextInputAction.done,
                          enforceMinimumAge: false,
                        ),
                        const SizedBox(height: 8),
                      ],
                      LegalAcceptanceField(),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: isLoading
                            ? AppStrings.authLoading
                            : AppStrings.consentContinue,
                        onPressed: isLoading ? null : () => _submit(needsBirthDate),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => ref.read(authControllerProvider.notifier).signOut(),
                        child: const Text(AppStrings.consentSignOut),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _submit(bool needsBirthDate) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authControllerProvider.notifier).acceptLegalTerms(
          birthDate: needsBirthDate
              ? AgeRules.parseBirthDate(_birthDateController.text)
              : null,
        );
  }
}

class _UnderagePanel extends ConsumerWidget {
  const _UnderagePanel({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Icon(Icons.shield_outlined, size: 48, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          AppStrings.consentUnderageTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.consentUnderageBody,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : () => confirmAndDeleteAccount(context, ref),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: Text(
            busy ? AppStrings.authLoading : AppStrings.consentUnderageDelete,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => openPrivacyEmail(context, subject: AppStrings.settingsContactSubject),
          child: const Text(AppStrings.settingsContact),
        ),
        TextButton(
          onPressed: busy ? null : () => ref.read(authControllerProvider.notifier).signOut(),
          child: const Text(AppStrings.consentSignOut),
        ),
      ],
    );
  }
}
