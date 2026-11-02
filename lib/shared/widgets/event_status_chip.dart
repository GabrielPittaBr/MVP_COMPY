import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/providers/clock_providers.dart';
import '../../core/theme/app_colors.dart';
import '../models/event.dart';
import '../models/event_status.dart';

/// Selo da fase do evento: "Acontecendo agora", "Encerrado" ou "Encerrado
/// automaticamente". Evento agendado não tem selo.
///
/// Contraste AA (tarefa 14): o verde #10B981 não passa como texto sobre
/// branco, então ele fica só no ponto e o texto é escuro. "Encerrado" usa o
/// cinza de texto secundário, que passa sobre o branco.
class EventStatusChip extends StatelessWidget {
  const EventStatusChip({
    required this.status,
    this.endedAutomatically = false,
    super.key,
  });

  final EventStatus status;

  /// Troca o texto do encerrado por "Encerrado automaticamente".
  final bool endedAutomatically;

  @override
  Widget build(BuildContext context) {
    if (status == EventStatus.scheduled) return const SizedBox.shrink();
    final live = status == EventStatus.happening;
    final label = live
        ? AppStrings.eventStatusLive
        : endedAutomatically
            ? AppStrings.eventStatusEndedAutomatically
            : AppStrings.eventStatusEnded;

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: live ? AppColors.surfaceMuted : AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: live ? null : Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: live ? AppColors.secondary : AppColors.onSurfaceMuted,
              boxShadow: live
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: live ? AppColors.onSurface : AppColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Calcula a fase de [event] com o "agora" do app e entrega a [builder].
///
/// O `nowProvider` emite a cada 30s, mas o `select` só reconstrói este
/// widget quando a fase muda — e só ele, não a lista em volta (hipótese 9
/// da tarefa 14).
class EventStatusBuilder extends ConsumerWidget {
  const EventStatusBuilder({
    required this.event,
    required this.builder,
    super.key,
  });

  final Event event;
  final Widget Function(BuildContext context, EventStatus status) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.watch(clockProvider);
    final status = ref.watch(
      nowProvider.select((now) => event.statusAt(now.valueOrNull ?? clock())),
    );
    return builder(context, status);
  }
}
