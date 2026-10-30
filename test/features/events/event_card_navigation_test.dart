import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/providers/clock_providers.dart';
import 'package:mvp_compy/core/routes/app_router.dart';
import 'package:mvp_compy/features/events/domain/entities/events_filter.dart';
import 'package:mvp_compy/features/events/domain/repositories/events_repository.dart';
import 'package:mvp_compy/features/events/presentation/pages/events_list_page.dart';
import 'package:mvp_compy/features/events/presentation/pages/search_page.dart';
import 'package:mvp_compy/features/events/presentation/providers/events_providers.dart';
import 'package:mvp_compy/features/events/presentation/providers/search_providers.dart';
import 'package:mvp_compy/features/home/presentation/pages/home_page.dart';
import 'package:mvp_compy/features/home/presentation/providers/home_providers.dart';
import 'package:mvp_compy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/paged_result.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';
import 'package:mvp_compy/shared/widgets/event_card.dart';

const _user =
    UserSummary(id: 'uid', name: 'Ana', handle: '@ana', avatarUrl: '');
final _now = DateTime(2026, 10, 29);
const _filter = EventsFilter(sport: Sport.basquete);

Event _event(int index, {int spots = 4}) => Event(
      id: 'uid-evento-$index',
      title: 'Treino $index',
      sport: Sport.basquete,
      location: 'Taquara',
      coordinates: const LatLng(-29.65, -50.78),
      dateTime: DateTime(2026, 10, 31, 15),
      durationMinutes: 90,
      skillLevel: SkillLevel.todos,
      totalSpots: 10,
      remainingSpots: spots,
      bannerUrl: '',
      creator: _user,
    );

class _Events implements EventsRepository {
  _Events(this.items, {this.personal = const []});
  final List<Event> items;
  final List<Event> personal;
  final cursors = <Object?>[];
  final filters = <EventsFilter>[];
  int joins = 0;

  @override
  Future<PagedResult<Event>> fetchPage(
      {Object? cursor,
      int pageSize = 10,
      EventsFilter filter = const EventsFilter()}) async {
    cursors.add(cursor);
    filters.add(filter);
    final start = (cursor as int?) ?? 0;
    final matching = items.where(filter.matches).toList();
    final page = matching.skip(start).take(pageSize).toList();
    final end = start + page.length;
    return PagedResult(
        items: page, cursor: end, hasMore: end < matching.length);
  }

  @override
  Future<List<Event>> fetchCreatedBy(String uid,
          {EventsFilter filter = const EventsFilter()}) async =>
      personal;
  @override
  Stream<List<Event>> watchJoinedActive(String uid) => Stream.value([]);
  @override
  Future<Event> joinEvent(String eventId, UserSummary user) async {
    joins++;
    throw StateError('Navegação não deve inscrever');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(GoRouter, ProviderContainer, List<String>)> _open(
  WidgetTester tester,
  String path,
  _Events events, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // A saudação usa CircleAvatar de rede. Ignorar somente a falha de imagem
  // do ambiente de widgets mantém erros de gesto/layout visíveis.
  final previousError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.library == 'image resource service') return;
    previousError?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousError);
  final container = ProviderContainer(overrides: [
    clockProvider.overrideWithValue(() => _now),
    nowProvider.overrideWith((ref) => Stream.value(_now)),
    currentUserSummaryProvider.overrideWith((ref) async => _user),
    greetingNameProvider.overrideWithValue(_user.name),
    categoriesProvider.overrideWithValue([]),
    unreadNotificationsCountProvider.overrideWithValue(0),
    nearbyEventsProvider.overrideWith((ref) => Stream.value(events.items)),
    eventsRepositoryProvider.overrideWithValue(events),
    eventsFilterProvider.overrideWith((ref) => _filter),
    searchQueryProvider.overrideWith((ref) => 'Treino'),
    searchResultsProvider.overrideWith((ref) async => events.items),
  ]);
  addTearDown(container.dispose);
  final opened = <String>[];
  final router = GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(path: AppRoutes.home, builder: (_, __) => const HomePage()),
        GoRoute(
            path: AppRoutes.events, builder: (_, __) => const EventsListPage()),
        GoRoute(path: AppRoutes.search, builder: (_, __) => const SearchPage()),
        GoRoute(
            path: AppRoutes.eventDetail,
            builder: (_, state) =>
                Scaffold(body: Text('detalhes ${state.pathParameters['id']}'))),
      ],
      redirect: (_, state) {
        final id = state.pathParameters['id'];
        if (id != null) opened.add(id);
        return null;
      });
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // O footer da paginação mantém um spinner enquanto há outra página.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }
  return (router, container, opened);
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  for (final path in [AppRoutes.home, AppRoutes.events, AppRoutes.search]) {
    testWidgets(
        '$path: calendário independente, corpo e CTA usam detalhes por UID',
        (tester) async {
      final event = _event(1);
      final events = _Events([event]);
      final (router, container, opened) = await _open(tester, path, events);
      await tester.ensureVisible(find.byType(EventCard));
      await tester.pumpAndSettle();
      final requestsBefore = events.cursors.length;
      final calendar = find.descendant(
          of: find.byType(EventCard),
          matching: find.byTooltip(AppStrings.eventDateTimeTitle));
      await tester.tap(calendar);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Término previsto: 16:30'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(opened, isEmpty);
      expect(events.joins, 0);
      expect(container.read(eventsFilterProvider), _filter);
      expect(events.cursors.length, requestsBefore);
      await tester.tap(find.byTooltip(AppStrings.commonClose));
      await tester.pumpAndSettle();
      await tester.tap(find.text(event.title));
      await tester.pumpAndSettle();
      expect(find.text('detalhes ${event.id}'), findsOneWidget);
      expect(opened, [event.id]);
      expect(events.joins, 0);
      router.go(path);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(EventCard));
      await tester.pumpAndSettle();
      final cta = find.descendant(
          of: find.byType(EventCard), matching: find.byType(TextButton));
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(opened, [event.id, event.id]);
      expect(events.joins, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'aba Eventos preserva paginação e filtro após consultar calendário',
      (tester) async {
    final events = _Events([for (var i = 0; i < 12; i++) _event(i)]);
    final (_, container, opened) =
        await _open(tester, AppRoutes.events, events, settle: false);
    expect(container.read(paginatedEventsProvider).valueOrNull, hasLength(10));
    await tester.tap(find.byTooltip(AppStrings.eventDateTimeTitle).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byTooltip(AppStrings.commonClose));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2400));
    await tester.pumpAndSettle();
    expect(container.read(paginatedEventsProvider).valueOrNull, hasLength(12));
    expect(events.cursors, [null, 10]);
    expect(events.filters, [_filter, _filter]);
    expect(opened, isEmpty);
    expect(events.joins, 0);
  });

  testWidgets('evento pessoal lotado mantém Ver mais habilitado na aba Eventos',
      (tester) async {
    final full = _event(1, spots: 0);
    final events = _Events([], personal: [full]);
    final (_, _, opened) = await _open(tester, AppRoutes.events, events);
    final cta = tester.widget<TextButton>(find.descendant(
        of: find.byType(EventCard), matching: find.byType(TextButton)));
    expect(cta.onPressed, isNotNull);
    await tester.tap(find.text(AppStrings.eventSeeMore));
    await tester.pumpAndSettle();
    expect(opened, [full.id]);
    expect(events.joins, 0);
  });
}
