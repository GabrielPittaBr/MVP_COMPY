import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_flags.dart';
import '../../../../core/providers/clock_providers.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/event_status.dart';
import '../../../../shared/models/paged_result.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/datasources/events_remote_datasource.dart';
import '../../data/repositories/events_repository_impl.dart';
import '../../domain/entities/events_filter.dart';
import '../../domain/repositories/events_repository.dart';
import '../../domain/usecases/create_event.dart';
import '../../domain/usecases/delete_own_event.dart';
import '../../domain/usecases/end_event.dart';
import '../../domain/usecases/join_event.dart';
import '../../domain/usecases/watch_event_detail.dart';
import '../../domain/usecases/watch_joined_active_events.dart';

final eventsRemoteDataSourceProvider = Provider<EventsRemoteDataSource?>(
  (ref) => kUseFirebaseRepos
      ? EventsRemoteDataSource(
          FirebaseFirestore.instance,
          FirebaseFunctions.instanceFor(region: kFunctionsRegion),
        )
      : null,
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

final endEventProvider = Provider<EndEvent>(
  (ref) => EndEvent(ref.watch(eventsRepositoryProvider)),
);

final deleteOwnEventProvider = Provider<DeleteOwnEvent>(
  (ref) => DeleteOwnEvent(ref.watch(eventsRepositoryProvider)),
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

/// Seção "Outros eventos" da aba Eventos — blocos de 10 documentos via
/// `startAfterDocument`, sem os eventos de que o usuário participa (que já
/// incluem os que ele criou: o Organizador também é Participante). Use
/// `loadMore()` ao aproximar do fim do scroll e
/// `ref.invalidate(paginatedEventsProvider)` para recarregar do zero
/// (pull-to-refresh, após criar evento etc.).
class PaginatedEventsController extends AsyncNotifier<List<Event>> {
  static const int pageSize = 10;

  /// Teto de páginas lidas numa carga só. O repositório tira os eventos
  /// encerrados (tarefa 14) e o [_fetchVisible] tira os do usuário, então
  /// uma página pode chegar vazia com mais páginas pela frente; sem buscar a
  /// próxima, a lista ficaria num spinner sem fim quando a tela não chega a
  /// rolar. O teto evita um laço de leituras se houver muitos seguidos.
  static const int maxPagesPerLoad = 5;

  Object? _cursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  EventsFilter _filter = const EventsFilter();
  String _uid = '';

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
    // Só o id, e pelo [currentUserSummaryProvider] (que resolve o modo
    // mock): editar o nome ou a foto não pode zerar a paginação.
    _uid = await ref
        .watch(currentUserSummaryProvider.selectAsync((user) => user.id));
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

  /// Busca a partir de [cursor] até vir algum evento de outra pessoa,
  /// acabarem as páginas ou bater [maxPagesPerLoad].
  ///
  /// Os eventos do usuário saem aqui, e não na tela, para uma página só com
  /// eventos dele contar como vazia e o laço buscar a próxima. O Firestore
  /// não faz esse filtro: não existe "array não contém", e um `!=` em
  /// `creator.id` obrigaria a ordenar por ele antes do `dateTime`.
  Future<PagedResult<Event>> _fetchVisible(
    EventsRepository repository, {
    required Object? cursor,
    required EventsFilter filter,
  }) async {
    bool isOthers(Event event) => !event.participantIds.contains(_uid);
    var page = await repository.fetchPage(
      cursor: cursor,
      pageSize: pageSize,
      filter: filter,
    );
    final items = <Event>[...page.items.where(isOthers)];
    for (var loaded = 1;
        items.isEmpty && page.hasMore && loaded < maxPagesPerLoad;
        loaded++) {
      page = await repository.fetchPage(
        cursor: page.cursor,
        pageSize: pageSize,
        filter: filter,
      );
      items.addAll(page.items.where(isOthers));
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

/// Seção "Participando" — o [joinedActiveEventsProvider] sem os eventos que
/// o usuário organiza (esses ficam só em "Criados por mim") e com o filtro
/// da folha aplicado no cliente.
///
/// O corte fica aqui, e não no [joinedActiveEventsProvider], porque ele
/// também alimenta o card ao vivo, que o Organizador precisa ver.
final joinedEventsProvider = Provider<AsyncValue<List<Event>>>((ref) {
  final filter = ref.watch(eventsFilterProvider);
  final uid =
      ref.watch(currentUserSummaryProvider.select((u) => u.valueOrNull?.id));
  return ref.watch(joinedActiveEventsProvider).whenData((events) => events
      .where((event) => event.creator.id != uid && filter.matches(event))
      .toList());
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

/// Recarrega as três seções da aba Eventos e os eventos da Home.
///
/// Sempre todas juntas: cada evento fica numa seção só, então criar ou
/// entrar num evento muda a seção dele ("Outros eventos" para "Criados por
/// mim" ou "Participando") e o card ao vivo. Invalidar só uma deixa o
/// evento sumido ou repetido. A Home entra porque lê os eventos uma vez só,
/// sem listener.
void invalidateEventLists(WidgetRef ref) {
  ref.invalidate(paginatedEventsProvider);
  ref.invalidate(myEventsProvider);
  ref.invalidate(joinedActiveEventsProvider);
  ref.invalidate(nearbyEventsProvider);
}

/// Detalhe de um evento por id, em tempo real (tarefa 14): um join ou um
/// encerramento aparece na tela sem invalidar nada.
///
/// `autoDispose`: sair da tela cancela o listener. Sem ele, cada evento
/// aberto seguia gerando uma leitura a cada inscrição até o app fechar;
/// reabrir o detalhe custa uma leitura só.
final eventDetailProvider =
    StreamProvider.autoDispose.family<Event?, String>((ref, id) {
  return ref.watch(watchEventDetailProvider).call(id);
});
