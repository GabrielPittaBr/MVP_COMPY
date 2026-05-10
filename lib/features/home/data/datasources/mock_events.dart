import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/skill_level.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/user_summary.dart';

/// Fixtures de eventos próximos. Compartilhado por home (lista de
/// "Eventos Próximos") e events (lista completa + detalhes).
abstract final class MockEvents {
  static final UserSummary _carlao = UserSummary(
    id: 'u_carlao',
    name: 'Carlos Alberto',
    handle: '@carlao.alberto',
    avatarUrl: AppAssets.avatar('Carlos'),
  );

  static final UserSummary _joao = UserSummary(
    id: 'u_joao',
    name: 'João Souza',
    handle: '@joao.souza',
    avatarUrl: AppAssets.avatar('João'),
  );

  static final UserSummary _hercules = UserSummary(
    id: 'u_hercules',
    name: 'Hércules',
    handle: '@hercules',
    avatarUrl: AppAssets.avatar('Hércules'),
  );

  static final List<UserSummary> _participants10 = List<UserSummary>.generate(
    10,
    (i) => UserSummary(
      id: 'p_$i',
      name: 'Participante ${i + 1}',
      handle: '@p${i + 1}',
      avatarUrl: AppAssets.avatar('${i + 1}'),
    ),
  );

  /// Lista usada na home e na aba "Eventos".
  static List<Event> get nearby => <Event>[
        Event(
          id: 'evt_001',
          title: 'Amistoso',
          sport: Sport.futebol,
          location: 'Taquara',
          coordinates: const LatLng(-29.6485, -50.7820),
          dateTime: DateTime.now().add(const Duration(days: 2, hours: 4)),
          skillLevel: SkillLevel.intermediario,
          totalSpots: 14,
          remainingSpots: 5,
          bannerUrl: AppAssets.soccerBanner,
          creator: _carlao,
          description:
              'Precisamos de 4 pessoas para completar os times, chegar pronto pra jogar.',
          participants: _participants10,
        ),
        Event(
          id: 'evt_002',
          title: 'Rachão',
          sport: Sport.basquete,
          location: 'Taquara',
          coordinates: const LatLng(-29.6512, -50.7765),
          dateTime: DateTime.now().add(const Duration(days: 1, hours: 6)),
          skillLevel: SkillLevel.iniciante,
          totalSpots: 10,
          remainingSpots: 2,
          bannerUrl: AppAssets.basketballBanner,
          creator: _hercules,
          description: 'Jogo descontraído entre amigos. Bola J, água e energia.',
          participants: _participants10.take(8).toList(),
        ),
        Event(
          id: 'evt_003',
          title: 'Valendo horário',
          sport: Sport.volei,
          location: 'Taquara',
          coordinates: const LatLng(-29.6470, -50.7750),
          dateTime: DateTime.now().add(const Duration(days: 3, hours: 2)),
          skillLevel: SkillLevel.avancado,
          totalSpots: 12,
          remainingSpots: 3,
          bannerUrl: AppAssets.volleyballBanner,
          creator: _joao,
          description: 'Quem perder paga a água. Time fechado, vamos com tudo.',
          participants: _participants10.take(9).toList(),
        ),
        Event(
          id: 'evt_004',
          title: 'Amistoso',
          sport: Sport.futebol,
          location: 'Taquara',
          coordinates: const LatLng(-29.6500, -50.7790),
          dateTime: DateTime.now().add(const Duration(days: 5, hours: 1)),
          skillLevel: SkillLevel.intermediario,
          totalSpots: 14,
          remainingSpots: 5,
          bannerUrl: AppAssets.soccerBanner,
          creator: _carlao,
          description: 'Mais um amistoso clássico de fim de semana.',
          participants: _participants10.take(9).toList(),
        ),
      ];
}
