import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/features/auth/domain/entities/auth_user.dart';
import 'package:mvp_compy/features/auth/domain/repositories/auth_repository.dart';
import 'package:mvp_compy/features/auth/presentation/providers/auth_providers.dart';
import 'package:mvp_compy/features/profile/domain/entities/rating_summary.dart';
import 'package:mvp_compy/features/profile/domain/entities/user_profile.dart';
import 'package:mvp_compy/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

/// Só os dois métodos que esta tela usa têm corpo; o resto estoura de
/// propósito, para um uso não previsto aparecer como falha e não como
/// silêncio.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.needsPassword = false, this.errorOnDelete});

  final bool needsPassword;
  final Object? errorOnDelete;

  int deleteCalls = 0;
  String? passwordUsed;

  @override
  bool signedInWithPassword() => needsPassword;

  @override
  Future<void> deleteAccount({String? password}) async {
    deleteCalls++;
    passwordUsed = password;
    if (errorOnDelete != null) throw errorOnDelete!;
  }

  @override
  Stream<AuthUser?> authState() => const Stream<AuthUser?>.empty();

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signUpWithEmail({
    required String name,
    required String username,
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<bool> isUsernameAvailable(String username, {String? forUid}) =>
      throw UnimplementedError();

  @override
  Future<void> setUsername({
    required String uid,
    required String username,
    required String name,
    required String email,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}

void main() {
  const UserProfile perfil = UserProfile(
    summary: UserSummary(
      id: 'u_gabriel',
      name: 'Gabriel',
      handle: '@gabriel',
      avatarUrl: '',
    ),
    bio: '',
    favoriteSports: <Never>[],
    badges: <Never>[],
    friends: <Never>[],
    rating: RatingSummary(average: 0, count: 0, breakdown: <int, double>{}),
    gallery: <String>[],
  );

  Future<_FakeAuthRepository> pumpPage(
    WidgetTester tester, {
    bool needsPassword = false,
    Object? errorOnDelete,
  }) async {
    final repo = _FakeAuthRepository(
      needsPassword: needsPassword,
      errorOnDelete: errorOnDelete,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWith((_) => repo),
          currentProfileProvider.overrideWith((_) async => perfil),
        ],
        child: const MaterialApp(home: EditProfilePage()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> abrirDialogo(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.profileDeleteAccount));
    await tester.pumpAndSettle();
  }

  group('EditProfilePage — username', () {
    testWidgets('mostra o handle atual, mas não deixa editar', (tester) async {
      await pumpPage(tester);

      expect(find.text('@gabriel'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).readOnly,
        isTrue,
      );
    });

    testWidgets('explica por que o campo está apagado', (tester) async {
      await pumpPage(tester);
      expect(find.text(AppStrings.profileUsernameLocked), findsOneWidget);
    });
  });

  group('EditProfilePage — excluir conta', () {
    testWidgets('pede confirmação antes de qualquer coisa', (tester) async {
      final repo = await pumpPage(tester);
      await abrirDialogo(tester);

      expect(find.text(AppStrings.profileDeleteAccountTitle), findsOneWidget);
      expect(find.text(AppStrings.profileDeleteAccountBody), findsOneWidget);
      expect(repo.deleteCalls, 0);
    });

    testWidgets('cancelar não exclui nada', (tester) async {
      final repo = await pumpPage(tester);
      await abrirDialogo(tester);

      await tester.tap(find.text(AppStrings.commonCancel));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, 0);
    });

    testWidgets('conta Google avisa do seletor e exclui sem senha',
        (tester) async {
      final repo = await pumpPage(tester);
      await abrirDialogo(tester);

      expect(
        find.text(AppStrings.profileDeleteAccountGoogleHint),
        findsOneWidget,
      );

      await tester.tap(find.text(AppStrings.profileDeleteAccountConfirm));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, 1);
      expect(repo.passwordUsed, isNull);
    });

    testWidgets('conta com senha exclui usando o que foi digitado',
        (tester) async {
      final repo = await pumpPage(tester, needsPassword: true);
      await abrirDialogo(tester);

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.profileDeleteAccountPasswordHint),
        'segredo123',
      );
      await tester.tap(find.text(AppStrings.profileDeleteAccountConfirm));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, 1);
      expect(repo.passwordUsed, 'segredo123');
    });

    // Sem senha o Firebase recusaria a reautenticação de qualquer jeito; parar
    // antes evita apagar nada e diz o motivo na hora.
    testWidgets('conta com senha não exclui com o campo vazio', (tester) async {
      final repo = await pumpPage(tester, needsPassword: true);
      await abrirDialogo(tester);

      await tester.tap(find.text(AppStrings.profileDeleteAccountConfirm));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, 0);
      expect(
        find.text(AppStrings.profileDeleteAccountPasswordEmpty),
        findsOneWidget,
      );
    });

    testWidgets('falha de senha vira mensagem na tela', (tester) async {
      await pumpPage(
        tester,
        needsPassword: true,
        errorOnDelete: FirebaseAuthException(code: 'invalid-credential'),
      );
      await abrirDialogo(tester);

      await tester.enterText(
        find.widgetWithText(TextField, AppStrings.profileDeleteAccountPasswordHint),
        'errada',
      );
      await tester.tap(find.text(AppStrings.profileDeleteAccountConfirm));
      await tester.pumpAndSettle();

      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    });
  });
}
