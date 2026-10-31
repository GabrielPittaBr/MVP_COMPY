import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compy_admin/features/places/data/admin_place_model.dart';
import 'package:compy_admin/features/places/data/admin_places_repository.dart';
import 'package:compy_admin/features/places/presentation/admin_place_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Contrato de formulário de Local Esportivo', () {
    test('valida e serializa schema completo sem dados fictícios', () {
      final fields = _validDraft().toFirestoreFields();
      final address = fields['address']! as Map<String, Object>;

      expect(fields['name'], 'Praça Central');
      expect(fields['nameLower'], 'praca central');
      expect(fields['sports'], <String>['corrida', 'futebol']);
      expect(fields['primarySport'], 'futebol');
      expect(fields['coordinates'], isA<GeoPoint>());
      expect(address['cityLower'], 'taquara');
      expect(address['postalCode'], '95600000');
      expect(address.containsKey('number'), isFalse);
      expect(fields.keys, isNot(contains('rating')));
      expect(fields.keys, isNot(contains('ratingsCount')));
      expect(fields.keys, isNot(contains('hasRatings')));
      expect(fields['accessType'], 'public');
      expect(fields.containsKey('contactPhone'), isFalse);
      expect(fields['images'], <Map<String, Object>>[
        <String, Object>{'url': 'https://example.com/place.jpg'},
      ]);
    });

    test('exige telefone com DDD somente para locais privados', () {
      final publicErrors = _validDraft(
        accessType: 'public',
        contactPhone: '',
      ).validate(requireAccessType: true);
      final privateValid = _validDraft(
        accessType: 'private',
        contactPhone: '(51) 99999-9999',
      );
      final privateMissing = _validDraft(
        accessType: 'private',
        contactPhone: '',
      ).validate(requireAccessType: true);

      expect(publicErrors, isEmpty);
      expect(privateValid.validate(requireAccessType: true), isEmpty);
      expect(privateValid.toFirestoreFields()['contactPhone'], '51999999999');
      expect(privateMissing['contactPhone'], contains('DDD'));
      expect(
        _validDraft(
          accessType: 'private',
          contactPhone: '(00) 1234-5678',
        ).validate()['contactPhone'],
        isNotNull,
      );
    });

    test('serializa fontes por foto e mantém cada fonte na sua imagem', () {
      final fields = _validDraft(
        images: const <AdminPlaceImage>[
          AdminPlaceImage(
            url: 'https://example.com/cover.jpg',
            source: 'Foto: Prefeitura de Taquara',
          ),
          AdminPlaceImage(
            url: 'https://example.com/court.jpg',
            source: 'Imagem via Google',
          ),
        ],
      ).toFirestoreFields();
      final images = fields['images']! as List<Map<String, Object>>;

      expect(fields['imageUrl'], 'https://example.com/cover.jpg');
      expect(images[0]['source'], 'Foto: Prefeitura de Taquara');
      expect(images[1]['source'], 'Imagem via Google');
    });

    test('limita a galeria a oito imagens', () {
      final images = List<AdminPlaceImage>.generate(
        9,
        (index) => AdminPlaceImage(url: 'https://example.com/$index.jpg'),
      );

      expect(_validDraft(images: images).validate()['images'], contains('8'));
    });

    test('rejeita modalidade principal não selecionada e CEP malformado', () {
      final errors = _validDraft(
        primarySport: 'volei',
        postalCode: '9560A-000',
      ).validate();

      expect(errors.keys, containsAll(<String>['primarySport', 'postalCode']));
    });

    test('valida UF, limites geográficos e HTTPS antes da escrita', () {
      final errors = _validDraft(
        state: 'XX',
        latitude: -91,
        longitude: 181,
        imageUrl: 'http://example.com/image.jpg',
      ).validate();

      expect(
        errors.keys,
        containsAll(<String>['state', 'latitude', 'longitude', 'imageUrl']),
      );
    });

    test('distância grande de Taquara gera aviso não bloqueante', () {
      final nearby = _validDraft();
      final far = _validDraft(latitude: -23.5505, longitude: -46.6333);

      expect(nearby.isFarFromTaquara, isFalse);
      expect(far.isFarFromTaquara, isTrue);
      expect(far.validate(), isEmpty);
    });
  });

  group('Edição administrativa de Local Esportivo', () {
    testWidgets(
      'conflito mantém valores digitados e oferece recarga explícita',
      (tester) async {
        final repository = _FakePlacesRepository(place: _record());
        addTearDown(repository.dispose);
        await _pumpEditor(tester, repository);

        final nameField = find.byKey(const ValueKey<String>('place-name'));
        await tester.ensureVisible(nameField);
        await tester.enterText(nameField, 'Nome digitado pelo admin');
        final save = find.widgetWithText(FilledButton, 'Salvar alterações');
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(repository.updateCalls, 1);
        expect(repository.lastExpectedUpdatedAt, _record().updatedAt);
        expect(repository.updatedDraft!.accessType, isNull);
        expect(
          repository.updatedDraft!.toFirestoreFields().containsKey(
            'accessType',
          ),
          isFalse,
        );
        expect(
          find.textContaining('alterado por outra pessoa'),
          findsOneWidget,
        );
        expect(
          tester.widget<TextFormField>(nameField).controller!.text,
          'Nome digitado pelo admin',
        );

        await tester.tap(find.text('Recarregar dados').first);
        await tester.pumpAndSettle();
        expect(repository.getPlaceCalls, 1);
        expect(
          tester.widget<TextFormField>(nameField).controller!.text,
          'Praça Central',
        );
      },
    );

    testWidgets('edição atualiza a fonte da foto existente', (tester) async {
      final repository = _FakePlacesRepository(
        place: _record(
          images: const <AdminPlaceImage>[
            AdminPlaceImage(
              url: 'https://example.com/place.jpg',
              source: 'Fonte antiga',
            ),
          ],
        ),
      )..succeedUpdates = true;
      addTearDown(repository.dispose);
      await _pumpEditor(tester, repository);

      final sourceField = find.byKey(
        const ValueKey<String>('place-imageSource-0'),
      );
      await tester.ensureVisible(sourceField);
      await tester.enterText(sourceField, 'Foto: Prefeitura de Taquara');
      final save = find.widgetWithText(FilledButton, 'Salvar alterações');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.updateCalls, 1);
      expect(
        repository.updatedDraft!.images.single.source,
        'Foto: Prefeitura de Taquara',
      );
      expect(find.text('Local atualizado com sucesso.'), findsOneWidget);
    });

    testWidgets('desativação exige confirmação e só confirma após servidor', (
      tester,
    ) async {
      final repository = _FakePlacesRepository(place: _record());
      addTearDown(repository.dispose);
      await _pumpEditor(tester, repository);

      final deactivate = find.widgetWithText(OutlinedButton, 'Desativar local');
      await tester.ensureVisible(deactivate);
      await tester.tap(deactivate);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('deixará de aparecer no mapa'),
        findsOneWidget,
      );
      expect(repository.statusCalls, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Desativar'));
      await tester.pumpAndSettle();
      expect(repository.statusCalls, 1);
      expect(repository.lastStatus, 'inactive');
      expect(find.text('Ativo'), findsOneWidget);
      expect(find.text('Local desativado.'), findsOneWidget);

      repository.latest = _record(status: 'inactive', updateSeconds: 101);
      repository.placeChanges.add(repository.latest);
      await tester.pumpAndSettle();
      expect(find.text('Inativo'), findsOneWidget);
    });

    testWidgets('formulário vazio mostra resumo e não chama o repositório', (
      tester,
    ) async {
      final repository = _FakePlacesRepository();
      addTearDown(repository.dispose);
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPlaceFormPage(
              repository: repository,
              mapPickerBuilder: _fakeMap,
            ),
          ),
        ),
      );
      final submit = find.widgetWithText(FilledButton, 'Cadastrar inativo');
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('Revise os campos destacados:'), findsOneWidget);
      expect(find.textContaining('entre 3 e 120 caracteres'), findsWidgets);
      expect(repository.createCalls, 0);
    });

    testWidgets('criação valida o formulário e segue para o novo ID', (
      tester,
    ) async {
      final repository = _FakePlacesRepository();
      addTearDown(repository.dispose);
      final router = await _pumpCreateForm(tester, repository);
      addTearDown(router.dispose);
      await _fillValidForm(tester);
      expect(find.byType(Image), findsOneWidget);

      final submit = find.widgetWithText(FilledButton, 'Cadastrar inativo');
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(
        repository.createdDraft?.toFirestoreFields()['nameLower'],
        'praca central',
      );
      expect(find.text('Criado: new-place'), findsOneWidget);
    });

    testWidgets('telefone aparece e é mascarado somente no local privado', (
      tester,
    ) async {
      final repository = _FakePlacesRepository();
      addTearDown(repository.dispose);
      final router = await _pumpCreateForm(tester, repository);
      addTearDown(router.dispose);
      await _fillValidForm(tester);

      expect(
        find.byKey(const ValueKey<String>('place-contactPhone')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey<String>('place-accessType')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Privado').last);
      await tester.pumpAndSettle();

      final phoneField = find.byKey(
        const ValueKey<String>('place-contactPhone'),
      );
      expect(phoneField, findsOneWidget);
      await tester.enterText(phoneField, '51999999999');
      expect(
        tester.widget<TextFormField>(phoneField).controller!.text,
        '(51) 99999-9999',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar inativo'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(
        repository.createdDraft!.toFirestoreFields()['contactPhone'],
        '51999999999',
      );
    });

    testWidgets('adiciona, remove e reorganiza imagens preservando as fontes', (
      tester,
    ) async {
      final repository = _FakePlacesRepository();
      addTearDown(repository.dispose);
      final router = await _pumpCreateForm(tester, repository);
      addTearDown(router.dispose);
      await _fillValidForm(tester);

      final addButton = find.text('Adicionar imagem (1/8)');
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('place-imageUrl-1')),
        'https://example.com/second.jpg',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('place-imageSource-1')),
        'Fonte da segunda foto',
      );
      await tester.pump();

      final secondAddButton = find.text('Adicionar imagem (2/8)');
      await tester.ensureVisible(secondAddButton);
      await tester.tap(secondAddButton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('place-imageUrl-2')),
        'https://example.com/temporary.jpg',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('place-imageSource-2')),
        'Fonte temporária',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('place-imageUrl-2')),
      );
      await tester.tap(find.byTooltip('Remover imagem').last);
      await tester.pumpAndSettle();

      final secondUrl = find.byKey(const ValueKey<String>('place-imageUrl-1'));
      await tester.ensureVisible(secondUrl);
      await tester.tap(find.byTooltip('Mover para cima').last);
      await tester.pumpAndSettle();

      final submit = find.widgetWithText(FilledButton, 'Cadastrar inativo');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      final fields = repository.createdDraft!.toFirestoreFields();
      final images = fields['images']! as List<Map<String, Object>>;
      expect(images, hasLength(2));
      expect(fields['imageUrl'], 'https://example.com/second.jpg');
      expect(images[0]['source'], 'Fonte da segunda foto');
      expect(images[1]['url'], 'https://example.com/place.jpg');
    });

    testWidgets(
      'falha de rede preserva os campos e comunica necessidade de reconectar',
      (tester) async {
        final repository = _FakePlacesRepository()
          ..createError = FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        addTearDown(repository.dispose);
        final router = await _pumpCreateForm(tester, repository);
        addTearDown(router.dispose);
        await _fillValidForm(tester);
        await tester.tap(
          find.widgetWithText(FilledButton, 'Cadastrar inativo'),
        );
        await tester.pumpAndSettle();

        expect(repository.createCalls, 1);
        expect(
          find.textContaining('Sem conexão com o servidor'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey<String>('place-name')),
              )
              .controller!
              .text,
          'Praça Central',
        );
      },
    );

    testWidgets('mapa atualiza as coordenadas e a prévia possui semântica', (
      tester,
    ) async {
      final repository = _FakePlacesRepository();
      addTearDown(repository.dispose);
      await _pumpCreateForm(tester, repository);
      final semantics = tester.ensureSemantics();

      expect(
        find.bySemanticsLabel('Prévia da imagem do Local Esportivo'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('UF brasileira'), findsOneWidget);
      expect(find.bySemanticsLabel('Latitude'), findsOneWidget);
      await tester.tap(find.textContaining('Selecionar no mapa'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey<String>('place-latitude')),
            )
            .controller!
            .text,
        '-29.700000',
      );
      expect(find.textContaining('50 km de Taquara'), findsNothing);
      semantics.dispose();
    });

    testWidgets('saída com alterações não salvas pede confirmação', (
      tester,
    ) async {
      final repository = _FakePlacesRepository(place: _record());
      addTearDown(repository.dispose);
      await _pumpEditor(tester, repository);
      final nameField = find.byKey(const ValueKey<String>('place-name'));
      await tester.enterText(nameField, 'Nome ainda não salvo');
      await tester.pump();
      expect(
        tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>)).canPop,
        isFalse,
      );
      final cancel = find.text('Cancelar');
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();

      expect(find.text('Descartar alterações?'), findsOneWidget);
      await tester.tap(find.text('Continuar editando'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(nameField).controller!.text,
        'Nome ainda não salvo',
      );
    });
  });
}

AdminPlaceDraft _validDraft({
  String state = 'RS',
  String postalCode = '95600-000',
  List<String> sports = const <String>['corrida', 'futebol'],
  String? primarySport = 'futebol',
  double? latitude = -29.6562,
  double? longitude = -50.7877,
  String imageUrl = 'https://example.com/place.jpg',
  String? accessType = 'public',
  String contactPhone = '',
  List<AdminPlaceImage> images = const <AdminPlaceImage>[],
}) => AdminPlaceDraft(
  name: ' Praça Central ',
  description: 'Espaço público para atividades esportivas e convivência.',
  street: 'Rua Principal',
  number: '',
  complement: '',
  neighborhood: 'Centro',
  city: 'Taquara',
  state: state,
  postalCode: postalCode,
  sports: sports,
  primarySport: primarySport,
  latitude: latitude,
  longitude: longitude,
  imageUrl: imageUrl,
  accessType: accessType,
  contactPhone: contactPhone,
  images: images,
);

AdminPlaceRecord _record({
  String status = 'active',
  int updateSeconds = 100,
  List<AdminPlaceImage> images = const <AdminPlaceImage>[],
}) => AdminPlaceRecord(
  id: 'place-1',
  name: 'Praça Central',
  nameLower: 'praca central',
  description: 'Espaço público para atividades esportivas e convivência.',
  address: const AdminPlaceAddress(
    street: 'Rua Principal',
    number: '12',
    city: 'Taquara',
    cityLower: 'taquara',
    state: 'RS',
    postalCode: '95600000',
  ),
  sports: const <String>['corrida', 'futebol'],
  primarySport: 'futebol',
  coordinates: GeoPoint(-29.6562, -50.7877),
  imageUrl: 'https://example.com/place.jpg',
  images: images,
  status: status,
  createdAt: Timestamp(50, 0),
  updatedAt: Timestamp(updateSeconds, 0),
  isFromCache: false,
);

Widget _fakeMap(
  BuildContext context,
  LatLng point,
  ValueChanged<LatLng> onSelected,
) => SizedBox(
  height: 180,
  child: TextButton(
    onPressed: () => onSelected(const LatLng(-29.7, -50.9)),
    child: Text('Selecionar no mapa (${point.latitude})'),
  ),
);

Future<GoRouter> _pumpCreateForm(
  WidgetTester tester,
  _FakePlacesRepository repository,
) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(
    initialLocation: '/places/new',
    routes: <RouteBase>[
      GoRoute(
        path: '/places/new',
        builder: (context, state) => Scaffold(
          body: AdminPlaceFormPage(
            repository: repository,
            mapPickerBuilder: _fakeMap,
          ),
        ),
      ),
      GoRoute(
        path: '/places/:id',
        builder: (context, state) =>
            Scaffold(body: Text('Criado: ${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('place-name')),
    'Praça Central',
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('place-description')),
    'Espaço público para atividades esportivas e convivência.',
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('place-street')),
    'Rua Principal',
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('place-city')),
    'Taquara',
  );
  await tester.tap(find.widgetWithText(FilterChip, 'Futebol'));
  await tester.enterText(
    find.byKey(const ValueKey<String>('place-imageUrl')),
    'https://example.com/place.jpg',
  );
  await tester.pump();
}

Future<void> _pumpEditor(
  WidgetTester tester,
  _FakePlacesRepository repository,
) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(
    initialLocation: '/places/place-1',
    routes: <RouteBase>[
      GoRoute(
        path: '/places/:id',
        builder: (context, state) => Scaffold(
          body: AdminPlaceFormPage(
            repository: repository,
            placeId: state.pathParameters['id'],
            mapPickerBuilder: _fakeMap,
          ),
        ),
      ),
      GoRoute(
        path: '/places',
        builder: (context, state) =>
            const Scaffold(body: Text('Lista de locais')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  repository.placeChanges.add(repository.latest);
  await tester.pumpAndSettle();
}

class _FakePlacesRepository implements AdminPlacesRepository {
  _FakePlacesRepository({AdminPlaceRecord? place}) : latest = place;

  final StreamController<AdminPlaceRecord?> placeChanges =
      StreamController<AdminPlaceRecord?>.broadcast();
  AdminPlaceRecord? latest;
  int createCalls = 0;
  int updateCalls = 0;
  int statusCalls = 0;
  int getPlaceCalls = 0;
  Timestamp? lastExpectedUpdatedAt;
  String? lastStatus;
  AdminPlaceDraft? createdDraft;
  AdminPlaceDraft? updatedDraft;
  bool succeedUpdates = false;
  Object? createError;

  @override
  Stream<AdminPlacesPageSnapshot> watchPage(
    AdminPlacesFilters filters, {
    AdminPlaceCursor? after,
  }) => const Stream<AdminPlacesPageSnapshot>.empty();

  @override
  Stream<AdminPlacesCollectionSnapshot> watchAll(AdminPlacesFilters filters) =>
      const Stream<AdminPlacesCollectionSnapshot>.empty();

  @override
  Stream<AdminPlaceRecord?> watchPlace(String id) => placeChanges.stream;

  @override
  Future<AdminPlaceRecord?> getPlace(String id) async {
    getPlaceCalls++;
    return latest;
  }

  @override
  Future<String> createPlace(AdminPlaceDraft draft) async {
    createCalls++;
    createdDraft = draft;
    if (createError case final error?) throw error;
    return 'new-place';
  }

  @override
  Future<void> updatePlace(
    String id,
    AdminPlaceDraft draft, {
    required Timestamp expectedUpdatedAt,
  }) async {
    updateCalls++;
    lastExpectedUpdatedAt = expectedUpdatedAt;
    updatedDraft = draft;
    if (!succeedUpdates) {
      throw const AdminPlaceOperationError(
        AdminPlaceOperationErrorCode.conflict,
      );
    }
  }

  @override
  Future<void> setPlaceStatus(
    String id,
    String status, {
    required Timestamp expectedUpdatedAt,
  }) async {
    statusCalls++;
    lastStatus = status;
    lastExpectedUpdatedAt = expectedUpdatedAt;
  }

  Future<void> dispose() => placeChanges.close();
}
