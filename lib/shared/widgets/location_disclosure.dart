import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_strings.dart';
import '../../core/providers/location_providers.dart';
import '../../core/theme/app_colors.dart';

/// Aviso em destaque antes do pedido de localização (Play, política de Dados
/// do Usuário; LGPD art. 9º). O diálogo do Android só abre depois de um "Ativar
/// localização" explícito; "Agora não" não pede nada.
Future<void> requestLocationWithDisclosure(BuildContext context, WidgetRef ref) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final LocationAccess current = await ref.read(locationAccessProvider.future);

  if (current == LocationAccess.deniedForever || current == LocationAccess.serviceOff) {
    // O Android não mostra mais o diálogo: só as configurações resolvem.
    messenger.showSnackBar(
      SnackBar(
        content: const Text(AppStrings.locationDeniedForever),
        action: SnackBarAction(
          label: AppStrings.locationOpenSettings,
          onPressed: () => current == LocationAccess.serviceOff
              ? Geolocator.openLocationSettings()
              : Geolocator.openAppSettings(),
        ),
      ),
    );
    return;
  }
  if (current == LocationAccess.granted || !context.mounted) return;

  final bool? allow = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
      title: const Text(AppStrings.locationDisclosureTitle),
      content: const Text(AppStrings.locationDisclosureBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(AppStrings.locationDisclosureNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(AppStrings.locationDisclosureAllow),
        ),
      ],
    ),
  );
  if (allow != true) return;

  try {
    await Geolocator.requestPermission();
  } catch (_) {
    // Plugin indisponível: fica como estava.
  }
  ref.invalidate(locationAccessProvider);
  ref.invalidate(userPositionProvider);
}

/// Cartão da Home enquanto a localização está desligada: explica e oferece
/// ligar. Some sozinho quando a permissão chega.
class LocationPromptCard extends ConsumerWidget {
  const LocationPromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LocationAccess? access = ref.watch(locationAccessProvider).valueOrNull;
    if (access == null || access == LocationAccess.granted) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.near_me_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.locationCardTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              AppStrings.locationCardBody,
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => requestLocationWithDisclosure(context, ref),
                child: const Text(AppStrings.locationDisclosureAllow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
