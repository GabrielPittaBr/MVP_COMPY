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
    this.durationMinutes = defaultDurationMinutes,
    this.description = '',
    this.participants = const <UserSummary>[],
  });

  /// Duração assumida quando o criador não informou nada — vale tanto
  /// para o pré-selecionado do formulário quanto para os eventos
  /// gravados antes da tarefa 3 (documentos sem `durationMinutes`).
  static const int defaultDurationMinutes = 60;

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

  /// Duração informada pelo criador, em minutos.
  final int durationMinutes;
  final String description;
  final List<UserSummary> participants;

  /// RN-05: evento sem vagas restantes deve ser ocultado / impedido de receber inscrições.
  bool get isFull => remainingSpots <= 0;

  /// Fim previsto do evento (início + duração).
  DateTime get endsAt => dateTime.add(Duration(minutes: durationMinutes));

  /// Ids dos participantes — projeção consultável de [participants].
  ///
  /// O Firestore não enxerga dentro de mapas: `arrayContains` sobre
  /// `participants` exigiria o mapa **inteiro** idêntico, então trocar de
  /// avatar ou de nome faria o usuário sumir da própria seção
  /// "Participando". Por isso a seção consulta este campo, não o outro.
  ///
  /// Derivado em vez de armazenado, como `titleLower`, `geohash` e `endsAt`:
  /// o valor existe no documento (via [toMap]) só para o servidor poder
  /// filtrar; no cliente `participants` continua sendo a única fonte de
  /// verdade, e os dois não têm como sair de sincronia.
  List<String> get participantIds =>
      <String>[for (final p in participants) p.id];

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
        'durationMinutes': durationMinutes,
        // Fim previsto desnormalizado: o Firestore não calcula nada em
        // consulta, então "esconder eventos encerrados" e "acontecendo
        // agora" (tarefa 14) precisam do campo gravado para filtrar no
        // servidor sem quebrar a paginação.
        'endsAt': Timestamp.fromDate(endsAt),
        'skillLevel': skillLevel.name,
        'totalSpots': totalSpots,
        'remainingSpots': remainingSpots,
        'bannerUrl': bannerUrl,
        'creator': creator.toMap(),
        'description': description,
        'participants': participants.map((p) => p.toMap()).toList(),
        // Espelho consultável de `participants` — ver [participantIds].
        // A transação de `join()` mantém os dois em `arrayUnion` no mesmo
        // update, e as regras exigem que cresçam juntos.
        'participantIds': participantIds,
      };

  factory Event.fromMap(String id, Map<String, dynamic> data) {
    final geoPoint = data['coordinates'] as GeoPoint?;
    final timestamp = data['dateTime'] as Timestamp?;
    final startsAt = timestamp?.toDate() ?? DateTime.now();

    // Eventos criados antes da tarefa 3 não têm `durationMinutes`. Se o
    // documento tiver ao menos `endsAt`, a duração vem dele; senão cai
    // no padrão de 1h.
    final storedEndsAt = (data['endsAt'] as Timestamp?)?.toDate();
    final durationMinutes = (data['durationMinutes'] as int?) ??
        (storedEndsAt != null && storedEndsAt.isAfter(startsAt)
            ? storedEndsAt.difference(startsAt).inMinutes
            : defaultDurationMinutes);

    return Event(
      id: id,
      title: (data['title'] as String?) ?? '',
      sport: Sport.tryParse(data['sport']) ?? Sport.futebol,
      location: (data['location'] as String?) ?? '',
      coordinates: geoPoint != null
          ? LatLng(geoPoint.latitude, geoPoint.longitude)
          : const LatLng(0, 0),
      dateTime: startsAt,
      durationMinutes: durationMinutes,
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
    int? durationMinutes,
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
      durationMinutes: durationMinutes ?? this.durationMinutes,
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
        durationMinutes,
        skillLevel,
        totalSpots,
        remainingSpots,
        bannerUrl,
        creator,
        description,
        participants,
      ];
}
