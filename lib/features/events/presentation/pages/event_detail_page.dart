import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/utils/rating_format.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/event_status.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/custom_sport_marker.dart';
import '../../../../shared/widgets/event_status_chip.dart';
import '../../../../shared/widgets/event_skill_level_chip.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../ratings/domain/entities/rating_summary.dart';
import '../../../ratings/presentation/providers/ratings_providers.dart';
import '../../domain/repositories/events_repository.dart';
import '../providers/events_providers.dart';
import '../widgets/participants_avatars.dart';

/// Tela "3.1 Evento detalhes": cabeçalho com banner, dados,
/// criador, descrição, participantes e mapa do local.
///
/// Acompanha o documento em tempo real e mostra a ação certa para a fase do
/// evento e o papel de quem olha (tarefa 14) — ver [_ActionBar].
///
/// RN-05: o botão "Participar" é desabilitado quando `event.isFull`.
class EventDetailPage extends ConsumerWidget {
  const EventDetailPage({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(eventDetailProvider(eventId));
    final event = detailAsync.valueOrNull;

    return Scaffold(
      body: detailAsync.when(
        data: (event) {
          if (event == null) {
            return const Center(child: Text(AppStrings.eventNotFound));
          }
          return _Body(event: event);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
      // Barra fixa, como no design aprovado: a ação do evento fica sempre à
      // vista, sem precisar rolar até o fim.
      bottomNavigationBar: event == null ? null : _ActionBar(event: event),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dia da semana + intervalo início–fim ("Sábado, 15:00 – 16:00"):
    // saber a que horas acaba é mais útil que só o horário de início.
    final dayFormat = DateFormat('EEEE', 'pt_BR');

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.onSurface,
          elevation: 0,
          title: Text(event.title),
          leading: const BackButton(),
        ),
        SliverToBoxAdapter(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: event.bannerUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: AppColors.surfaceMuted,
                alignment: Alignment.center,
                child:
                    Icon(event.sport.icon, size: 60, color: event.sport.color),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              EventStatusBuilder(
                event: event,
                builder: (context, status) => status == EventStatus.scheduled
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: EventStatusChip(
                            status: status,
                            endedAutomatically: event.endedAutomatically,
                          ),
                        ),
                      ),
              ),
              Text(
                event.title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _IconRow(
                icon: event.sport.icon,
                iconColor: event.sport.color,
                label: event.sport.label,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: EventSkillLevelChip(level: event.skillLevel),
              ),
              const SizedBox(height: 8),
              _IconRow(
                icon: Icons.calendar_today_outlined,
                label: '${_capitalize(dayFormat.format(event.dateTime))}, '
                    '${DurationFormat.timeRange(event.dateTime, event.durationMinutes)}',
              ),
              const SizedBox(height: 8),
              _IconRow(
                icon: Icons.schedule,
                label: '${AppStrings.eventDuration}: '
                    '${DurationFormat.short(event.durationMinutes)}',
              ),
              EventStatusBuilder(
                event: event,
                builder: (context, status) => status == EventStatus.ended
                    ? _EventRatingCard(eventId: event.id)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),

              const Text(
                AppStrings.eventCreatedBy,
                style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _CreatorTile(event: event),
              const SizedBox(height: 20),

              // Descrição é opcional: sem texto, o bloco inteiro some
              // (nada de espaçamento órfão no meio do layout).
              if (event.description.isNotEmpty) ...<Widget>[
                const Text(
                  AppStrings.eventDescription,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(event.description, style: const TextStyle(height: 1.45)),
                const SizedBox(height: 24),
              ],

              ParticipantsAvatars(
                participants: event.participants,
                organizer: event.creator,
              ),
              const SizedBox(height: 24),

              const Text(
                AppStrings.eventLocation,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 160,
                  child: AbsorbPointer(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: event.coordinates,
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: <Widget>[
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'br.com.compy.mvp',
                        ),
                        MarkerLayer(
                          markers: <Marker>[
                            Marker(
                              point: event.coordinates,
                              // Mesmo pin do mapa e do preview de criação,
                              // aqui na modalidade do próprio evento.
                              width: 40,
                              height: 50,
                              alignment: Alignment.topCenter,
                              child: CustomSportMarker(
                                sport: event.sport,
                                selected: false,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}

/// Ação do detalhe para a fase do evento e o papel de quem olha (§8.4 da
/// tarefa 14).
enum _DetailAction {
  /// Agendado ou acontecendo, para quem não participa.
  join,

  /// O mesmo, com o evento lotado (RN-05).
  full,

  /// Acontecendo, para quem participa ou criou.
  openLive,

  /// Agendado, para quem participa.
  youAreIn,

  /// Agendado, para quem criou.
  youOrganize,

  /// Encerrado, para o participante que ainda não avaliou.
  rate,

  /// Encerrado, para o criador que ainda não avaliou o local e quem jogou.
  rateAsCreator,

  /// Encerrado, para quem já enviou a avaliação (`ratedBy`).
  alreadyRated,

  /// Encerrado, para quem não participou (ou o criador sem nada a avaliar).
  ended,
}

_DetailAction _actionFor(Event event, EventStatus status, String? uid) {
  final isCreator = uid != null && event.creator.id == uid;
  final isParticipant = uid != null && event.participantIds.contains(uid);
  if (status == EventStatus.ended) {
    if (!isCreator && !isParticipant) return _DetailAction.ended;
    if (event.hasRated(uid)) return _DetailAction.alreadyRated;
    if (!isCreator) return _DetailAction.rate;
    // O criador avalia o local e quem jogou, não o próprio evento (D14).
    final hasSomethingToRate = event.placeId != null ||
        event.participantIds.any((id) => id != uid);
    return hasSomethingToRate ? _DetailAction.rateAsCreator : _DetailAction.ended;
  }
  if (status == EventStatus.happening && (isCreator || isParticipant)) {
    return _DetailAction.openLive;
  }
  if (isCreator) return _DetailAction.youOrganize;
  if (isParticipant) return _DetailAction.youAreIn;
  return event.isFull ? _DetailAction.full : _DetailAction.join;
}

/// Barra fixa com a ação do detalhe. Corrige o "Participar" que aparecia
/// para quem já participava e para o próprio criador.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserSummaryProvider).valueOrNull?.id;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outlineSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: EventStatusBuilder(
            event: event,
            builder: (context, status) =>
                switch (_actionFor(event, status, uid)) {
              _DetailAction.join => PrimaryButton(
                  label: AppStrings.eventJoin,
                  onPressed: () => _join(context, ref),
                ),
              _DetailAction.openLive => PrimaryButton(
                  label: AppStrings.eventLiveOpenFromDetail,
                  icon: Icons.sensors,
                  onPressed: () =>
                      context.go(AppRoutes.liveEventPath(event.id)),
                ),
              _DetailAction.full => const PrimaryButton(
                  label: AppStrings.eventFull,
                  onPressed: null,
                ),
              _DetailAction.youAreIn => const _StatusPill(
                  icon: Icons.check_circle_outline,
                  label: AppStrings.eventYouAreIn,
                ),
              _DetailAction.youOrganize => const _StatusPill(
                  icon: Icons.flag_outlined,
                  label: AppStrings.eventYouOrganize,
                ),
              _DetailAction.rate => PrimaryButton(
                  label: AppStrings.eventRate,
                  icon: Icons.star_outline_rounded,
                  onPressed: () =>
                      context.push(AppRoutes.eventRatingPath(event.id)),
                ),
              _DetailAction.rateAsCreator => PrimaryButton(
                  label: AppStrings.eventRateAsCreator,
                  icon: Icons.star_outline_rounded,
                  onPressed: () =>
                      context.push(AppRoutes.eventRatingPath(event.id)),
                ),
              _DetailAction.alreadyRated => const _StatusPill(
                  icon: Icons.check_circle_outline,
                  label: AppStrings.eventAlreadyRated,
                ),
              _DetailAction.ended => const _StatusPill(
                  icon: Icons.event_busy_outlined,
                  label: AppStrings.eventAlreadyEnded,
                ),
            },
          ),
        ),
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // UserSummary real do usuário autenticado (users/{uid} no Firestore).
      final user = await ref.read(currentUserSummaryProvider.future);
      await ref.read(joinEventProvider).call(event.id, user);
      // O detalhe acompanha o documento e já reflete o join; as seções da
      // aba Eventos, que são leituras únicas, precisam recarregar — o evento
      // passa a valer para "Participando".
      invalidateEventLists(ref);
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.eventJoined)),
      );
    } on EventFullException {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.eventFull)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${AppStrings.eventJoinError}: $e')),
      );
    }
  }
}

/// "Nota do evento ★ 4,6 · 8 avaliações", no detalhe do evento encerrado
/// que já recebeu notas (tarefa 14). Sem nota nenhuma, não ocupa espaço.
class _EventRatingCard extends ConsumerWidget {
  const _EventRatingCard({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref
        .watch(ratingSummaryProvider((type: RatingTargetType.event, id: eventId)))
        .valueOrNull;
    if (summary == null || !summary.hasRatings) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              AppStrings.eventRatingAverage,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                StarRating(value: summary.average.round(), size: 18),
                const SizedBox(width: 8),
                Text(
                  RatingFormat.average(summary.average),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '· ${AppStrings.ratingsCount(summary.count)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurfaceMuted,
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

/// Situação de quem olha, no lugar de um botão: não há ação a tomar.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 20, color: AppColors.onSurfaceMuted),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({
    required this.icon,
    required this.label,
    this.iconColor = AppColors.onSurface,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: iconColor),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class _CreatorTile extends ConsumerWidget {
  const _CreatorTile({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(publicUserSummaryProvider(event.creator.id));
    final creator = current.hasValue && current.valueOrNull == null
        ? UserSummary(
            id: event.creator.id,
            name: event.creator.name,
            handle: event.creator.handle,
            avatarUrl: '',
          )
        : current.valueOrNull ?? event.creator;
    return InkWell(
      key: const Key('event-creator-profile'),
      onTap: () => context.push(AppRoutes.publicProfileFor(event.creator.id)),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: <Widget>[
            UserAvatar(user: creator, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    creator.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    creator.handle,
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.onSurfaceMuted),
          ],
        ),
      ),
    );
  }
}
