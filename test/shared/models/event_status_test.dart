import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/event_status.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

final _inicio = DateTime(2026, 10, 21, 19);

Event _evento({DateTime? endedAt, List<String> ratedBy = const <String>[]}) {
  return Event(
    id: 'evt_status',
    title: 'Pelada',
    sport: Sport.futebol,
    location: 'Taquara',
    coordinates: const LatLng(-29.65, -50.78),
    dateTime: _inicio,
    durationMinutes: 90,
    skillLevel: SkillLevel.todos,
    totalSpots: 10,
    remainingSpots: 9,
    bannerUrl: '',
    creator: const UserSummary(
      id: 'u_dono',
      name: 'Dono',
      handle: '@dono',
      avatarUrl: '',
    ),
    endedAt: endedAt,
    ratedBy: ratedBy,
  );
}

void main() {
  group('EventLifecycle.statusAt', () {
    final evento = _evento();
    final fimPrevisto = _inicio.add(const Duration(minutes: 90));

    test('antes do início está agendado', () {
      expect(
        evento.statusAt(_inicio.subtract(const Duration(seconds: 1))),
        EventStatus.scheduled,
      );
    });

    test('exatamente no início já está acontecendo', () {
      expect(evento.statusAt(_inicio), EventStatus.happening);
    });

    test('exatamente no fim previsto ainda está acontecendo', () {
      expect(evento.statusAt(fimPrevisto), EventStatus.happening);
    });

    test('um instante antes de fim + 1h ainda está acontecendo', () {
      expect(
        evento.statusAt(
          fimPrevisto.add(kEventEndTolerance - const Duration(seconds: 1)),
        ),
        EventStatus.happening,
      );
    });

    test('exatamente em fim + 1h está encerrado, mesmo sem endedAt', () {
      expect(
        evento.statusAt(fimPrevisto.add(kEventEndTolerance)),
        EventStatus.ended,
      );
    });

    test('endedAt gravado antes do início encerra o evento', () {
      final encerrado =
          _evento(endedAt: _inicio.subtract(const Duration(hours: 2)));
      expect(
        encerrado.statusAt(_inicio.subtract(const Duration(hours: 3))),
        EventStatus.ended,
      );
    });

    test('endedAt gravado durante o evento encerra na hora', () {
      final encerrado = _evento(endedAt: _inicio.add(const Duration(minutes: 30)));
      expect(
        encerrado.statusAt(_inicio.add(const Duration(minutes: 40))),
        EventStatus.ended,
      );
    });
  });

  group('EventLifecycle.isOverdueAt', () {
    final evento = _evento();
    final fimPrevisto = _inicio.add(const Duration(minutes: 90));

    test('não está em atraso antes do fim previsto', () {
      expect(
        evento.isOverdueAt(fimPrevisto.subtract(const Duration(seconds: 1))),
        isFalse,
      );
    });

    test('está em atraso do fim previsto até o fim da folga', () {
      expect(evento.isOverdueAt(fimPrevisto), isTrue);
      expect(
        evento.isOverdueAt(fimPrevisto.add(const Duration(minutes: 59))),
        isTrue,
      );
    });

    test('depois da folga não está em atraso, está encerrado', () {
      expect(evento.isOverdueAt(fimPrevisto.add(kEventEndTolerance)), isFalse);
    });
  });

  test('hasRated olha o ratedBy', () {
    final evento = _evento(ratedBy: const <String>['u_ana']);
    expect(evento.hasRated('u_ana'), isTrue);
    expect(evento.hasRated('u_bia'), isFalse);
  });

  group('Event e os campos do ciclo de vida', () {
    test('fromMap lê endedAt, endedAutomatically e ratedBy', () {
      final fim = DateTime(2026, 10, 21, 21, 30);
      final dados = _evento().toMap()
        ..['endedAt'] = Timestamp.fromDate(fim)
        ..['endedAutomatically'] = true
        ..['ratedBy'] = <String>['u_ana', 'u_bia'];

      final lido = Event.fromMap('evt_status', dados);

      expect(lido.endedAt, fim);
      expect(lido.endedAutomatically, isTrue);
      expect(lido.ratedBy, <String>['u_ana', 'u_bia']);
    });

    test('fromMap sem os campos assume evento aberto e sem avaliações', () {
      final lido = Event.fromMap('evt_status', _evento().toMap());

      expect(lido.endedAt, isNull);
      expect(lido.endedAutomatically, isFalse);
      expect(lido.ratedBy, isEmpty);
    });

    test('toMap nunca grava os campos, que são do servidor', () {
      final mapa = _evento(
        endedAt: DateTime(2026, 10, 21, 21),
        ratedBy: const <String>['u_ana'],
      ).copyWith(endedAutomatically: true).toMap();

      expect(mapa.containsKey('endedAt'), isFalse);
      expect(mapa.containsKey('endedAutomatically'), isFalse);
      expect(mapa.containsKey('ratedBy'), isFalse);
    });

    test('os campos entram na igualdade e no copyWith', () {
      final aberto = _evento();
      final encerrado = aberto.copyWith(
        endedAt: DateTime(2026, 10, 21, 21),
        endedAutomatically: true,
        ratedBy: const <String>['u_ana'],
      );

      expect(encerrado, isNot(aberto));
      expect(encerrado.endedAt, DateTime(2026, 10, 21, 21));
      expect(encerrado.endedAutomatically, isTrue);
      expect(encerrado.ratedBy, <String>['u_ana']);
      expect(encerrado.copyWith(remainingSpots: 3).ratedBy, <String>['u_ana']);
    });
  });
}
