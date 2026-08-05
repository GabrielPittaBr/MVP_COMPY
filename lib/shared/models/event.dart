import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../core/utils/geohash.dart';
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

  // ── Serialização Firestore ──────────────────────────────────────

  Map<String, dynamic> toMap() => <String, dynamic>{
        'title': title,
        // Índice de busca por prefixo (Firestore não faz busca
        // case-insensitive; gravamos a versão minúscula para consultar).
        'titleLower': title.toLowerCase(),
        'sport': sport.name,
        'location': location,
        'coordinates': GeoPoint(coordinates.latitude, coordinates.longitude),
        // Índice geográfico para a busca por raio na Home (RF03).
        'geohash': Geohash.encode(coordinates.latitude, coordinates.longitude),
        'dateTime': Timestamp.fromDate(dateTime),
        'skillLevel': skillLevel.name,
        'totalSpots': totalSpots,
        'remainingSpots': remainingSpots,
        'bannerUrl': bannerUrl,
        'creator': creator.toMap(),
        'description': description,
        'participants': participants.map((p) => p.toMap()).toList(),
      };

  factory Event.fromMap(String id, Map<String, dynamic> data) {
    final geoPoint = data['coordinates'] as GeoPoint?;
    final timestamp = data['dateTime'] as Timestamp?;

    return Event(
      id: id,
      title: (data['title'] as String?) ?? '',
      sport: Sport.values.firstWhere(
        (s) => s.name == data['sport'],
        orElse: () => Sport.futebol,
      ),
      location: (data['location'] as String?) ?? '',
      coordinates: geoPoint != null
          ? LatLng(geoPoint.latitude, geoPoint.longitude)
          : const LatLng(0, 0),
      dateTime: timestamp?.toDate() ?? DateTime.now(),
      skillLevel: SkillLevel.values.firstWhere(
        (l) => l.name == data['skillLevel'],
        orElse: () => SkillLevel.todos,
      ),
      totalSpots: (data['totalSpots'] as int?) ?? 0,
      remainingSpots: (data['remainingSpots'] as int?) ?? 0,
      bannerUrl: (data['bannerUrl'] as String?) ?? '',
      creator: UserSummary.fromMap(data['creator']),
      description: (data['description'] as String?) ?? '',
      participants: (data['participants'] as List<dynamic>? ?? <dynamic>[])
          .map((p) => UserSummary.fromMap(p))
          .toList(),
    );
  }

  // ── copyWith ────────────────────────────────────────────────────

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
