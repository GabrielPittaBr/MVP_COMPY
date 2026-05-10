import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import 'skill_level.dart';
import 'sport.dart';
import 'user_summary.dart';

/// Entidade central de evento esportivo.
///
/// Compartilhada entre as features Home (cards de "Eventos Próximos"),
/// Events (lista, detalhes, criação) e Maps (eventos vinculados a um local).
///
/// Os campos `description` e `participants` são populados na tela de
/// detalhes (RF07); nas listas eles podem vir vazios sem prejuízo.
class Event extends Equatable {
  const Event({
    required this.id,
    required this.title,
    required this.sport,
    required this.location,
    required this.coordinates,
    required this.dateTime,
    required this.skillLevel,
    required this.totalSpots,
    required this.remainingSpots,
    required this.bannerUrl,
    required this.creator,
    this.description = '',
    this.participants = const <UserSummary>[],
  });

  final String id;
  final String title;
  final Sport sport;
  final String location;
  final LatLng coordinates;
  final DateTime dateTime;
  final SkillLevel skillLevel;
  final int totalSpots;
  final int remainingSpots;
  final String bannerUrl;
  final UserSummary creator;
  final String description;
  final List<UserSummary> participants;

  /// RN-05: evento sem vagas restantes deve ser ocultado / impedido de receber inscrições.
  bool get isFull => remainingSpots <= 0;

  Event copyWith({
    int? remainingSpots,
    List<UserSummary>? participants,
  }) {
    return Event(
      id: id,
      title: title,
      sport: sport,
      location: location,
      coordinates: coordinates,
      dateTime: dateTime,
      skillLevel: skillLevel,
      totalSpots: totalSpots,
      remainingSpots: remainingSpots ?? this.remainingSpots,
      bannerUrl: bannerUrl,
      creator: creator,
      description: description,
      participants: participants ?? this.participants,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        title,
        sport,
        location,
        coordinates,
        dateTime,
        skillLevel,
        totalSpots,
        remainingSpots,
        bannerUrl,
        creator,
        description,
        participants,
      ];
}
