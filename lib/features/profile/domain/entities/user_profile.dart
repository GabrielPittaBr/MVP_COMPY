import 'package:equatable/equatable.dart';

import '../../../../shared/models/sport.dart';
import '../../../../shared/models/user_summary.dart';
import 'badge.dart';
import 'rating_summary.dart';

/// Perfil completo do usuário (RF01 + RF08 + RF10).
///
/// Apenas `bio`, `favoriteSports`, `badges`, `friends`, `rating` e `gallery`
/// são exibidos publicamente — campos sensíveis (telefone, e-mail) ficam
/// fora desta entidade por design (RN-06).
class UserProfile extends Equatable {
  const UserProfile({
    required this.summary,
    required this.bio,
    required this.favoriteSports,
    required this.badges,
    required this.friends,
    required this.rating,
    required this.gallery,
  });

  final UserSummary summary;
  final String bio;
  final List<Sport> favoriteSports;
  final List<Badge> badges;
  final List<UserSummary> friends;
  final RatingSummary rating;
  final List<String> gallery;

  @override
  List<Object?> get props => <Object?>[
        summary,
        bio,
        favoriteSports,
        badges,
        friends,
        rating,
        gallery,
      ];
}
