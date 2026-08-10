import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/sport_place.dart';

/// Local encaminhado dentro do balão de mensagem.
///
/// A mensagem guarda só o id; o catálogo de locais vive em código
/// (`SportPlace.all`), então nome, foto e esporte saem daqui sem nenhuma
/// leitura extra. Local que sumir do catálogo vira texto simples em vez de
/// derrubar a conversa.
class PlaceMessageCard extends StatelessWidget {
  const PlaceMessageCard({
    required this.placeId,
    required this.isMine,
    super.key,
  });

  final String placeId;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final place = SportPlace.byId(placeId);
    final onColor = isMine ? Colors.white : AppColors.onSurface;

    if (place == null) {
      return Text(
        AppStrings.chatForwardedPlace,
        style: TextStyle(color: onColor, fontSize: 14),
      );
    }

    return InkWell(
      onTap: () => context.go(AppRoutes.maps, extra: place.id),
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
                imageUrl: place.imageUrl,
                height: 110,
                width: 220,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  height: 110,
                  width: 220,
                  color: AppColors.surfaceMuted,
                  child: Icon(
                    place.primarySport.icon,
                    size: 40,
                    color: place.primarySport.color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              place.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: <Widget>[
                Icon(Icons.place_outlined, size: 13, color: onColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    place.address.isEmpty ? place.city : place.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: onColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
