import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../shared/models/event.dart';
import '../../data/datasources/events_remote_datasource.dart';
import '../../data/repositories/events_repository_impl.dart';
import '../../domain/entities/events_filter.dart';
import '../../domain/repositories/events_repository.dart';
import '../../domain/usecases/create_event.dart';
import '../../domain/usecases/get_event_detail.dart';
import '../../domain/usecases/join_event.dart';

final eventsRemoteDataSourceProvider = Provider<EventsRemoteDataSource?>(
  (ref) => kUseFirebaseRepos ? EventsRemoteDataSource(FirebaseFirestore.instance) : null,
);

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepositoryImpl(ref.watch(eventsRemoteDataSourceProvider)),
);

final getEventDetailProvider = Provider<GetEventDetail>(
  (ref) => GetEventDetail(ref.watch(eventsRepositoryProvider)),
);

final joinEventProvider = Provider<JoinEvent>(
  (ref) => JoinEvent(ref.watch(eventsRepositoryProvider)),
);

final createEventProvider = Provider<CreateEvent>(
  (ref) => CreateEvent(ref.watch(eventsRepositoryProvider)),
);

/// Critérios ativos da aba "Eventos" — vazio lista tudo.
///
/// Escrito pelas categorias da Home, pela folha de filtros e pelo "x" de
/// cada chip da lista.
final eventsFilterProvider =
    StateProvider<EventsFilter>((ref) => const EventsFilter());

/// Lista paginada da aba "5 Eventos" — blocos de 10 documentos via
/// `startAfterDocument`. Use `loadMore()` ao aproximar do fim do scroll e
/// `ref.invalidate(paginatedEventsProvider)` para recarregar do zero
/// (pull-to-refresh, após criar evento etc.).
class PaginatedEventsController extends AsyncNotifier<List<Event>> {
  static const int pageSize = 10;

  Object? _cursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  EventsFilter _filter = const EventsFilter();

  /// Se ainda há páginas para buscar — controla o footer de loading.
  bool get hasMore => _hasMore;

  @override
  Future<List<Event>> build() async {
    _cursor = null;
    _hasMore = true;
    _isLoadingMore = false;
    // Observar o filtro aqui faz o controller ser reconstruído a cada
    // mudança — a paginação reseta naturalmente, sem estado órfão.
    _filter = ref.watch(eventsFilterProvider);
    final page = await ref
        .watch(eventsRepositoryProvider)
        .fetchPage(pageSize: pageSize, filter: _filter);
    _cursor = page.cursor;
    _hasMore = page.hasMore;
    return page.items;
  }

  /// Anexa a próxima página. No-op se já está carregando ou acabou.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || _isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    final requestedFilter = _filter;
    try {
      final page = await ref.read(eventsRepositoryProvider).fetchPage(
            cursor: _cursor,
            pageSize: pageSize,
            filter: requestedFilter,
          );
      // O filtro pode ter mudado durante a busca — nesse caso o build()
      // já repopulou o estado e esta página é lixo.
      if (requestedFilter != _filter) return;
      _cursor = page.cursor;
      _hasMore = page.hasMore;
      state = AsyncData<List<Event>>(<Event>[...current, ...page.items]);
    } finally {
      _isLoadingMore = false;
    }
  }
}

final paginatedEventsProvider =
    AsyncNotifierProvider<PaginatedEventsController, List<Event>>(
  PaginatedEventsController.new,
);

/// Detalhe de um evento por id. `family` permite cachear por id;
/// invalidado explicitamente após join/create.
final eventDetailProvider =
    FutureProvider.family<Event?, String>((ref, id) async {
  return ref.watch(getEventDetailProvider).call(id);
});
