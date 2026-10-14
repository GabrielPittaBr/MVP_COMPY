import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';
import '../../../maps/presentation/providers/maps_providers.dart';
import '../../domain/entities/message.dart';

/// Local encaminhado: prefere o documento atual e preserva mensagens novas
/// pelo snapshot caso a leitura falhe. Mensagens legadas sem snapshot mantêm
/// um fallback genérico quando o documento não existe mais.
class PlaceMessageCard extends ConsumerWidget {
  const PlaceMessageCard({
    required this.placeId,
    required this.isMine,
    this.snapshot,
    super.key,
  });

  final String placeId;
  final bool isMine;
  final PlaceMessageSnapshot? snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookup = ref.watch(placeByIdProvider(placeId));
    return lookup.when(
      data: (result) {
        final place = result.place;
        if (place != null) {
          return _PlaceMessageCardContent(
            placeId: placeId,
            isMine: isMine,
            name: place.name,
            imageUrl: place.imageUrl,
            sport: place.primarySport,
            address: place.formattedAddress,
            inactive: place.status == PlaceStatus.inactive,
          );
        }
        return _snapshotOrGeneric();
      },
      // Exibe o snapshot imediatamente e troca pelos dados atuais quando a
      // resolução termina, evitando um card vazio durante o carregamento.
      loading: _snapshotOrGeneric,
      error: (_, __) => _snapshotOrGeneric(),
    );
  }

  Widget _snapshotOrGeneric() {
    final placeSnapshot = snapshot;
    if (placeSnapshot == null) {
      return Text(
        AppStrings.chatForwardedPlace,
        style: TextStyle(
          color: isMine ? Colors.white : AppColors.onSurface,
          fontSize: 14,
        ),
      );
    }
    return _PlaceMessageCardContent(
      placeId: placeId,
      isMine: isMine,
      name: placeSnapshot.name,
      imageUrl: placeSnapshot.imageUrl,
      sport: placeSnapshot.primarySport,
    );
  }
}

class _PlaceMessageCardContent extends StatelessWidget {
  const _PlaceMessageCardContent({
    required this.placeId,
    required this.isMine,
    required this.name,
    required this.imageUrl,
    required this.sport,
    this.address,
    this.inactive = false,
  });

  final String placeId;
  final bool isMine;
  final String name;
  final String imageUrl;
  final Sport sport;
  final String? address;
  final bool inactive;

  @override
  Widget build(BuildContext context) {
    final onColor = isMine ? Colors.white : AppColors.onSurface;
    return InkWell(
      onTap: () => context.go(AppRoutes.maps, extra: placeId),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                height: 110,
                width: 220,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  height: 110,
                  color: AppColors.surfaceMuted,
                  child: Icon(sport.icon, size: 40, color: sport.color),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: <Widget>[
                Icon(sport.icon, size: 13, color: sport.color),
                const SizedBox(width: 4),
                Text(
                  sport.label,
                  style: TextStyle(color: onColor, fontSize: 12),
                ),
              ],
            ),
            if (address != null && address!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  Icon(Icons.place_outlined, size: 13, color: onColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: onColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (inactive) ...<Widget>[
              const SizedBox(height: 6),
              const Text(
                'Local inativo',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
