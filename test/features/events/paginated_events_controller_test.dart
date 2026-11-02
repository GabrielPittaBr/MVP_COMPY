import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/features/events/domain/entities/events_filter.dart';
import 'package:mvp_compy/features/events/domain/repositories/events_repository.dart';
import 'package:mvp_compy/features/events/presentation/providers/events_providers.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/paged_result.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

/// Devolve as páginas na ordem pedida e repete a última quando acabam —
/// como um Firestore em que o filtro de encerrados esvazia as páginas.
class _PaginasRoteirizadas implements EventsRepository {
  _PaginasRoteirizadas(this.paginas);

  final List<PagedResult<Event>> paginas;
  final List<Object?> cursores = <Object?>[];

  @override
  Future<PagedResult<Event>> fetchPage({
    Object? cursor,
    int pageSize = 10,
    EventsFilter filter = const EventsFilter(),
  }) async {
    cursores.add(cursor);
    final i = cursores.length - 1;
    return paginas[i < paginas.length ? i : paginas.length - 1];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PagedResult<Event> _pagina(
  List<Event> items, {
  required Object cursor,
  bool hasMore = true,
}) =>
    PagedResult<Event>(items: items, cursor: cursor, hasMore: hasMore);

Event _evento(String id) => Event(
      id: id,
      title: id,
      sport: Sport.futebol,
      location: 'Taquara',
      coordinates: const LatLng(-29.65, -50.78),
      dateTime: DateTime(2026, 10, 22, 19),
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
    );

ProviderContainer _container(EventsRepository repository) {
  final container = ProviderContainer(
    overrides: <Override>[
      eventsRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a primeira carga pula páginas que vieram vazias pelo filtro', () async {
    final repository = _PaginasRoteirizadas(<PagedResult<Event>>[
      _pagina(const <Event>[], cursor: 1),
      _pagina(const <Event>[], cursor: 2),
      _pagina(<Event>[_evento('a')], cursor: 3),
    ]);
    final container = _container(repository);

    final eventos = await container.read(paginatedEventsProvider.future);

    expect(eventos.map((e) => e.id), <String>['a']);
    expect(repository.cursores, <Object?>[null, 1, 2]);
    expect(container.read(paginatedEventsProvider.notifier).hasMore, isTrue);
  });

  test('para no teto de páginas se tudo vier vazio', () async {
    final repository = _PaginasRoteirizadas(<PagedResult<Event>>[
      _pagina(const <Event>[], cursor: 1),
    ]);
    final container = _container(repository);

    final eventos = await container.read(paginatedEventsProvider.future);

    expect(eventos, isEmpty);
    expect(
      repository.cursores,
      hasLength(PaginatedEventsController.maxPagesPerLoad),
    );
  });

  test('loadMore também pula páginas vazias até achar eventos', () async {
    final repository = _PaginasRoteirizadas(<PagedResult<Event>>[
      _pagina(<Event>[_evento('a')], cursor: 1),
      _pagina(const <Event>[], cursor: 2),
      _pagina(<Event>[_evento('b')], cursor: 3, hasMore: false),
    ]);
    final container = _container(repository);
    await container.read(paginatedEventsProvider.future);

    await container.read(paginatedEventsProvider.notifier).loadMore();

    expect(
      container.read(paginatedEventsProvider).value!.map((e) => e.id),
      <String>['a', 'b'],
    );
    expect(container.read(paginatedEventsProvider.notifier).hasMore, isFalse);
  });
}
