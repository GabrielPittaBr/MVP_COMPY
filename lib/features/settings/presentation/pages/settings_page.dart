import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_links.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/location_providers.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/external_links.dart';
import '../../../../shared/widgets/location_disclosure.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/delete_account_dialog.dart';
import '../providers/settings_providers.dart';

/// Configurações (chore/lgpd): o caminho fácil de achar que a Play pede para
/// a exclusão de conta e o lugar onde a pessoa exerce os direitos da LGPD —
/// ler a política, baixar os dados, desligar a localização, ver quem
/// bloqueou e falar com o encarregado.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AuthUser?> auth = ref.watch(authControllerProvider);
    final AuthUser? user = auth.valueOrNull ?? ref.watch(authStateProvider).valueOrNull;
    final bool exporting = ref.watch(dataExportControllerProvider).isLoading;
    final LocationAccess? location = ref.watch(locationAccessProvider).valueOrNull;

    // Senha errada na exclusão, rede fora etc.: o controller fecha em erro.
    ref.listen(authControllerProvider, (_, next) {
      next.whenOrNull(
        error: (Object error, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(firebaseAuthErrorMessage(error)),
            backgroundColor: AppColors.error,
          ),
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          const _SectionTitle(AppStrings.settingsPrivacySection),
          if (user != null && user.isMinorAt(DateTime.now()))
            const ListTile(
              leading: Icon(Icons.shield_outlined, color: AppColors.primary),
              title: Text(AppStrings.consentMinorNotice),
            ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text(AppStrings.settingsPrivacyPolicy),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openExternalLink(context, AppLinks.privacyPolicy),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text(AppStrings.settingsTerms),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openExternalLink(context, AppLinks.terms),
          ),
          ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: const Text(AppStrings.settingsSafety),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openExternalLink(context, AppLinks.safety),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text(AppStrings.settingsDownloadData),
            subtitle: Text(
              exporting ? AppStrings.settingsDownloadPreparing : AppStrings.settingsDownloadDataHint,
            ),
            trailing: exporting
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: exporting ? null : () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text(AppStrings.settingsLocation),
            subtitle: Text(
              location == LocationAccess.granted
                  ? AppStrings.settingsLocationOn
                  : AppStrings.settingsLocationOff,
            ),
            // Para desligar, só as configurações do Android; para ligar,
            // o aviso em destaque antes do pedido.
            onTap: () => location == LocationAccess.granted
                ? Geolocator.openAppSettings()
                : requestLocationWithDisclosure(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text(AppStrings.settingsBlocked),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.blockedUsers),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text(AppStrings.settingsContact),
            subtitle: const Text(AppLinks.privacyEmail),
            onTap: () => openPrivacyEmail(context, subject: AppStrings.settingsContactSubject),
          ),
          const Divider(height: 32),
          const _SectionTitle(AppStrings.settingsAccountSection),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text(AppStrings.settingsSignOut),
            onTap: auth.isLoading ? null : () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
            title: const Text(
              AppStrings.settingsDeleteAccount,
              style: TextStyle(color: AppColors.error),
            ),
            subtitle: const Text(AppStrings.profileDeleteAccountHint),
            onTap: auth.isLoading ? null : () => confirmAndDeleteAccount(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await ref.read(dataExportControllerProvider.notifier).run();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(AppStrings.settingsDownloadError),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurfaceMuted,
        ),
      ),
    );
  }
}
