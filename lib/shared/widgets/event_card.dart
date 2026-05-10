import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/event.dart';

/// Card horizontal de evento usado tanto na "Home > Eventos Próximos"
/// quanto na aba "Eventos". O texto do CTA varia conforme o contexto
/// (`Participar` na home, `Ver mais` na lista completa).
class EventCard extends StatelessWidget {
  const EventCard({
    required this.event,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final Event event;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          event.sport.label,
                          style: const TextStyle(
                            color: AppColors.onSurfaceMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: AppColors.onSurfaceMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.location}, ${event.remainingSpots} vagas restantes',
                      style: const TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: event.bannerUrl,
                  width: 88,
                  height: 72,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 88,
                    height: 72,
                    color: AppColors.surfaceMuted,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 88,
                    height: 72,
                    color: AppColors.surfaceMuted,
                    child: Icon(event.sport.icon, color: event.sport.color),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: event.isFull ? null : onAction,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.surfaceMuted,
                foregroundColor: AppColors.onSurface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Text(event.isFull ? 'Sem vagas' : actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
