import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

/// Cabeçalho da home: avatar à esquerda, título "Compy" no centro, sino e
/// engrenagem à direita, e abaixo a saudação "Oi, {nome}".
///
/// O sino (tarefa 14) tem o badge das notificações não lidas. Com dois
/// ícones à direita e um à esquerda, um `Row` com `Spacer` tiraria o título
/// do centro; por isso ele fica num `Stack`, centralizado na largura toda.
///
/// Os dois toques saem daqui como callback em vez de navegar direto: quem
/// conhece as rotas é a página, como já acontece em `CategoryCircle` e
/// `ExploreMapCard`.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    required this.userName,
    required this.onAvatarTap,
    required this.onSettingsTap,
    required this.onNotificationsTap,
    this.unreadNotifications = 0,
    this.avatarUrl,
    super.key,
  });

  final String userName;

  /// Foto do perfil (`users/{uid}.avatarUrl`). Enquanto o perfil carrega,
  /// fica a inicial de [userName].
  final String? avatarUrl;

  /// Atalho para a aba Perfil.
  final VoidCallback onAvatarTap;

  final VoidCallback onSettingsTap;

  /// Abre a central de notificações.
  final VoidCallback onNotificationsTap;

  /// Número do badge; zero esconde o badge.
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Stack(
          alignment: Alignment.center,
          children: <Widget>[
            const Text(
              AppStrings.appName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
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
                      // Vazio também cai na inicial: `CachedNetworkImageProvider('')`
                      // estoura, e perfis antigos podem não ter o campo.
                      avatarUrl == null || avatarUrl!.isEmpty
                          ? AppAssets.avatar(userName)
                          : avatarUrl!,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: AppStrings.notificationsBellSemantics(unreadNotifications),
              color: AppColors.onSurface,
              onPressed: onNotificationsTap,
              icon: ExcludeSemantics(
                child: Badge(
                  isLabelVisible: unreadNotifications > 0,
                  backgroundColor: AppColors.error,
                  textColor: Colors.white,
                  label: Text(
                    unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                  ),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              color: AppColors.onSurface,
              tooltip: AppStrings.settingsTitle,
              onPressed: onSettingsTap,
            ),
          ],
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
