import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_summary.dart';

/// Avatar do interlocutor, tolerante a peer ausente.
///
/// A sala pode estar carregando a conversa, ou a conversa pode ter chegado
/// sem `memberSummaries` — nos dois casos há um avatar para desenhar e
/// nenhuma URL válida. `CachedNetworkImageProvider('')` falha em runtime,
/// então o vazio precisa virar o ícone genérico antes de chegar lá.
class PeerAvatar extends StatelessWidget {
  const PeerAvatar({required this.peer, this.radius = 16, super.key});

  final UserSummary? peer;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = peer?.avatarUrl ?? '';
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
