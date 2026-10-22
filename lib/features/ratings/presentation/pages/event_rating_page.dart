import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/clock_providers.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/event_status.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../events/presentation/providers/events_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/event_rating_submission.dart';
import '../../domain/entities/rating_draft.dart';
import '../../domain/rating_validation.dart';
import '../../domain/repositories/ratings_repository.dart';
import '../providers/ratings_providers.dart';
import '../widgets/rating_input.dart';

/// Passos da avaliação. O passo dos participantes entra no ticket 10.
enum _RatingStep { event, place }

/// Avaliação de um evento encerrado (tarefa 14), em tela cheia, fora do
/// shell: `/avaliacao/:eventId`, aberta com `push`.
///
/// O participante avalia o evento e o local; o criador só o local, porque
/// não avalia o próprio evento (D14). Evento legado sem local pula esse
/// passo. Tudo vai de uma vez, no fim, para a callable.
class EventRatingPage extends ConsumerStatefulWidget {
  const EventRatingPage({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<EventRatingPage> createState() => _EventRatingPageState();
}

class _EventRatingPageState extends ConsumerState<EventRatingPage> {
  final Map<_RatingStep, RatingDraft> _drafts = <_RatingStep, RatingDraft>{};
  int _index = 0;
  bool _sending = false;
  bool _sent = false;

  RatingDraft _draftOf(_RatingStep step) =>
      _drafts[step] ?? const RatingDraft();

  bool get _hasInput => _drafts.values.any((draft) => !draft.isEmpty);

  static List<_RatingStep> _stepsFor(Event event, String uid) => <_RatingStep>[
        if (event.creator.id != uid) _RatingStep.event,
        if (event.placeId != null) _RatingStep.place,
      ];

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.eventDetailPath(widget.eventId));
    }
  }

  Future<void> _close() async {
    if (_hasInput && !_sent) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(AppStrings.ratingExitTitle),
          content: const Text(AppStrings.ratingExitBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(AppStrings.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text(AppStrings.ratingExitConfirm),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    _leave();
  }

  Future<void> _submit(Event event, String uid, List<_RatingStep> steps) async {
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    void fail(String message) =>
        messenger.showSnackBar(SnackBar(content: Text(message)));
    try {
      await ref.read(submitEventRatingsProvider).call(
            EventRatingSubmission(
              eventId: event.id,
              raterId: uid,
              event: steps.contains(_RatingStep.event)
                  ? _draftOf(_RatingStep.event)
                  : null,
              place: steps.contains(_RatingStep.place)
                  ? _draftOf(_RatingStep.place)
                  : null,
            ),
          );
      if (!mounted) return;
      setState(() => _sent = true);
    } on RatingAlreadySubmittedException {
      fail(AppStrings.ratingErrorAlreadyRated);
      if (mounted) _leave();
    } on RatingEventNotEndedException {
      fail(AppStrings.ratingErrorNotEnded);
    } on RatingNotParticipantException {
      fail(AppStrings.ratingErrorNotParticipant);
    } on RatingOfflineException {
      fail(AppStrings.ratingErrorOffline);
    } catch (_) {
      fail(AppStrings.ratingErrorGeneric);
    } finally {
      if (mounted && !_sent) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return _SentView(
        onBack: () => context.go(AppRoutes.eventDetailPath(widget.eventId)),
      );
    }

    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final me = ref.watch(currentUserSummaryProvider).valueOrNull;
    final event = eventAsync.valueOrNull;
    if (eventAsync.hasError) {
      return _MessageView(text: 'Erro: ${eventAsync.error}', onClose: _leave);
    }
    if (event == null && eventAsync.hasValue) {
      return _MessageView(text: AppStrings.eventNotFound, onClose: _leave);
    }
    if (event == null || me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Quem já enviou não avalia de novo; o "Você já avaliou" do detalhe
    // existe para ninguém chegar aqui, mas a rota pode ser aberta direto.
    final String? blocker;
    if (event.hasRated(me.id)) {
      blocker = AppStrings.ratingErrorAlreadyRated;
    } else if (!event.participantIds.contains(me.id)) {
      blocker = AppStrings.ratingErrorNotParticipant;
    } else if (event.statusAt(ref.read(clockProvider)()) != EventStatus.ended) {
      blocker = AppStrings.ratingErrorNotEnded;
    } else {
      blocker = null;
    }
    final steps = _stepsFor(event, me.id);
    if (blocker != null || steps.isEmpty) {
      return _MessageView(
        text: blocker ?? AppStrings.ratingNothingToRate,
        onClose: _leave,
      );
    }

    final index = _index.clamp(0, steps.length - 1);
    final step = steps[index];
    final draft = _draftOf(step);
    final last = index == steps.length - 1;
    final canGo = RatingValidation.isValid(draft) && !_sending;

    return PopScope(
      canPop: !_hasInput,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: AppStrings.ratingClose,
            onPressed: _close,
          ),
          title: const Text(
            AppStrings.ratingTitle,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        body: Column(
          children: <Widget>[
            _StepProgress(index: index, total: steps.length),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: <Widget>[
                  _TargetHeader(step: step, event: event),
                  const SizedBox(height: 32),
                  Text(
                    step == _RatingStep.event
                        ? AppStrings.ratingEventQuestion
                        : AppStrings.ratingPlaceQuestion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  RatingInput(
                    key: ValueKey<_RatingStep>(step),
                    draft: draft,
                    onChanged: (value) => setState(() => _drafts[step] = value),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: PrimaryButton(
              label: _sending
                  ? AppStrings.ratingSending
                  : last
                      ? AppStrings.ratingSubmit
                      : AppStrings.ratingContinue,
              onPressed: !canGo
                  ? null
                  : last
                      ? () => _submit(event, me.id, steps)
                      : () => setState(() => _index = index + 1),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra em segmentos e "Passo i de n".
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (var i = 0; i < total; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= index ? AppColors.primary : AppColors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.ratingStep(index + 1, total),
            style:
                const TextStyle(fontSize: 13, color: AppColors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

/// O que está sendo avaliado no passo: o evento ou o local.
class _TargetHeader extends StatelessWidget {
  const _TargetHeader({required this.step, required this.event});

  final _RatingStep step;
  final Event event;

  @override
  Widget build(BuildContext context) {
    final snapshot = event.placeSnapshot;
    final placeName = snapshot?.name ?? event.location;
    final isEvent = step == _RatingStep.event;
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isEvent
                ? event.sport.color.withValues(alpha: 0.16)
                : AppColors.surfaceMuted,
          ),
          child: Icon(
            isEvent ? event.sport.icon : Icons.location_on_outlined,
            size: 22,
            color: isEvent ? event.sport.color : AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                isEvent ? event.title : placeName,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Text(
                isEvent
                    ? '${event.sport.label} · $placeName'
                    : snapshot == null
                        ? ''
                        : '${snapshot.address.city}, ${snapshot.address.state}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SentView extends StatelessWidget {
  const _SentView({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 152,
                        height: 152,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceMuted,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        AppStrings.ratingSent,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        AppStrings.ratingThanks,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: AppColors.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: PrimaryButton(
                  label: AppStrings.ratingBack, onPressed: onBack),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: AppStrings.ratingClose,
          onPressed: onClose,
        ),
        title: const Text(AppStrings.ratingTitle),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
