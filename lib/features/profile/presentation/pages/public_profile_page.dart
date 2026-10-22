import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/profile_providers.dart';
import '../widgets/favorite_sports_chips.dart';
import 'profile_page.dart';

class PublicProfilePage extends ConsumerStatefulWidget {
  const PublicProfilePage({required this.uid, super.key});

  final String uid;

  @override
  ConsumerState<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends ConsumerState<PublicProfilePage> {
  bool _opening = false;

  Future<void> _message(UserProfile profile) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final me = await ref.read(currentUserSummaryProvider.future);
      if (me.id == profile.summary.id) return;
      final conversationId = await ref.read(openConversationProvider).call(
            me: me,
            peer: profile.summary,
          );
      ref.invalidate(paginatedConversationsProvider);
      ref.invalidate(conversationProvider(conversationId));
      if (!mounted) return;
      context.push<void>('${AppRoutes.chat}/$conversationId');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.chatOpenConversationError)),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A rota pública para o próprio uid reutiliza a tela proprietária, sem
    // oferecer conversa consigo mesmo nem trocar a pilha de navegação.
    if (widget.uid == ref.watch(currentUserIdProvider)) {
      return const ProfilePage();
    }

    final profile = ref.watch(publicProfileProvider(widget.uid));
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profilePublicTitle)),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _Notice(
          text: AppStrings.profilePublicError,
          onRetry: () => ref.invalidate(publicProfileProvider(widget.uid)),
        ),
        data: (value) {
          if (value == null) {
            return const _Notice(text: AppStrings.profilePublicNotFound);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: <Widget>[
              Center(child: UserAvatar(user: value.summary, radius: 56)),
              const SizedBox(height: 12),
              Text(
                value.summary.name,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                value.summary.handle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.onSurfaceMuted),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: AppStrings.profileMessage,
                icon: Icons.chat_bubble_outline,
                onPressed: _opening ? null : () => _message(value),
              ),
              if (_opening) const LinearProgressIndicator(minHeight: 2),
              if (value.bio.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                Text(value.bio.trim()),
              ],
              const SizedBox(height: 28),
              const Text(
                AppStrings.profileFavoriteSports,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (value.favoriteSports.isEmpty)
                const Text(
                  AppStrings.profileNoFavoriteSports,
                  style: TextStyle(color: AppColors.onSurfaceMuted),
                )
              else
                FavoriteSportsChips(sports: value.favoriteSports),
            ],
          );
        },
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text(AppStrings.authRetry),
              ),
          ],
        ),
      );
}
