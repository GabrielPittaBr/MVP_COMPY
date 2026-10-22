import 'package:flutter/material.dart';

import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/user_avatar.dart';

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
    return UserAvatar(user: peer, radius: radius);
  }
}
