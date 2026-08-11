import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

/// Cabeçalho da home: avatar à esquerda, título "Compy" no centro,
/// engrenagem à direita, e abaixo a saudação "Oi, {nome}".
///
/// Os dois toques saem daqui como callback em vez de navegar direto: quem
/// conhece as rotas é a página, como já acontece em `CategoryCircle` e
/// `ExploreMapCard`.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    required this.userName,
    required this.onAvatarTap,
    required this.onSettingsTap,
    super.key,
  });

  final String userName;

  /// Atalho para a aba Perfil.
  final VoidCallback onAvatarTap;

  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Semantics(
              button: true,
              label: AppStrings.navProfile,
              child: InkWell(
                onTap: onAvatarTap,
                customBorder: const CircleBorder(),
                // O avatar tem 36px, abaixo do alvo de toque de 48. O padding
                // cresce só para a direita e para cima/baixo, para a borda
                // esquerda continuar alinhada com a saudação logo abaixo.
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 12, 6),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.surfaceMuted,
                    backgroundImage: CachedNetworkImageProvider(
                      AppAssets.avatar(userName),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            const Text(
              AppStrings.appName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              color: AppColors.onSurface,
              tooltip: AppStrings.settingsTitle,
              onPressed: onSettingsTap,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${AppStrings.homeGreetingPrefix} $userName',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
