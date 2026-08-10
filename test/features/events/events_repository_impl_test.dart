import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/events/data/repositories/events_repository_impl.dart';
import 'package:mvp_compy/shared/models/sport.dart';

void main() {
  // `_remote == null` força o ramo mock (InMemoryEventsStore), sem Firebase.
  final repo = EventsRepositoryImpl(null);

  group('EventsRepositoryImpl.fetchPage', () {
    test('sem filtro devolve eventos de várias modalidades', () async {
      final page = await repo.fetchPage(pageSize: 50);
      expect(page.items, isNotEmpty);
      expect(page.items.map((e) => e.sport).toSet().length, greaterThan(1));
    });

    test('com filtro devolve só a modalidade pedida', () async {
      final page = await repo.fetchPage(pageSize: 50, sport: Sport.futebol);
      expect(page.items, isNotEmpty);
      expect(page.items.every((e) => e.sport == Sport.futebol), isTrue);
    });

    test('paginação percorre o conjunto filtrado, não o completo', () async {
      final all = await repo.fetchPage(pageSize: 50, sport: Sport.futebol);
      final collected = <String>[];

      Object? cursor;
      var hasMore = true;
      // Páginas de 1 em 1: cada uma precisa vir cheia enquanto houver
      // eventos de futebol — o filtro é aplicado antes de paginar.
      while (hasMore) {
        final page =
            await repo.fetchPage(cursor: cursor, pageSize: 1, sport: Sport.futebol);
        expect(page.items.every((e) => e.sport == Sport.futebol), isTrue);
        collected.addAll(page.items.map((e) => e.id));
        cursor = page.cursor;
        hasMore = page.hasMore;
      }

      expect(collected, all.items.map((e) => e.id).toList());
    });
  });
}
