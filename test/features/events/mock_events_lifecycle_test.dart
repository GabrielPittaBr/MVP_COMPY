import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/events/data/datasources/in_memory_events_store.dart';
import 'package:mvp_compy/features/home/data/datasources/mock_events.dart';
import 'package:mvp_compy/shared/models/event_status.dart';

/// O usuário do modo mock (MockProfile e InMemoryChatStore).
const _joao = 'u_joao';

void main() {
  group('MockEvents.nearby', () {
    final now = DateTime.now();
    final eventos = MockEvents.nearby;

    test('o criador participa do próprio evento', () {
      final doJoao = eventos.where((e) => e.creator.id == _joao);
      expect(doJoao, isNotEmpty);
      for (final evento in doJoao) {
        expect(evento.participantIds, contains(_joao));
      }
    });

    test('tem um evento ao vivo com o João participando', () {
      final aoVivo = eventos.where(
        (e) => e.statusAt(now) == EventStatus.happening,
      );
      expect(aoVivo, hasLength(1));
      expect(aoVivo.single.participantIds, contains(_joao));
      expect(aoVivo.single.isOverdueAt(now), isFalse);
    });

    test('tem um evento encerrado com o João, ainda sem avaliação', () {
      final encerrados = eventos.where(
        (e) => e.statusAt(now) == EventStatus.ended,
      );
      expect(encerrados, hasLength(1));
      final encerrado = encerrados.single;
      expect(encerrado.endedAt, isNotNull);
      expect(encerrado.endedAt!.isBefore(now), isTrue);
      expect(encerrado.participantIds, contains(_joao));
      expect(encerrado.hasRated(_joao), isFalse);
    });

    test('as vagas batem com os participantes em todos os eventos', () {
      for (final evento in eventos) {
        expect(
          evento.participants.length + evento.remainingSpots,
          evento.totalSpots,
          reason: evento.id,
        );
      }
    });
  });

  test('add() gera id para rascunho sem id', () {
    final store = InMemoryEventsStore.instance;
    final rascunho = MockEvents.nearby.first.copyWith(id: '');

    final criado = store.add(rascunho);

    expect(criado.id, isNotEmpty);
    expect(store.getById(criado.id), criado);
  });
}
