import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../models/event.dart';
import '../models/event_status.dart';
import 'event_status_chip.dart';
import 'event_skill_level_chip.dart';
import 'event_schedule_sheet.dart';

/// Card horizontal de evento usado tanto na "Home > Eventos Próximos"
/// quanto na aba "Eventos". O texto do CTA varia conforme o contexto
/// (`Participar` na home, `Ver mais` na lista completa).
class EventCard extends StatelessWidget {
  const EventCard({
    required this.event,
    required this.actionLabel,
    required this.onOpen,
    this.onAction,
    this.disableWhenFull = true,
    this.status,
    super.key,
  });

  final Event event;
  final String actionLabel;
  final VoidCallback onOpen;

  /// Sem ação específica, o CTA abre os detalhes como o corpo do card.
  /// Uma ação distinta mantém seu próprio gesto e nó de acessibilidade.
  final VoidCallback? onAction;

  /// Se um evento lotado (RN-05) trava o CTA e troca o rótulo por
  /// "Sem vagas". Vale para o "Participar" da Home, mas não para o "Ver
  /// mais" da aba Eventos: nas seções "Criados por mim" e "Participando"
  /// aparecem eventos lotados de propósito, e abrir os detalhes de um
  /// evento que você criou ou de que já participa continua fazendo sentido.
  final bool disableWhenFull;

  /// Fase do evento, calculada por quem monta a lista com o "agora" do app
  /// (ver [EventStatusBuilder]). Acontecendo, o selo toma o lugar do ícone
  /// de calendário; nulo ou agendado, fica o calendário.
  final EventStatus? status;

  @override
  Widget build(BuildContext context) {
    final blocked = disableWhenFull && event.isFull;

    final action = TextButton(
      onPressed: blocked ? null : (onAction ?? onOpen),
      style: TextButton.styleFrom(
        backgroundColor: AppColors.surfaceMuted,
        foregroundColor: AppColors.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      child: Text(blocked ? AppStrings.eventCardFull : actionLabel),
    );

    return Semantics(
      key: ValueKey('event-card-${event.id}'),
      container: true,
      button: true,
      hint: AppStrings.eventOpenDetails,
      onTap: onOpen,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          excludeFromSemantics: true,
          child: Padding(
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
                              Flexible(
                                child: Text(
                                  event.sport.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.onSurfaceMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (status != EventStatus.happening)
                                IconButton(
                                  tooltip: AppStrings.eventDateTimeTitle,
                                  onPressed: () =>
                                      showEventScheduleSheet(context, event),
                                  icon:
                                      const Icon(Icons.calendar_today_outlined),
                                  iconSize: 16,
                                  color: AppColors.onSurfaceMuted,
                                  constraints: const BoxConstraints(
                                      minWidth: 48, minHeight: 48),
                                  padding: EdgeInsets.zero,
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
                            '${event.location}, ${event.remainingSpots} ${AppStrings.eventVacanciesLabel}',
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
                          child:
                              Icon(event.sport.icon, color: event.sport.color),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (status == EventStatus.happening)
                      const EventStatusChip(status: EventStatus.happening),
                    EventSkillLevelChip(level: event.skillLevel, compact: true),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ExcludeFocus(
                    excluding: onAction == null,
                    child: ExcludeSemantics(
                      // Uma única ação de detalhes para leitores de tela.
                      excluding: onAction == null,
                      child: blocked
                          // Um botão desabilitado não disputa o gesto com o pai.
                          // Consumimos esse toque para não abrir os detalhes.
                          ? GestureDetector(
                              onTap: () {},
                              excludeFromSemantics: true,
                              child: action)
                          : action,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
