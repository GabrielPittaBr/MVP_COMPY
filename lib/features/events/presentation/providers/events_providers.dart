import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../core/providers/clock_providers.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/event_status.dart';
import '../../../../shared/models/paged_result.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/datasources/events_remote_datasource.dart';
import '../../data/repositories/events_repository_impl.dart';
import '../../domain/entities/events_filter.dart';
import '../../domain/repositories/events_repository.dart';
import '../../domain/usecases/create_event.dart';
import '../../domain/usecases/join_event.dart';
import '../../domain/usecases/watch_event_detail.dart';
import '../../domain/usecases/watch_joined_active_events.dart';

final eventsRemoteDataSourceProvider = Provider<EventsRemoteDataSource?>(
  (ref) => kUseFirebaseRepos ? EventsRemoteDataSource(FirebaseFirestore.instance) : null,
);

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepositoryImpl(
    ref.watch(eventsRemoteDataSourceProvider),
    clock: ref.watch(clockProvider),
  ),
);

final watchEventDetailProvider = Provider<WatchEventDetail>(
  (ref) => WatchEventDetail(ref.watch(eventsRepositoryProvider)),
);

final joinEventProvider = Provider<JoinEvent>(
  (ref) => JoinEvent(ref.watch(eventsRepositoryProvider)),
);

final watchJoinedActiveEventsProvider = Provider<WatchJoinedActiveEvents>(
  (ref) => WatchJoinedActiveEvents(ref.watch(eventsRepositoryProvider)),
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

  /// Teto de páginas lidas numa carga só. O repositório tira os eventos
  /// encerrados (tarefa 14), então uma página pode chegar vazia com mais
  /// páginas pela frente; sem buscar a próxima, a lista ficaria num spinner
  /// sem fim quando a tela não chega a rolar. O teto evita um laço de
  /// leituras se houver muitos encerrados seguidos.
  static const int maxPagesPerLoad = 5;

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
    final page = await _fetchVisible(
      ref.watch(eventsRepositoryProvider),
      cursor: null,
      filter: _filter,
    );
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
      final page = await _fetchVisible(
        ref.read(eventsRepositoryProvider),
        cursor: _cursor,
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

  /// Busca a partir de [cursor] até vir algum evento, acabarem as páginas
  /// ou bater [maxPagesPerLoad].
  Future<PagedResult<Event>> _fetchVisible(
    EventsRepository repository, {
    required Object? cursor,
    required EventsFilter filter,
  }) async {
    var page = await repository.fetchPage(
      cursor: cursor,
      pageSize: pageSize,
      filter: filter,
    );
    final items = <Event>[...page.items];
    for (var loaded = 1;
        items.isEmpty && page.hasMore && loaded < maxPagesPerLoad;
        loaded++) {
      page = await repository.fetchPage(
        cursor: page.cursor,
        pageSize: pageSize,
        filter: filter,
      );
      items.addAll(page.items);
    }
    return PagedResult<Event>(
      items: items,
      cursor: page.cursor,
      hasMore: page.hasMore,
    );
  }
}

final paginatedEventsProvider =
    AsyncNotifierProvider<PaginatedEventsController, List<Event>>(
  PaginatedEventsController.new,
);

/// Seção "Criados por mim" da aba Eventos — lista completa, sem cursor.
///
/// O uid vem do [currentUserSummaryProvider], e não direto do
/// [authStateProvider], porque ele já resolve o modo mock (onde não existe
/// uid do Firebase e a identidade vem de `MockProfile`).
final myEventsProvider = FutureProvider<List<Event>>((ref) async {
  final filter = ref.watch(eventsFilterProvider);
  final repository = ref.watch(eventsRepositoryProvider);
  final user = await ref.watch(currentUserSummaryProvider.future);
  return repository.fetchCreatedBy(user.id, filter: filter);
});

/// Eventos não encerrados de que o usuário participa, inclusive os que ele
/// mesmo criou, em tempo real (tarefa 14). É a fonte única do card do
/// evento ao vivo e da seção "Participando".
final joinedActiveEventsProvider = StreamProvider<List<Event>>((ref) async* {
  final watchJoined = ref.watch(watchJoinedActiveEventsProvider);
  final user = await ref.watch(currentUserSummaryProvider.future);
  yield* watchJoined(user.id);
});

/// Seção "Participando" — o [joinedActiveEventsProvider] com o filtro da
/// folha aplicado no cliente (a duplicação com "Criados por mim" é
/// intencional).
final joinedEventsProvider = Provider<AsyncValue<List<Event>>>((ref) {
  final filter = ref.watch(eventsFilterProvider);
  return ref
      .watch(joinedActiveEventsProvider)
      .whenData((events) => events.where(filter.matches).toList());
});

/// Eventos acontecendo agora de que o usuário participa — o card ao vivo
/// do topo da aba Eventos. Ignora o filtro da folha de propósito: o atalho
/// para o jogo em andamento não pode sumir por causa de um filtro.
final liveEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(joinedActiveEventsProvider).valueOrNull;
  if (events == null || events.isEmpty) return const <Event>[];
  final now = ref.watch(nowProvider).valueOrNull ?? ref.watch(clockProvider)();
  return <Event>[
    for (final event in events)
      if (event.statusAt(now) == EventStatus.happening) event,
  ];
});

/// Recarrega as três seções da aba Eventos.
///
/// Sempre as três juntas: criar um evento mexe em "Criados por mim",
/// "Participando" (o criador já entra como participante) e "Todos os
/// eventos" ao mesmo tempo. Invalidar só uma deixa a tela mentindo.
void invalidateEventLists(WidgetRef ref) {
  ref.invalidate(paginatedEventsProvider);
  ref.invalidate(myEventsProvider);
  ref.invalidate(joinedActiveEventsProvider);
}

/// Detalhe de um evento por id, em tempo real (tarefa 14): um join ou um
/// encerramento aparece na tela sem invalidar nada.
final eventDetailProvider = StreamProvider.family<Event?, String>((ref, id) {
  return ref.watch(watchEventDetailProvider).call(id);
});
