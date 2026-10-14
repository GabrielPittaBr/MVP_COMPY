import 'dart:async';

import 'package:compy_admin/features/users/data/admin_users_repository.dart';
import 'package:compy_admin/features/users/presentation/admin_users_controller.dart';
import 'package:compy_admin/features/users/presentation/admin_users_pages.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('contratos de pesquisa de Usuário', () {
    test('normaliza prefixo de Nome e converte Handle para @prefixo', () {
      final name = AdminUsersQueryPlan.fromSearch(
        AdminUserSearchType.name,
        '  JÚLIA  ',
      );
      final handle = AdminUsersQueryPlan.fromSearch(
        AdminUserSearchType.handle,
        '  @MaRiA  ',
      );

      expect(name.field, 'nameLower');
      expect(name.prefix, 'julia');
      expect(handle.field, 'handle');
      expect(handle.prefix, '@maria');
      expect(AdminUsersQueryPlan.pageSize, 20);
      expect(
        () => AdminUsersQueryPlan.fromSearch(AdminUserSearchType.uid, 'abc'),
        throwsArgumentError,
      );
    });

    test('mapeia somente campos públicos do perfil e whitelist Auth', () {
      final profile = AdminUserProfile.fromDocument('uid-1', <String, dynamic>{
        'id': 'forged-id',
        'name': 'Júlia',
        'handle': '@julia',
        'avatarUrl': 'https://example.test/avatar.png',
        'favoriteSports': <String>['corrida', 'corrida', 'futebol'],
        'email': 'must-not-be-profile-data@example.test',
        'private': <String, Object?>{'phone': 'private'},
        'passwordHash': 'never-model-this',
      });
      final auth = AdminUserAuthDetails.fromCallable(<String, Object?>{
        'uid': 'uid-1',
        'email': 'julia@example.test',
        'emailVerified': true,
        'providerIds': <String>['password'],
        'createdAt': '2026-01-02T03:04:05.000Z',
        'lastSignInAt': null,
        'disabled': false,
        'passwordHash': 'never-model-this',
        'refreshTokens': <String>['secret'],
      });

      expect(profile.uid, 'uid-1');
      expect(profile.favoriteSports, <String>['corrida', 'futebol']);
      expect(auth.email, 'julia@example.test');
      expect(auth.providerIds, <String>['password']);
      expect(auth.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(auth.disabled, isFalse);
    });

    test('Callables usam endpoints e payloads exatos aprovados', () async {
      final calls = <(String, Map<String, Object?>)>[];
      final client = AdminUsersCallableClient(
        invoker: (name, payload) async {
          calls.add((name, Map<String, Object?>.from(payload)));
          return const <String, Object?>{'items': <Object?>[]};
        },
      );

      await client.getAdminUserAuthDetails(uid: 'uid-1');
      await client.getAdminUserAuthDetails(email: ' PERSON@EXAMPLE.TEST ');
      await client.getAdminUsersAuthStatus(<String>['uid-1', 'uid-2']);

      expect(calls.map((call) => call.$1), <String>[
        'getAdminUserAuthDetails',
        'getAdminUserAuthDetails',
        'getAdminUsersAuthStatus',
      ]);
      expect(calls[0].$2, <String, Object?>{'uid': 'uid-1'});
      expect(calls[1].$2, <String, Object?>{'email': 'person@example.test'});
      expect(calls[2].$2, <String, Object?>{
        'uids': <String>['uid-1', 'uid-2'],
      });
      expect(
        () => client.getAdminUserAuthDetails(uid: 'uid-1', email: 'a@b.test'),
        throwsArgumentError,
      );
    });

    test('suspensão envia somente o contrato idempotente aprovado', () async {
      final calls = <(String, Map<String, Object?>)>[];
      final client = AdminUsersCallableClient(
        invoker: (name, payload) async {
          calls.add((name, Map<String, Object?>.from(payload)));
          return <String, Object?>{
            'uid': 'target-uid',
            'disabled': true,
            'action': 'suspend',
            'completedAt': '2026-10-03T12:00:00.000Z',
          };
        },
      );

      final result = await client.setUserSuspension(
        uid: 'target-uid',
        action: AdminUserSuspensionAction.suspend,
        reason: '  Violação   das regras da comunidade  ',
        operationId: 'a04988af-ccba-4c4e-a0d2-df5c56be31d6',
      );

      expect(calls.single.$1, 'setUserSuspension');
      expect(calls.single.$2, <String, Object?>{
        'uid': 'target-uid',
        'action': 'suspend',
        'reason': 'Violação das regras da comunidade',
        'operationId': 'a04988af-ccba-4c4e-a0d2-df5c56be31d6',
      });
      expect(result.disabled, isTrue);
      expect(result.completedAt, DateTime.utc(2026, 10, 3, 12));
    });
  });

  group('AdminUsersController', () {
    test(
      'pagina com cursor e preserva cada estado Auth, inclusive falha',
      () async {
        final firstCursor = _Cursor('page-1');
        final repo = _FakeUsersRepository()
          ..pages.add(
            AdminUsersPageSnapshot(
              items: <AdminUserListItem>[
                _item('active', AdminUserAuthState.active),
                _item('suspended', AdminUserAuthState.suspended),
                _item('missing', AdminUserAuthState.notFound),
                _item('unavailable', AdminUserAuthState.unavailable),
              ],
              cursor: firstCursor,
              isFromCache: true,
            ),
          )
          ..pages.add(
            const AdminUsersPageSnapshot(
              items: <AdminUserListItem>[],
              cursor: null,
              isFromCache: false,
            ),
          );
        final controller = AdminUsersController(repo);

        await controller.search(AdminUserSearchType.name, ' Ju');
        expect(controller.state.items, hasLength(4));
        expect(controller.state.hasMore, isTrue);
        expect(controller.state.isFromCache, isTrue);
        expect(
          controller.state.items.map((item) => item.authState),
          <AdminUserAuthState>[
            AdminUserAuthState.active,
            AdminUserAuthState.suspended,
            AdminUserAuthState.notFound,
            AdminUserAuthState.unavailable,
          ],
        );

        await controller.loadNextPage();
        expect(repo.searchCalls, hasLength(2));
        expect(repo.searchCalls.last.after, same(firstCursor));
        expect(controller.state.items, hasLength(4));
        expect(controller.state.hasMore, isFalse);
        controller.dispose();
      },
    );

    test(
      'UID e e-mail usam apenas consulta exata, sem consulta de lista',
      () async {
        final result = _details('uid-1');
        final repo = _FakeUsersRepository()..exactResult = result;
        final controller = AdminUsersController(repo);

        final byUid = await controller.search(AdminUserSearchType.uid, 'uid-1');
        expect(byUid, same(result));
        final byEmail = await controller.search(
          AdminUserSearchType.email,
          'person@example.test',
        );
        expect(byEmail, same(result));
        expect(repo.exactCalls, <(AdminUserSearchType, String)>[
          (AdminUserSearchType.uid, 'uid-1'),
          (AdminUserSearchType.email, 'person@example.test'),
        ]);
        expect(repo.searchCalls, isEmpty);
        controller.dispose();
      },
    );

    test('consulta exata ausente gera vazio, não estado Auth ativo', () async {
      final repo = _FakeUsersRepository();
      final controller = AdminUsersController(repo);

      final result = await controller.search(
        AdminUserSearchType.email,
        'x@y.z',
      );

      expect(result, isNull);
      expect(controller.state.exactNotFound, isTrue);
      expect(controller.state.items, isEmpty);
      controller.dispose();
    });
  });

  testWidgets('lista oferece seletor explícito, busca por prefixo e estados', (
    tester,
  ) async {
    final repo = _FakeUsersRepository()
      ..pages.add(
        const AdminUsersPageSnapshot(
          items: <AdminUserListItem>[
            AdminUserListItem(
              profile: AdminUserProfile(
                uid: 'profile-1',
                name: 'Júlia',
                handle: '@julia',
                avatarUrl: '',
                favoriteSports: <String>['corrida'],
              ),
              authState: AdminUserAuthState.unavailable,
            ),
          ],
          cursor: null,
          isFromCache: true,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminUsersPage(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Júlia'), findsOneWidget);
    expect(find.textContaining('Estado indisponível'), findsOneWidget);
    expect(find.textContaining('Exibindo dados em cache'), findsOneWidget);
    expect(find.text('UID'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<AdminUserSearchType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Handle').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '@Ma');
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.pumpAndSettle();

    expect(repo.searchCalls.last.type, AdminUserSearchType.handle);
    expect(repo.searchCalls.last.query, '@Ma');
  });

  testWidgets(
    'detalhe mostra Auth sem perfil e mantém ações permitidas da conta',
    (tester) async {
      final repo = _FakeUsersRepository();
      final details = AdminUserDetailsResult(
        uid: 'auth-only',
        profile: null,
        auth: const AdminUserAuthDetails(
          uid: 'auth-only',
          email: 'admin-target@example.test',
          emailVerified: true,
          providerIds: <String>['password'],
          createdAt: null,
          lastSignInAt: null,
          disabled: true,
        ),
        profileNotFound: true,
        profileUnavailable: false,
        profileFromCache: false,
        authNotFound: false,
        authUnavailable: false,
      );
      await _pumpDetails(tester, repo, result: details);

      expect(find.text('Perfil não encontrado'), findsOneWidget);
      expect(find.textContaining('admin-target@example.test'), findsOneWidget);
      expect(find.textContaining('Suspensa'), findsOneWidget);
      expect(find.textContaining('Provedores: password'), findsOneWidget);
      expect(find.text('Ações administrativas da conta'), findsOneWidget);
      expect(find.text('Motivo obrigatório'), findsOneWidget);
      expect(find.text('Reativar conta'), findsOneWidget);
      expect(find.textContaining('Editar'), findsNothing);
    },
  );

  testWidgets(
    'perfil sem Conta Auth é identificado sem oferecer ação de conta',
    (tester) async {
      final details = AdminUserDetailsResult(
        uid: 'profile-only',
        profile: const AdminUserProfile(
          uid: 'profile-only',
          name: 'Perfil legado',
          handle: '@legado',
          avatarUrl: '',
          favoriteSports: <String>['futebol'],
        ),
        auth: null,
        profileNotFound: false,
        profileUnavailable: false,
        profileFromCache: false,
        authNotFound: true,
        authUnavailable: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminUserDetailsPage(
              uid: 'profile-only',
              repository: _FakeUsersRepository(),
              initialDetails: details,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Conta não encontrada'), findsOneWidget);
      expect(find.text('Perfil legado'), findsOneWidget);
      expect(find.textContaining('Futebol'), findsOneWidget);
      expect(find.textContaining('Reativar'), findsNothing);
      expect(find.textContaining('Suspender'), findsNothing);
    },
  );

  group('ações administrativas de suspensão', () {
    testWidgets('valida motivo antes da confirmação ou chamada', (
      tester,
    ) async {
      final repo = _FakeUsersRepository()
        ..detailResult = _details('target-uid');
      await _pumpDetails(tester, repo);

      await tester.enterText(find.byType(TextField), 'curto');
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Suspender conta'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Suspender conta'));
      await tester.pumpAndSettle();

      expect(find.textContaining('10 a 500 caracteres'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.suspensionCalls, isEmpty);
    });

    testWidgets('confirma UID e limite de token e atualiza só após sucesso', (
      tester,
    ) async {
      final repo = _FakeUsersRepository()
        ..detailResult = _details('target-uid');
      await _pumpDetails(tester, repo);
      await tester.enterText(
        find.byType(TextField),
        'Violação comprovada das regras da comunidade.',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Suspender conta'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Suspender conta'));
      await tester.pumpAndSettle();

      expect(find.text('UID: target-uid'), findsWidgets);
      expect(
        find.textContaining('não é um bloqueio instantâneo'),
        findsWidgets,
      );
      expect(find.textContaining('Estado: Ativa'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirmar suspensão'),
      );
      await tester.pumpAndSettle();

      expect(repo.suspensionCalls, hasLength(1));
      expect(
        repo.suspensionCalls.single.action,
        AdminUserSuspensionAction.suspend,
      );
      expect(
        repo.suspensionCalls.single.operationId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(find.textContaining('Estado: Suspensa'), findsOneWidget);
      expect(find.text('Conta suspensa.'), findsOneWidget);
    });

    testWidgets(
      'mantém ação e status sem alteração enquanto aguarda servidor',
      (tester) async {
        final completer = Completer<AdminUserSuspensionResult>();
        final repo = _FakeUsersRepository()
          ..detailResult = _details('target-uid')
          ..suspensionHandler = (_, _, _, _) => completer.future;
        await _pumpDetails(tester, repo);
        await tester.enterText(
          find.byType(TextField),
          'Violação comprovada das regras da comunidade.',
        );
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Suspender conta'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Suspender conta'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, 'Confirmar suspensão'),
        );
        await tester.pump();

        final actionButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Suspender conta'),
        );
        expect(actionButton.onPressed, isNull);
        expect(find.textContaining('Estado: Ativa'), findsOneWidget);
        expect(find.textContaining('Aguardando confirmação'), findsOneWidget);

        completer.complete(_suspensionResult('target-uid', true));
        await tester.pumpAndSettle();
        expect(find.textContaining('Estado: Suspensa'), findsOneWidget);
      },
    );

    testWidgets(
      'retry de resultado incerto reutiliza o mesmo operationId e motivo',
      (tester) async {
        var attempts = 0;
        final repo = _FakeUsersRepository()
          ..detailResult = _details('target-uid')
          ..suspensionHandler = (uid, action, reason, operationId) async {
            attempts++;
            if (attempts == 1) throw StateError('transporte interrompido');
            return _suspensionResult(uid, true, action: action);
          };
        await _pumpDetails(tester, repo);
        const reason = 'Violação comprovada das regras da comunidade.';
        await tester.enterText(find.byType(TextField), reason);

        await _confirmSuspension(tester);
        expect(find.textContaining('tente novamente'), findsOneWidget);
        expect(find.text(reason), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        final firstOperationId = repo.suspensionCalls.first.operationId;

        await _confirmSuspension(tester);
        expect(repo.suspensionCalls, hasLength(2));
        expect(repo.suspensionCalls.last.operationId, firstOperationId);
        expect(repo.suspensionCalls.last.reason, reason);
        expect(find.textContaining('Estado: Suspensa'), findsOneWidget);
      },
    );

    testWidgets('negação segura do backend permanece próxima da ação', (
      tester,
    ) async {
      final repo = _FakeUsersRepository()
        ..detailResult = _details('admin-target')
        ..suspensionHandler = (_, _, _, _) async {
          throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'private details must not be shown',
          );
        };
      await _pumpDetails(tester, repo);
      await tester.enterText(
        find.byType(TextField),
        'Violação comprovada das regras da comunidade.',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Suspender conta'),
      );
      await _confirmSuspension(tester);

      expect(
        find.text('Esta conta não pode ser alterada pelo painel.'),
        findsOneWidget,
      );
      expect(find.textContaining('private details'), findsNothing);
      expect(find.textContaining('Estado: Ativa'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Suspender conta'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('falha por estado já alterado recarrega o estado Auth', (
      tester,
    ) async {
      final repo = _FakeUsersRepository()
        ..detailResult = _details('target-uid');
      repo.suspensionHandler = (_, _, _, _) async {
        repo.detailResult = _details('target-uid', disabled: true);
        throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'safe server failure',
        );
      };
      await _pumpDetails(tester, repo);
      await tester.enterText(
        find.byType(TextField),
        'Violação comprovada das regras da comunidade.',
      );
      await _confirmSuspension(tester);

      expect(find.textContaining('Estado: Suspensa'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Reativar conta'),
        findsOneWidget,
      );
      expect(find.textContaining('já está nesse estado'), findsOneWidget);
    });

    testWidgets('reativação exige confirmação e reflete resposta confirmada', (
      tester,
    ) async {
      final repo = _FakeUsersRepository()
        ..detailResult = _details('suspended-user', disabled: true);
      await _pumpDetails(tester, repo);
      await tester.enterText(
        find.byType(TextField),
        'Revisão administrativa concluída com justificativa.',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Reativar conta'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Reativar conta'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar reativação'), findsWidgets);
      expect(
        find.textContaining(
          'Tokens de sessões anteriores não serão restaurados',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirmar reativação'),
      );
      await tester.pumpAndSettle();

      expect(
        repo.suspensionCalls.single.action,
        AdminUserSuspensionAction.reactivate,
      );
      expect(find.textContaining('Estado: Ativa'), findsOneWidget);
      expect(find.text('Conta reativada.'), findsOneWidget);
    });

    testWidgets('rótulos da ação e do motivo são acessíveis', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpDetails(
        tester,
        _FakeUsersRepository()..detailResult = _details('target-uid'),
      );

      expect(find.bySemanticsLabel('Motivo obrigatório'), findsOneWidget);
      expect(find.bySemanticsLabel('Suspender conta'), findsOneWidget);
      semantics.dispose();
    });
  });
}

Future<void> _pumpDetails(
  WidgetTester tester,
  _FakeUsersRepository repo, {
  AdminUserDetailsResult? result,
}) async {
  tester.view.physicalSize = const Size(1100, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminUserDetailsPage(
          uid: result?.uid ?? 'target-uid',
          repository: repo,
          initialDetails: result,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _confirmSuspension(WidgetTester tester) async {
  await tester.ensureVisible(
    find.widgetWithText(FilledButton, 'Suspender conta'),
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Suspender conta'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Confirmar suspensão'));
  await tester.pumpAndSettle();
}

AdminUserSuspensionResult _suspensionResult(
  String uid,
  bool disabled, {
  AdminUserSuspensionAction action = AdminUserSuspensionAction.suspend,
}) => AdminUserSuspensionResult(
  uid: uid,
  disabled: disabled,
  action: action,
  completedAt: DateTime.utc(2026, 10, 3),
);

AdminUserListItem _item(String uid, AdminUserAuthState state) =>
    AdminUserListItem(
      profile: AdminUserProfile(
        uid: uid,
        name: uid,
        handle: '@$uid',
        avatarUrl: '',
        favoriteSports: const <String>[],
      ),
      authState: state,
    );

AdminUserDetailsResult _details(String uid, {bool disabled = false}) =>
    AdminUserDetailsResult(
      uid: uid,
      profile: null,
      auth: AdminUserAuthDetails(
        uid: uid,
        email: null,
        emailVerified: false,
        providerIds: const <String>[],
        createdAt: null,
        lastSignInAt: null,
        disabled: disabled,
      ),
      profileNotFound: true,
      profileUnavailable: false,
      profileFromCache: false,
      authNotFound: false,
      authUnavailable: false,
    );

class _Cursor implements AdminUserCursor {
  const _Cursor(this.label);
  final String label;
}

class _SearchCall {
  const _SearchCall(this.type, this.query, this.after);
  final AdminUserSearchType type;
  final String query;
  final AdminUserCursor? after;
}

class _FakeUsersRepository implements AdminUsersRepository {
  final List<AdminUsersPageSnapshot> pages = <AdminUsersPageSnapshot>[];
  final List<_SearchCall> searchCalls = <_SearchCall>[];
  final List<(AdminUserSearchType, String)> exactCalls =
      <(AdminUserSearchType, String)>[];
  AdminUserDetailsResult? exactResult;
  AdminUserDetailsResult? detailResult;
  final List<_SuspensionCall> suspensionCalls = <_SuspensionCall>[];
  Future<AdminUserSuspensionResult> Function(
    String uid,
    AdminUserSuspensionAction action,
    String reason,
    String operationId,
  )?
  suspensionHandler;

  @override
  Future<AdminUserDetailsResult?> findExact(
    AdminUserSearchType type,
    String query,
  ) async {
    exactCalls.add((type, query));
    return exactResult;
  }

  @override
  Future<AdminUserDetailsResult> loadDetails(String uid) async =>
      detailResult ?? _details(uid);

  @override
  Future<AdminUserSuspensionResult> setUserSuspension({
    required String uid,
    required AdminUserSuspensionAction action,
    required String reason,
    required String operationId,
  }) {
    suspensionCalls.add(_SuspensionCall(uid, action, reason, operationId));
    final handler = suspensionHandler;
    if (handler != null) return handler(uid, action, reason, operationId);
    return Future<AdminUserSuspensionResult>.value(
      _suspensionResult(
        uid,
        action == AdminUserSuspensionAction.suspend,
        action: action,
      ),
    );
  }

  @override
  Future<AdminUsersPageSnapshot> searchProfiles(
    AdminUserSearchType type,
    String query, {
    AdminUserCursor? after,
  }) async {
    searchCalls.add(_SearchCall(type, query, after));
    if (pages.isEmpty) {
      return const AdminUsersPageSnapshot(
        items: <AdminUserListItem>[],
        cursor: null,
        isFromCache: false,
      );
    }
    return pages.removeAt(0);
  }
}

class _SuspensionCall {
  const _SuspensionCall(this.uid, this.action, this.reason, this.operationId);
  final String uid;
  final AdminUserSuspensionAction action;
  final String reason;
  final String operationId;
}
