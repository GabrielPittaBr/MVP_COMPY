import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/providers/clock_providers.dart';
import 'package:mvp_compy/features/events/domain/repositories/events_repository.dart';
import 'package:mvp_compy/features/events/presentation/providers/events_providers.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/features/ratings/domain/entities/event_rating_submission.dart';
import 'package:mvp_compy/features/ratings/domain/entities/rating_draft.dart';
import 'package:mvp_compy/features/ratings/domain/repositories/ratings_repository.dart';
import 'package:mvp_compy/features/ratings/presentation/pages/event_rating_page.dart';
import 'package:mvp_compy/features/ratings/presentation/providers/ratings_providers.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/event_place_snapshot.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/sport_place.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

final _agora = DateTime(2026, 10, 21, 22);

const _dono = UserSummary(
  id: 'u_dono',
  name: 'Ana Souza',
  handle: '@anasouza',
  avatarUrl: '',
);
const _participante = UserSummary(
  id: 'u_participante',
  name: 'Bruno Lima',
  handle: '@brunolima',
  avatarUrl: '',
);

const _local = EventPlaceSnapshot(
  name: 'Parque do Trabalhador',
  address: PlaceAddress(
    street: 'Rua Central',
    city: 'Taquara',
    cityLower: 'taquara',
    state: 'RS',
  ),
  coordinates: LatLng(-29.65, -50.78),
);

Event _encerrado({bool comLocal = true}) => Event(
      id: 'evt_fim',
      title: 'Rachão',
      sport: Sport.basquete,
      location: 'Parque do Trabalhador, Taquara',
      coordinates: const LatLng(-29.65, -50.78),
      dateTime: _agora.subtract(const Duration(hours: 2)),
      durationMinutes: 60,
      skillLevel: SkillLevel.todos,
      totalSpots: 10,
      remainingSpots: 8,
      bannerUrl: '',
      creator: _dono,
      participants: const <UserSummary>[_dono, _participante],
      placeId: comLocal ? 'place_1' : null,
      placeSnapshot: comLocal ? _local : null,
      endedAt: _agora.subtract(const Duration(minutes: 50)),
    );

class _Eventos implements EventsRepository {
  _Eventos(this.evento);
  final Event evento;

  @override
  Stream<Event?> watchById(String id) => Stream<Event?>.value(evento);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Avaliacoes implements RatingsRepository {
  _Avaliacoes({this.erro});

  final Object? erro;
  final List<EventRatingSubmission> enviadas = <EventRatingSubmission>[];

  @override
  Future<void> submit(EventRatingSubmission submission) async {
    if (erro != null) throw erro!;
    enviadas.add(submission);
  }
}

Future<void> _abrir(
  WidgetTester tester, {
  required UserSummary quem,
  Event? evento,
  _Avaliacoes? avaliacoes,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: '/inicio',
    routes: <RouteBase>[
      GoRoute(
        path: '/inicio',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/avaliacao/evt_fim'),
            child: const Text('abrir avaliação'),
          ),
        ),
      ),
      GoRoute(
        path: '/events/:id',
        builder: (_, __) => const Scaffold(body: Text('detalhe do evento')),
      ),
      GoRoute(
        path: '/avaliacao/:eventId',
        builder: (_, state) =>
            EventRatingPage(eventId: state.pathParameters['eventId']!),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      clockProvider.overrideWithValue(() => _agora),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(_agora)),
      currentUserSummaryProvider.overrideWith((ref) async => quem),
      eventsRepositoryProvider
          .overrideWithValue(_Eventos(evento ?? _encerrado())),
      ratingsRepositoryProvider.overrideWithValue(avaliacoes ?? _Avaliacoes()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('abrir avaliação'));
  await tester.pumpAndSettle();
}

Finder _botao(String label) => find.widgetWithText(FilledButton, label);

bool _ativo(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(_botao(label)).onPressed != null;

TextField _comentario(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

Future<void> _estrelas(WidgetTester tester, int n) async {
  await tester.tap(find.byKey(ValueKey<String>('star-$n')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('o participante avalia o evento e o local e envia',
      (tester) async {
    final avaliacoes = _Avaliacoes();
    await _abrir(tester, quem: _participante, avaliacoes: avaliacoes);

    expect(find.text(AppStrings.ratingStep(1, 2)), findsOneWidget);
    expect(find.text(AppStrings.ratingEventQuestion), findsOneWidget);
    // Sem estrelas: não avança e o comentário fica travado.
    expect(_ativo(tester, AppStrings.ratingContinue), isFalse);
    expect(_comentario(tester).enabled, isFalse);
    expect(find.text(AppStrings.ratingCommentLocked), findsOneWidget);

    // Nota baixa: o comentário destrava e vira obrigatório.
    await _estrelas(tester, 2);
    expect(find.text('Ruim'), findsOneWidget);
    expect(_comentario(tester).enabled, isTrue);
    expect(find.text(AppStrings.ratingCommentReasonHint), findsOneWidget);
    expect(find.text(AppStrings.ratingReasonRequired), findsOneWidget);
    expect(_ativo(tester, AppStrings.ratingContinue), isFalse);

    await tester.enterText(find.byType(TextField), 'Começou bem atrasado');
    await tester.pump();
    expect(find.text(AppStrings.ratingReasonRequired), findsNothing);
    expect(_ativo(tester, AppStrings.ratingContinue), isTrue);

    await tester.tap(_botao(AppStrings.ratingContinue));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.ratingStep(2, 2)), findsOneWidget);
    expect(find.text(AppStrings.ratingPlaceQuestion), findsOneWidget);
    expect(_ativo(tester, AppStrings.ratingSubmit), isFalse);

    await _estrelas(tester, 4);
    await tester.tap(_botao(AppStrings.ratingSubmit));
    await tester.pumpAndSettle();

    expect(avaliacoes.enviadas, <EventRatingSubmission>[
      const EventRatingSubmission(
        eventId: 'evt_fim',
        raterId: 'u_participante',
        event: RatingDraft(stars: 2, comment: 'Começou bem atrasado'),
        place: RatingDraft(stars: 4),
      ),
    ]);
    expect(find.text(AppStrings.ratingSent), findsOneWidget);

    await tester.tap(_botao(AppStrings.ratingBack));
    await tester.pumpAndSettle();
    expect(find.text('detalhe do evento'), findsOneWidget);
  });

  testWidgets('o criador não tem o passo do evento (D14)', (tester) async {
    await _abrir(tester, quem: _dono);

    expect(find.text(AppStrings.ratingStep(1, 1)), findsOneWidget);
    expect(find.text(AppStrings.ratingPlaceQuestion), findsOneWidget);
    expect(find.text(AppStrings.ratingEventQuestion), findsNothing);
  });

  testWidgets('evento legado sem local pula o passo do local', (tester) async {
    await _abrir(tester,
        quem: _participante, evento: _encerrado(comLocal: false));

    expect(find.text(AppStrings.ratingStep(1, 1)), findsOneWidget);
    expect(find.text(AppStrings.ratingEventQuestion), findsOneWidget);
    expect(find.text(AppStrings.ratingSubmit), findsOneWidget);
  });

  testWidgets('fechar com algo preenchido pede confirmação', (tester) async {
    await _abrir(tester, quem: _participante);
    await _estrelas(tester, 5);

    await tester.tap(find.byTooltip(AppStrings.ratingClose));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.ratingExitTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.commonCancel));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.ratingEventQuestion), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.ratingClose));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.ratingExitConfirm));
    await tester.pumpAndSettle();
    expect(find.text('abrir avaliação'), findsOneWidget);
  });

  testWidgets('fechar sem nada preenchido sai direto', (tester) async {
    await _abrir(tester, quem: _participante);

    await tester.tap(find.byTooltip(AppStrings.ratingClose));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.ratingExitTitle), findsNothing);
    expect(find.text('abrir avaliação'), findsOneWidget);
  });

  testWidgets('quem já avaliou recebe o aviso e o fluxo fecha', (tester) async {
    await _abrir(
      tester,
      quem: _participante,
      evento: _encerrado(comLocal: false),
      avaliacoes: _Avaliacoes(erro: const RatingAlreadySubmittedException()),
    );
    await _estrelas(tester, 5);
    await tester.tap(_botao(AppStrings.ratingSubmit));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.ratingErrorAlreadyRated), findsOneWidget);
    expect(find.text('abrir avaliação'), findsOneWidget);
  });

  testWidgets('sem conexão, o erro aparece e dá para tentar de novo',
      (tester) async {
    await _abrir(
      tester,
      quem: _participante,
      evento: _encerrado(comLocal: false),
      avaliacoes: _Avaliacoes(erro: const RatingOfflineException()),
    );
    await _estrelas(tester, 5);
    await tester.tap(_botao(AppStrings.ratingSubmit));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.ratingErrorOffline), findsOneWidget);
    expect(_ativo(tester, AppStrings.ratingSubmit), isTrue);
  });
}
