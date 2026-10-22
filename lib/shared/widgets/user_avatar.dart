import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/user_summary.dart';

/// Avatar de um Usuário, tolerante a usuário ausente, sem foto ou com foto
/// que não carrega.
///
/// O chat pode estar carregando a conversa, ou a conversa pode ter chegado
/// sem `memberSummaries`; um participante de evento pode não ter foto. Em
/// todos esses casos há um avatar para desenhar e nenhuma URL válida, então
/// o ícone genérico aparece no lugar da imagem de rede. Ele também cobre a
/// espera e a falha do download.
class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.user, this.radius = 16, super.key});

  final UserSummary? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = user?.avatarUrl ?? '';
    final uri = Uri.tryParse(url);
    final valid = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    final fallback = Container(
      width: radius * 2,
      height: radius * 2,
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: radius, color: AppColors.onSurfaceMuted),
    );
    return ClipOval(
      child: valid
          ? CachedNetworkImage(
              imageUrl: url,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            )
          : fallback,
    );
  }
}
