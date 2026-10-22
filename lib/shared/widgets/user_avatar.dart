import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/user_summary.dart';

/// Avatar de um Usuário, tolerante a usuário ausente ou sem foto.
///
/// O chat pode estar carregando a conversa, ou a conversa pode ter chegado
/// sem `memberSummaries`; um participante de evento pode não ter foto. Em
/// todos esses casos há um avatar para desenhar e nenhuma URL válida.
/// `CachedNetworkImageProvider('')` falha em runtime, então o vazio precisa
/// virar o ícone genérico antes de chegar lá.
class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.user, this.radius = 16, super.key});

  final UserSummary? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = user?.avatarUrl ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceMuted,
      backgroundImage: url.isEmpty ? null : CachedNetworkImageProvider(url),
      child: url.isEmpty
          ? Icon(
              Icons.person,
              size: radius,
              color: AppColors.onSurfaceMuted,
            )
          : null,
    );
  }
}
