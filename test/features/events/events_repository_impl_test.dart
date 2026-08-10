import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/events/data/repositories/events_repository_impl.dart';
import 'package:mvp_compy/features/events/domain/entities/events_filter.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
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
      final page = await repo.fetchPage(
        pageSize: 50,
        filter: const EventsFilter(sport: Sport.futebol),
      );
      expect(page.items, isNotEmpty);
      expect(page.items.every((e) => e.sport == Sport.futebol), isTrue);
    });

    test('paginação percorre o conjunto filtrado, não o completo', () async {
      const filter = EventsFilter(sport: Sport.futebol);
      final all = await repo.fetchPage(pageSize: 50, filter: filter);
      final collected = <String>[];

      Object? cursor;
      var hasMore = true;
      // Páginas de 1 em 1: cada uma precisa vir cheia enquanto houver
      // eventos de futebol — o filtro é aplicado antes de paginar.
      while (hasMore) {
        final page =
            await repo.fetchPage(cursor: cursor, pageSize: 1, filter: filter);
        expect(page.items.every((e) => e.sport == Sport.futebol), isTrue);
        collected.addAll(page.items.map((e) => e.id));
        cursor = page.cursor;
        hasMore = page.hasMore;
      }

      expect(collected, all.items.map((e) => e.id).toList());
    });

    test('filtro por nível inclui os eventos abertos a todos os níveis',
        () async {
      final page = await repo.fetchPage(
        pageSize: 50,
        filter: const EventsFilter(skillLevel: SkillLevel.iniciante),
      );
      expect(
        page.items.every((e) =>
            e.skillLevel == SkillLevel.iniciante ||
            e.skillLevel == SkillLevel.todos),
        isTrue,
      );
    });

    test('filtro por dia recorta o intervalo [dia, dia+1)', () async {
      final todos = await repo.fetchPage(pageSize: 50);
      final referencia = todos.items.first.dateTime;
      final dia = DateTime(referencia.year, referencia.month, referencia.day);

      final page = await repo.fetchPage(
        pageSize: 50,
        filter: const EventsFilter().withDay(dia),
      );

      expect(page.items, isNotEmpty);
      expect(
        page.items.every((e) =>
            e.dateTime.year == dia.year &&
            e.dateTime.month == dia.month &&
            e.dateTime.day == dia.day),
        isTrue,
      );
    });

    test('critérios se somam em vez de se substituírem', () async {
      final base = await repo.fetchPage(
        pageSize: 50,
        filter: const EventsFilter(sport: Sport.futebol),
      );
      final combinado = await repo.fetchPage(
        pageSize: 50,
        filter: const EventsFilter(
          sport: Sport.futebol,
          skillLevel: SkillLevel.avancado,
        ).withDay(base.items.first.dateTime),
      );

      expect(combinado.items.length, lessThanOrEqualTo(base.items.length));
      expect(combinado.items.every((e) => e.sport == Sport.futebol), isTrue);
    });
  });

  group('EventsFilter', () {
    test('vazio por padrão e não-vazio com qualquer critério', () {
      expect(const EventsFilter().isEmpty, isTrue);
      expect(const EventsFilter(sport: Sport.corrida).isNotEmpty, isTrue);
      expect(
        const EventsFilter(skillLevel: SkillLevel.avancado).isNotEmpty,
        isTrue,
      );
    });

    test('cada with* limpa só o próprio critério', () {
      final filter = const EventsFilter(
        sport: Sport.volei,
        skillLevel: SkillLevel.iniciante,
      ).withDay(DateTime(2026, 8, 10));

      expect(filter.withSport(null).sport, isNull);
      expect(filter.withSport(null).skillLevel, SkillLevel.iniciante);
      expect(filter.withSport(null).day, DateTime(2026, 8, 10));
      expect(filter.withDay(null).day, isNull);
      expect(filter.withDay(null).sport, Sport.volei);
    });

    test('withDay normaliza para a meia-noite local', () {
      final filter = const EventsFilter().withDay(DateTime(2026, 8, 10, 21, 30));
      expect(filter.day, DateTime(2026, 8, 10));
      expect(filter.dayEnd, DateTime(2026, 8, 11));
    });

    test('nível de habilidade casa com o pedido e com "todos"', () {
      const filter = EventsFilter(skillLevel: SkillLevel.intermediario);
      expect(filter.matchesSkillLevel(SkillLevel.intermediario), isTrue);
      expect(filter.matchesSkillLevel(SkillLevel.todos), isTrue);
      expect(filter.matchesSkillLevel(SkillLevel.avancado), isFalse);
    });
  });
}
