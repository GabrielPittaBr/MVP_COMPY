import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/clock_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/user_avatar.dart';
import 'live_progress.dart';

/// Card do evento em andamento, no topo da aba Eventos (tarefa 14).
///
/// Fundo azul primário com texto branco, como no design aprovado. Em atraso
/// (fim previsto passou, ainda na folga de 1h), a barra fica cheia e o
/// aviso usa o laranja [AppColors.warning], que tem contraste AA sobre o
/// azul.
class LiveEventCard extends ConsumerWidget {
  const LiveEventCard({required this.event, required this.onOpen, super.key});

  final Event event;
  final VoidCallback onOpen;

  static const Color _muted = Color(0xD9FFFFFF); // branco a 85%

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now =
        ref.watch(nowProvider).valueOrNull ?? ref.watch(clockProvider)();
    final progress = LiveProgress.of(event, now);
    final place = event.placeSnapshot?.name ?? event.location;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _LiveBadge(),
              const Spacer(),
              Text(
                AppStrings.eventLiveEndsAt(
                  DateFormat('HH:mm').format(event.endsAt),
                ),
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${event.sport.label} · $place',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              color: progress.overdue ? AppColors.warning : AppColors.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              progress.overdue
                  ? AppStrings.eventLiveOverdue
                  : AppStrings.eventLiveRemaining(
                      DurationFormat.short(progress.minutesLeft),
                    ),
              style: progress.overdue
                  ? const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    )
                  : const TextStyle(fontSize: 12, color: _muted),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _AvatarStack(participants: event.participants),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppStrings.eventParticipantsShort(event.participants.length),
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ),
              FilledButton(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text(AppStrings.eventLiveOpen),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pílula "AO VIVO" com o ponto verde.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            AppStrings.eventLiveBadge,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Até três avatares sobrepostos, com o anel na cor do card.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.participants});

  final List<UserSummary> participants;

  static const double _size = 28;
  static const double _step = 20;

  @override
  Widget build(BuildContext context) {
    final visible = participants.take(3).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: _size + (visible.length - 1) * _step + 4,
      height: _size + 4,
      child: Stack(
        children: <Widget>[
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * _step,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: UserAvatar(user: visible[i], radius: _size / 2),
              ),
            ),
        ],
      ),
    );
  }
}
