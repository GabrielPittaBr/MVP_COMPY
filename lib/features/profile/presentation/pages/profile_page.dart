import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/badges_row.dart';
import '../widgets/favorite_sports_chips.dart';
import '../widgets/friends_avatars.dart';
import '../widgets/photo_gallery.dart';
import '../widgets/profile_header.dart';
import '../widgets/rating_breakdown.dart';

/// Tela "4 Perfil" — RF01 (cadastro), RF08 (gamificação) e RF10 (galeria).
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.profileTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ProfileHeader(summary: profile.summary),
              const SizedBox(height: 24),

              _SectionTitle(
                AppStrings.profileFavoriteSports,
                // Entrada dedicada em vez de sequestrar "Editar perfil":
                // aquele botão ainda vai abrir a edição completa (bio, foto),
                // e prometer isso aqui seria mentira.
                onEdit: () => context.push(AppRoutes.profileFavoriteSports),
              ),
              const SizedBox(height: 8),
              FavoriteSportsChips(sports: profile.favoriteSports),
              const SizedBox(height: 24),

              const _SectionTitle(AppStrings.profileBadges),
              const SizedBox(height: 12),
              BadgesRow(badges: profile.badges),
              const SizedBox(height: 24),

              const _SectionTitle(AppStrings.profileFriends),
              const SizedBox(height: 12),
              FriendsAvatars(friends: profile.friends),
              const SizedBox(height: 24),

              const _SectionTitle(AppStrings.profileRatings),
              const SizedBox(height: 12),
              RatingBreakdown(summary: profile.rating),
              const SizedBox(height: 24),

              const _SectionTitle(AppStrings.profileGallery),
              const SizedBox(height: 12),
              PhotoGallery(photos: profile.gallery),
              const SizedBox(height: 32),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.onEdit});

  final String text;

  /// Quando presente, a seção ganha um lápis à direita do título.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    const TextStyle style = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.onSurface,
    );

    if (onEdit == null) return Text(text, style: style);

    return Row(
      children: <Widget>[
        Text(text, style: style),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          color: AppColors.onSurfaceMuted,
          tooltip: AppStrings.profileEditFavoriteSports,
          visualDensity: VisualDensity.compact,
          onPressed: onEdit,
        ),
      ],
    );
  }
}
