import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/providers/clock_providers.dart';
import 'package:mvp_compy/features/auth/domain/entities/auth_user.dart';
import 'package:mvp_compy/features/auth/presentation/providers/auth_providers.dart';
import 'package:mvp_compy/features/events/domain/repositories/events_repository.dart';
import 'package:mvp_compy/features/events/domain/usecases/create_event.dart';
import 'package:mvp_compy/features/events/presentation/pages/create_event_page.dart';
import 'package:mvp_compy/features/events/presentation/providers/events_providers.dart';
import 'package:mvp_compy/features/maps/domain/repositories/places_repository.dart';
import 'package:mvp_compy/features/maps/presentation/providers/maps_providers.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/sport_place.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';
import 'package:latlong2/latlong.dart';

const _address = PlaceAddress(
  street: 'Rua Central',
  city: 'Taquara',
  cityLower: 'taquara',
  state: 'RS',
);

const _place = SportPlace(
  id: 'place-1',
  name: 'Quadra Central',
  nameLower: 'quadra central',
  description: 'Espaço esportivo comunitário para atividades locais.',
  address: _address,
  coordinates: LatLng(-29.65, -50.78),
  sports: <Sport>[Sport.futebol],
  primarySport: Sport.futebol,
  status: PlaceStatus.active,
  imageUrl: 'https://example.com/place.jpg',
);

const _authUser = AuthUser(
  uid: 'uid-1',
  email: 'user@example.com',
  displayName: 'Usuário',
  hasUsername: true,
  hasFavoriteSports: true,
);

const _summary = UserSummary(
  id: 'uid-1',
  name: 'Usuário',
  handle: '@usuario',
  avatarUrl: '',
);

class _OfflineEventsRepository implements EventsRepository {
  bool createCalled = false;

  @override
  Future<Event> createEvent(
    Event draft, {
    required SportPlace selectedPlace,
  }) async {
    createCalled = true;
    throw const EventCreationOfflineException();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _field(String hint) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == hint,
    );

/// Instante fixo do relógio: os seletores de data e horário abrem nele, e
/// é contra ele que o formulário decide se o início já passou.
final _agora = DateTime(2026, 10, 21, 9);

/// Preenche o formulário inteiro aceitando a data e o horário sugeridos
/// pelos seletores, que vêm do relógio.
Future<void> _preencher(WidgetTester tester) async {
  await tester.enterText(
      _field('Título (ex.: Pelada de quinta, Vôlei descontraído)'),
      'Meu evento');
  await tester.ensureVisible(_field('Selecionar local'));
  await tester.tap(_field('Selecionar local'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Quadra Central').last);
  await tester.pumpAndSettle();

  await tester.ensureVisible(_field('Selecionar esporte'));
  await tester.tap(_field('Selecionar esporte'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Futebol').last);
  await tester.pumpAndSettle();

  await tester.ensureVisible(_field('Data'));
  await tester.tap(_field('Data'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK').last);
  await tester.pumpAndSettle();

  await tester.ensureVisible(_field('Horário'));
  await tester.tap(_field('Horário'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK').last);
  await tester.pumpAndSettle();

  await tester.ensureVisible(_field('Nível de habilidade'));
  await tester.tap(_field('Nível de habilidade'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Todos').last);
  await tester.pumpAndSettle();

  await tester.ensureVisible(_field('Número de participantes'));
  await tester.enterText(_field('Número de participantes'), '4');
  await tester.pump();
}

List<Override> _overrides(DateTime Function() clock, EventsRepository repo) =>
    <Override>[
      clockProvider.overrideWithValue(clock),
      authStateProvider.overrideWith((ref) => Stream.value(_authUser)),
      currentUserSummaryProvider.overrideWith((ref) async => _summary),
      placesProvider.overrideWith(
        (ref) => Stream<PlacesStreamResult>.value(
          const PlacesStreamResult(
            places: <SportPlace>[_place],
            isFromCache: true,
          ),
        ),
      ),
      createEventProvider.overrideWithValue(CreateEvent(repo)),
    ];

void main() {
  testWidgets('offline preserva os valores do formulário e do local',
      (tester) async {
    final offlineRepository = _OfflineEventsRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(() => _agora, offlineRepository),
      child: const MaterialApp(home: CreateEventPage()),
    ));
    await tester.pumpAndSettle();

    // Data e horário sugeridos são o próprio "agora": começar no minuto
    // atual vale.
    await _preencher(tester);
    for (final hint in <String>[
      'Selecionar local',
      'Selecionar esporte',
      'Data',
      'Horário',
      'Nível de habilidade',
      'Número de participantes',
    ]) {
      // Keep each prerequisite explicit so a picker interaction regression
      // fails at the field that did not update, rather than as a disabled CTA.
      expect(
        tester.widget<TextField>(_field(hint).first).controller!.text,
        isNotEmpty,
        reason: '$hint precisa estar preenchido antes do envio',
      );
    }
    final submitButton = find.widgetWithText(FilledButton, 'Criar evento');
    await tester.ensureVisible(submitButton);
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNotNull);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(offlineRepository.createCalled, isTrue);
    expect(find.textContaining('Reconecte-se para criar o evento.'),
        findsOneWidget);
    expect(
        tester
            .widget<TextField>(
                _field('Título (ex.: Pelada de quinta, Vôlei descontraído)')
                    .first)
            .controller!
            .text,
        'Meu evento');
    expect(
        tester
            .widget<TextField>(_field('Selecionar local').first)
            .controller!
            .text,
        'Quadra Central — Taquara');
  });

  testWidgets('horário que já passou hoje mostra o aviso e bloqueia o envio',
      (tester) async {
    final repository = _OfflineEventsRepository();
    var agora = _agora;
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(() => agora, repository),
      child: const MaterialApp(home: CreateEventPage()),
    ));
    await tester.pumpAndSettle();

    await _preencher(tester);
    expect(find.text(AppStrings.eventStartInPast), findsNothing);

    // O relógio anda enquanto o formulário fica aberto: o horário escolhido
    // (09:00 de hoje) passa a estar no passado.
    agora = _agora.add(const Duration(minutes: 5));
    await tester.enterText(_field('Número de participantes'), '5');
    await tester.pump();

    expect(find.text(AppStrings.eventStartInPast), findsOneWidget);
    final submitButton = find.widgetWithText(FilledButton, 'Criar evento');
    await tester.ensureVisible(submitButton);
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNull);
    expect(repository.createCalled, isFalse);
  });

  testWidgets('desativação invalida somente local e modalidade selecionados',
      (tester) async {
    final snapshots = StreamController<PlacesStreamResult>();
    addTearDown(snapshots.close);
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        placesProvider.overrideWith((ref) => snapshots.stream),
      ],
      child: const MaterialApp(home: CreateEventPage()),
    ));
    snapshots.add(const PlacesStreamResult(
      places: <SportPlace>[_place],
      isFromCache: false,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        _field('Título (ex.: Pelada de quinta, Vôlei descontraído)'),
        'Meu evento');
    await tester.tap(_field('Selecionar local'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quadra Central').last);
    await tester.pumpAndSettle();
    await tester.tap(_field('Selecionar esporte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Futebol').last);
    await tester.pumpAndSettle();

    snapshots.add(const PlacesStreamResult(
      places: <SportPlace>[],
      isFromCache: false,
    ));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<TextField>(
                _field('Título (ex.: Pelada de quinta, Vôlei descontraído)')
                    .first)
            .controller!
            .text,
        'Meu evento');
    expect(
        tester
            .widget<TextField>(_field('Selecionar local').first)
            .controller!
            .text,
        isEmpty);
    expect(
        tester
            .widget<TextField>(_field('Selecionar esporte').first)
            .controller!
            .text,
        isEmpty);
    expect(find.textContaining('O local foi desativado'), findsOneWidget);
  });
}
