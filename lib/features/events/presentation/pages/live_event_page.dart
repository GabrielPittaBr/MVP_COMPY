import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/clock_providers.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/event_status.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/event_status_chip.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/repositories/events_repository.dart';
import '../providers/events_providers.dart';
import '../widgets/live_progress.dart';

/// Tela do evento em andamento (tarefa 14), em `/events/:id/ao-vivo`.
///
/// Só para quem participa, inclusive o criador: quem não participa, ou
/// chega antes do início, vai para o detalhe. Cada pessoa da lista tem um
/// atalho para a conversa 1:1 (D16), menos você mesmo — o chat não abre
/// conversa consigo mesmo (`Conversation.idBetween` com `a == b`).
///
/// Só o criador vê "Encerrar evento". Se o evento encerrar com a tela
/// aberta, o participante vê a faixa de encerrado pelo stream.
class LiveEventPage extends ConsumerStatefulWidget {
  const LiveEventPage({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<LiveEventPage> createState() => _LiveEventPageState();
}

class _LiveEventPageState extends ConsumerState<LiveEventPage> {
  bool _opening = false;
  bool _leaving = false;
  bool _ending = false;

  Future<void> _confirmAndEnd(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.eventEndConfirmTitle),
        content: const Text(AppStrings.eventEndConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(AppStrings.eventEndConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _ending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(endEventProvider).call(event.id);
      if (!mounted) return;
      // O evento sai das listas e o detalhe já mostra o encerrado; a
      // avaliação entra no lugar desta navegação no ticket 09.
      invalidateEventLists(ref);
      context.go(AppRoutes.eventDetailPath(event.id));
    } on EventAlreadyEndedException {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.eventAlreadyEndedError)),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.eventEndError)),
      );
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  /// Mesmo fluxo da "Nova conversa" do chat, com a trava contra toque
  /// repetido: o id determinístico evita a conversa duplicada, mas não a
  /// navegação em dobro.
  Future<void> _openConversation(UserSummary peer) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final me = await ref.read(currentUserSummaryProvider.future);
      final conversationId =
          await ref.read(openConversationProvider).call(me: me, peer: peer);
      ref.invalidate(paginatedConversationsProvider);
      ref.invalidate(conversationProvider(conversationId));
      if (!mounted) return;
      context.go('${AppRoutes.chat}/$conversationId');
    } catch (_) {
      if (!mounted) return;
      setState(() => _opening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.chatOpenConversationError)),
      );
    }
  }

  /// Leva ao detalhe quem não deveria estar aqui. Depois do frame, porque
  /// navegar durante o build é proibido.
  Widget _leave() {
    if (!_leaving) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.eventDetailPath(widget.eventId));
      });
    }
    return const _LoadingScaffold();
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final me = ref.watch(currentUserSummaryProvider).valueOrNull;
    final event = eventAsync.valueOrNull;

    if (eventAsync.hasError) {
      return _MessageScaffold(text: 'Erro: ${eventAsync.error}');
    }
    if (event == null && eventAsync.hasValue) {
      return const _MessageScaffold(text: AppStrings.eventNotFound);
    }
    if (event == null || me == null) return const _LoadingScaffold();

    final isMember =
        event.creator.id == me.id || event.participantIds.contains(me.id);
    return EventStatusBuilder(
      event: event,
      builder: (context, status) {
        if (!isMember || status == EventStatus.scheduled) return _leave();
        return _LiveScaffold(
          event: event,
          me: me,
          status: status,
          opening: _opening,
          onMessage: _openConversation,
          ending: _ending,
          onEnd: () => _confirmAndEnd(event),
        );
      },
    );
  }
}

class _LiveScaffold extends StatelessWidget {
  const _LiveScaffold({
    required this.event,
    required this.me,
    required this.status,
    required this.opening,
    required this.onMessage,
    required this.ending,
    required this.onEnd,
  });

  final Event event;
  final UserSummary me;
  final EventStatus status;
  final bool opening;
  final ValueChanged<UserSummary> onMessage;
  final bool ending;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final isCreator = event.creator.id == me.id;
    final ended = status == EventStatus.ended;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.eventLiveTitle),
        bottom: opening
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: <Widget>[
          if (ended && !isCreator) ...<Widget>[
            const _EndedBanner(),
            const SizedBox(height: 16),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: EventStatusChip(
              status: status,
              endedAutomatically: event.endedAutomatically,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            event.title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(event.sport.icon, size: 18, color: event.sport.color),
              const SizedBox(width: 8),
              Text(event.sport.label, style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          _Schedule(event: event, isCreator: isCreator, ended: ended),
          const SizedBox(height: 16),
          _PlaceCard(event: event),
          if (!isCreator) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: opening ? null : () => onMessage(event.creator),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surfaceMuted,
                  foregroundColor: AppColors.onSurface,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                label: const Text(AppStrings.eventLiveTalkToOrganizer),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            AppStrings.eventParticipantsCount(event.participants.length),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          for (final person in _organizerFirst(event))
            _ParticipantTile(
              person: person,
              isOrganizer: person.id == event.creator.id,
              isMe: person.id == me.id,
              onMessage: opening ? null : () => onMessage(person),
            ),
        ],
      ),
      bottomNavigationBar: isCreator && !ended
          ? DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.outlineSoft)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: PrimaryButton(
                    label: AppStrings.eventEnd,
                    icon: Icons.stop_circle_outlined,
                    onPressed: ending ? null : onEnd,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  /// O organizador no topo da lista; os demais na ordem em que entraram.
  static List<UserSummary> _organizerFirst(Event event) => <UserSummary>[
        ...event.participants.where((p) => p.id == event.creator.id),
        ...event.participants.where((p) => p.id != event.creator.id),
      ];
}

/// Horário, barra de tempo decorrido e "Faltam X" / "Passou X do previsto",
/// mais o aviso de atraso para cada papel. Lê o "agora" sozinho, para só ele
/// se redesenhar a cada 30s.
class _Schedule extends ConsumerWidget {
  const _Schedule({
    required this.event,
    required this.isCreator,
    required this.ended,
  });

  final Event event;
  final bool isCreator;

  /// Encerrado: a barra e o horário ficam, o "Faltam" e o aviso saem.
  final bool ended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now =
        ref.watch(nowProvider).valueOrNull ?? ref.watch(clockProvider)();
    final progress = LiveProgress.of(event, now);
    final time = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          AppStrings.eventLiveSchedule(
            time.format(event.dateTime),
            time.format(event.endsAt),
          ),
          style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.fraction,
            minHeight: 8,
            backgroundColor: AppColors.outline,
            color: progress.overdue ? AppColors.warning : AppColors.primary,
          ),
        ),
        if (!ended) ...<Widget>[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              progress.overdue
                  ? AppStrings.eventLiveOverdueBy(
                      DurationFormat.short(progress.minutesOver),
                    )
                  : AppStrings.eventLiveRemaining(
                      DurationFormat.short(progress.minutesLeft),
                    ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: progress.overdue
                    ? AppColors.warningText
                    : AppColors.onSurface,
              ),
            ),
          ),
          if (progress.overdue) ...<Widget>[
            const SizedBox(height: 14),
            _OverdueNotice(
              text: isCreator
                  ? AppStrings.eventLiveOverdueCreator
                  : AppStrings.eventLiveOverdueParticipant,
            ),
          ],
        ],
      ],
    );
  }
}

/// Aviso de que o horário previsto acabou, com a borda de atenção.
class _OverdueNotice extends StatelessWidget {
  const _OverdueNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.warning),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.schedule, color: AppColors.warningText, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 14, height: 1.45)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faixa do participante quando o organizador encerra com a tela aberta.
class _EndedBanner extends StatelessWidget {
  const _EndedBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.flag_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                AppStrings.eventEndedByOrganizer,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Local vindo do snapshot do evento — não consulta `places`.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final snapshot = event.placeSnapshot;
    final city = snapshot == null
        ? null
        : '${snapshot.address.city}, ${snapshot.address.state}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  snapshot?.name ?? event.location,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (city != null)
                  Text(
                    city,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.person,
    required this.isOrganizer,
    required this.isMe,
    required this.onMessage,
  });

  final UserSummary person;
  final bool isOrganizer;
  final bool isMe;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          UserAvatar(user: person, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      person.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isOrganizer)
                      const _Tag(
                        label: AppStrings.eventLiveOrganizer,
                        color: AppColors.primary,
                      ),
                    if (isMe)
                      const _Tag(
                        label: AppStrings.eventLiveYou,
                        color: AppColors.onSurface,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  person.handle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!isMe)
            IconButton(
              onPressed: onMessage,
              tooltip: AppStrings.eventLiveMessage(person.name),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceMuted,
                foregroundColor: AppColors.primary,
                fixedSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(AppStrings.eventLiveTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(AppStrings.eventLiveTitle)),
        body: Center(child: Text(text)),
      );
}
