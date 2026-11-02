import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_summary.dart';
import '../../../../shared/widgets/pill_tag.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// O evento mantém seu snapshot; só a apresentação acompanha users/{uid}.
UserSummary _shownUser(WidgetRef ref, UserSummary snapshot) {
  final current = ref.watch(publicUserSummaryProvider(snapshot.id));
  if (current.hasValue && current.valueOrNull == null) {
    return UserSummary(
      id: snapshot.id,
      name: snapshot.name,
      handle: snapshot.handle,
      avatarUrl: '',
    );
  }
  return current.valueOrNull ?? snapshot;
}

/// Prévia compacta. Só o organizador e até três avatares têm listeners aqui.
class ParticipantsAvatars extends ConsumerWidget {
  const ParticipantsAvatars({
    required this.participants,
    required this.organizer,
    this.meId,
    this.onMessage,
    super.key,
  });

  final List<UserSummary> participants;
  final UserSummary organizer;
  final String? meId;
  final ValueChanged<UserSummary>? onMessage;

  List<UserSummary> get _ordered {
    final seen = <String>{};
    return <UserSummary>[
      for (final person in <UserSummary>[organizer, ...participants])
        if (person.id.isNotEmpty && seen.add(person.id)) person,
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = _ordered;
    final shownOrganizer = _shownUser(ref, organizer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Flexible(
              child: Text(
                AppStrings.eventParticipants,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text('${people.length}',
                style: const TextStyle(color: AppColors.onSurfaceMuted)),
            const Spacer(),
            TextButton(
              key: const Key('participants-see-all'),
              onPressed: () => _showAll(context, people),
              child: const Text(AppStrings.eventSeeAllParticipants),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          key: const Key('participants-preview'),
          onTap: () => _showAll(context, people),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineSoft),
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 44.0 + (people.take(3).length - 1).clamp(0, 2) * 26,
                  height: 44,
                  child: Stack(
                    children: <Widget>[
                      for (var i = 0; i < people.length && i < 3; i++)
                        Positioned(
                          left: i * 26.0,
                          child: _PreviewAvatar(person: people[i]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(AppStrings.eventLiveOrganizer,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.onSurfaceMuted)),
                      Text(
                        shownOrganizer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAll(BuildContext pageContext, List<UserSummary> people) {
    showModalBottomSheet<void>(
      context: pageContext,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.78,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        AppStrings.eventParticipantsCount(people.length),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: AppStrings.eventCloseParticipants,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  key: const Key('participants-full-list'),
                  itemCount: people.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 80,
                    endIndent: 20,
                  ),
                  itemBuilder: (context, index) {
                    final person = people[index];
                    return _ParticipantRow(
                      snapshot: person,
                      isOrganizer: person.id == organizer.id,
                      isMe: person.id == meId,
                      showMessage: onMessage != null,
                      onProfile: () {
                        Navigator.of(sheetContext).pop();
                        pageContext.push(AppRoutes.publicProfileFor(person.id));
                      },
                      onMessage: onMessage == null
                          ? null
                          : (current) {
                              Navigator.of(sheetContext).pop();
                              onMessage!(current);
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewAvatar extends ConsumerWidget {
  const _PreviewAvatar({required this.person});
  final UserSummary person;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        key: Key('participant-preview-${person.id}'),
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
            color: AppColors.surface, shape: BoxShape.circle),
        child: UserAvatar(user: _shownUser(ref, person), radius: 20),
      );
}

class _ParticipantRow extends ConsumerWidget {
  const _ParticipantRow({
    required this.snapshot,
    required this.isOrganizer,
    required this.isMe,
    required this.showMessage,
    required this.onProfile,
    required this.onMessage,
  });

  final UserSummary snapshot;
  final bool isOrganizer;
  final bool isMe;
  final bool showMessage;
  final VoidCallback onProfile;
  final ValueChanged<UserSummary>? onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = _shownUser(ref, snapshot);
    return InkWell(
      key: Key('participant-row-${person.id}'),
      onTap: onProfile,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: <Widget>[
            UserAvatar(user: person, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isMe) ...<Widget>[
                        const SizedBox(width: 6),
                        const PillTag(label: AppStrings.eventLiveYou),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    person.handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.onSurfaceMuted),
                  ),
                  if (isOrganizer) ...<Widget>[
                    const SizedBox(height: 4),
                    const PillTag(
                      label: AppStrings.eventLiveOrganizer,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),
            if (showMessage && !isMe) ...<Widget>[
              const SizedBox(width: 4),
              IconButton(
                onPressed: onMessage == null ? null : () => onMessage!(person),
                tooltip: AppStrings.eventLiveMessage(person.name),
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                color: AppColors.primary,
              ),
            ] else
              const Icon(Icons.chevron_right, color: AppColors.onSurfaceMuted),
          ],
        ),
      ),
    );
  }
}
