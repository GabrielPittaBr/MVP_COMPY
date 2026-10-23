import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/features/auth/domain/entities/auth_user.dart';
import 'package:mvp_compy/features/auth/domain/repositories/auth_repository.dart';
import 'package:mvp_compy/features/auth/presentation/providers/auth_providers.dart';
import 'package:mvp_compy/features/profile/domain/entities/user_profile.dart';
import 'package:mvp_compy/features/profile/domain/repositories/profile_repository.dart';
import 'package:mvp_compy/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:mvp_compy/features/profile/presentation/providers/profile_providers.dart';
import 'package:mvp_compy/shared/models/sport.dart';
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
    Uint8List? photo,
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
    Uint8List? photo,
    String? photoUrl,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}

/// Só a troca de foto tem corpo, pelo mesmo motivo do [_FakeAuthRepository].
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.errorOnAvatar, this.errorOnDetails});

  final Object? errorOnAvatar;
  final Object? errorOnDetails;
  final List<(String, String, Uint8List?)> avatarCalls =
      <(String, String, Uint8List?)>[];
  final List<(String, String, String)> detailCalls = [];

  @override
  Future<void> updateDetails(String uid,
      {required String name, required String bio}) async {
    detailCalls.add((uid, name, bio));
    if (errorOnDetails != null) throw errorOnDetails!;
  }

  @override
  Future<void> updateAvatar(
    String uid, {
    required String name,
    Uint8List? jpeg,
  }) async {
    avatarCalls.add((uid, name, jpeg));
    if (errorOnAvatar != null) throw errorOnAvatar!;
  }

  @override
  Future<UserProfile> getCurrentProfile(String uid) =>
      throw UnimplementedError();

  @override
  Future<UserProfile?> getPublicProfile(String uid) =>
      throw UnimplementedError();

  @override
  Future<void> updateFavoriteSports(String uid, List<Sport> sports) =>
      throw UnimplementedError();

  @override
  Future<List<UserSummary>> searchByHandle(
    String handlePrefix, {
    String? excludeUid,
    int limit = 20,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<UserSummary>> searchByName(
    String namePrefix, {
    String? excludeUid,
    int limit = 20,
  }) =>
      throw UnimplementedError();
}

UserProfile perfilCom({required String avatarUrl}) => UserProfile(
      summary: UserSummary(
        id: 'u_gabriel',
        name: 'Gabriel',
        handle: '@gabriel',
        avatarUrl: avatarUrl,
      ),
      bio: '',
      favoriteSports: const <Never>[],
      badges: const <Never>[],
      friends: const <Never>[],
      gallery: const <String>[],
    );

void main() {
  final UserProfile perfil = perfilCom(avatarUrl: '');

  Future<_FakeAuthRepository> pumpPage(
    WidgetTester tester, {
    bool needsPassword = false,
    Object? errorOnDelete,
    UserProfile? profile,
    ProfileRepository? profileRepository,
  }) async {
    final repo = _FakeAuthRepository(
      needsPassword: needsPassword,
      errorOnDelete: errorOnDelete,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWith((_) => repo),
          authStateProvider.overrideWith((_) => Stream.value(const AuthUser(
                uid: 'u_gabriel',
                email: 'gabriel@example.com',
                displayName: 'Gabriel',
                hasUsername: true,
                hasFavoriteSports: true,
              ))),
          currentProfileProvider.overrideWith((_) async => profile ?? perfil),
          if (profileRepository != null)
            profileRepositoryProvider.overrideWith((_) => profileRepository),
        ],
        child: const MaterialApp(home: EditProfilePage()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  /// A foto é carregada por rede, e no ambiente de teste isso sempre falha.
  /// Como em `greeting_header_test`, só a biblioteca de imagem é silenciada.
  void ignoreImageErrors() {
    final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.library == 'image resource service') return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  group('EditProfilePage — foto', () {
    const String fotoReal =
        'https://firebasestorage.googleapis.com/v0/b/compy/o/a.jpg';

    testWidgets('sem foto mostra a inicial e oferece adicionar',
        (tester) async {
      await pumpPage(tester);

      expect(find.text('G'), findsOneWidget);
      expect(find.text(AppStrings.photoAdd), findsOneWidget);
      expect(find.text(AppStrings.photoRemove), findsNothing);
    });

    testWidgets('remover grava na hora, sem foto nova', (tester) async {
      ignoreImageErrors();
      final profileRepo = _FakeProfileRepository();
      await pumpPage(
        tester,
        profile: perfilCom(avatarUrl: fotoReal),
        profileRepository: profileRepo,
      );

      await tester.tap(find.text(AppStrings.photoRemove));
      await tester.pumpAndSettle();

      expect(profileRepo.avatarCalls, <(String, String, Uint8List?)>[
        ('u_gabriel', 'Gabriel', null),
      ]);
      expect(find.text(AppStrings.photoSaveError), findsNothing);
    });

    testWidgets('falha ao gravar vira mensagem na tela', (tester) async {
      ignoreImageErrors();
      await pumpPage(
        tester,
        profile: perfilCom(avatarUrl: fotoReal),
        profileRepository:
            _FakeProfileRepository(errorOnAvatar: Exception('sem rede')),
      );

      await tester.tap(find.text(AppStrings.photoRemove));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.photoSaveError), findsOneWidget);
    });
  });

  Future<void> abrirDialogo(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.profileDeleteAccount));
    await tester.pumpAndSettle();
  }

  group('EditProfilePage — username', () {
    testWidgets('mostra o handle atual, mas não deixa editar', (tester) async {
      await pumpPage(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('@gabriel'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
                find.widgetWithText(TextField, AppStrings.authUsernameField))
            .readOnly,
        isTrue,
      );
    });

    testWidgets('explica por que o campo está apagado', (tester) async {
      await pumpPage(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.profileUsernameLocked), findsOneWidget);
    });
  });

  group('EditProfilePage — nome e biografia', () {
    testWidgets('carrega os dados e nao grava sem alteracao', (tester) async {
      final repo = _FakeProfileRepository();
      await pumpPage(tester, profileRepository: repo);
      expect(find.text('Gabriel'), findsWidgets);
      expect(find.text(AppStrings.profileSaveChanges), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(find.widgetWithText(
                  FilledButton, AppStrings.profileSaveChanges))
              .onPressed,
          isNull);
      expect(repo.detailCalls, isEmpty);
    });

    testWidgets('limpa espacos do nome e grava biografia', (tester) async {
      final repo = _FakeProfileRepository();
      await pumpPage(tester, profileRepository: repo);
      await tester.enterText(
          find.widgetWithText(TextField, AppStrings.profileNameLabel),
          '  Gabriel Silva  ');
      await tester.enterText(
          find.widgetWithText(TextField, AppStrings.profileBioHint),
          'Volei em Taquara');
      await tester.tap(find.text(AppStrings.profileSaveChanges));
      await tester.pumpAndSettle();
      expect(repo.detailCalls,
          [('u_gabriel', 'Gabriel Silva', 'Volei em Taquara')]);
      expect(find.text(AppStrings.profileSaveSuccess), findsOneWidget);
    });

    testWidgets('nome vazio e recusado', (tester) async {
      final repo = _FakeProfileRepository();
      await pumpPage(tester, profileRepository: repo);
      await tester.enterText(
          find.widgetWithText(TextField, AppStrings.profileNameLabel), '   ');
      await tester.pump();
      expect(find.text(AppStrings.profileNameRequired), findsOneWidget);
      await tester.tap(find.text(AppStrings.profileSaveChanges));
      await tester.pump();
      expect(repo.detailCalls, isEmpty);
    });

    testWidgets('limita nome e bio e mostra contador', (tester) async {
      await pumpPage(tester);
      await tester.enterText(
          find.widgetWithText(TextField, AppStrings.profileNameLabel),
          'a' * 61);
      await tester.enterText(
          find.widgetWithText(TextField, AppStrings.profileBioHint), 'b' * 161);
      await tester.pump();
      expect(
          tester
              .widget<TextField>(
                  find.widgetWithText(TextField, AppStrings.profileNameLabel))
              .controller!
              .text
              .length,
          60);
      expect(
          tester
              .widget<TextField>(
                  find.widgetWithText(TextField, AppStrings.profileBioHint))
              .controller!
              .text
              .length,
          160);
      expect(find.text('160/160'), findsOneWidget);
    });

    testWidgets('voltar com alteracoes pede para descartar', (tester) async {
      await pumpPage(tester);
      await tester.enterText(
          find.widgetWithText(TextField, AppStrings.profileNameLabel),
          'Outro nome');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.profileDiscardTitle), findsOneWidget);
      await tester.tap(find.text(AppStrings.profileContinueEditing));
      await tester.pumpAndSettle();
      expect(find.text('Outro nome'), findsOneWidget);
    });

    testWidgets('bio pode ser apagada, falha preserva texto para repetir',
        (tester) async {
      final repo = _FakeProfileRepository(errorOnDetails: StateError('rede'));
      await pumpPage(tester,
          profile: UserProfile(
            summary: perfil.summary,
            bio: 'Bio anterior',
            favoriteSports: const [],
            badges: const [],
            friends: const [],
            gallery: const [],
          ),
          profileRepository: repo);
      expect(
          tester
              .widget<TextField>(
                  find.widgetWithText(TextField, AppStrings.profileBioHint))
              .controller!
              .text,
          'Bio anterior');
      await tester.enterText(
          find.widgetWithText(TextField, AppStrings.profileBioHint), '');
      await tester.pump();
      expect(
          tester
              .widget<FilledButton>(find.widgetWithText(
                  FilledButton, AppStrings.profileSaveChanges))
              .onPressed,
          isNotNull);
      await tester.tap(find.text(AppStrings.profileSaveChanges));
      await tester.pumpAndSettle();
      expect(repo.detailCalls, [('u_gabriel', 'Gabriel', '')]);
      expect(find.text(AppStrings.profileSaveError), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(find.widgetWithText(
                  FilledButton, AppStrings.profileSaveChanges))
              .onPressed,
          isNotNull);
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
        find.widgetWithText(
            TextField, AppStrings.profileDeleteAccountPasswordHint),
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
        find.widgetWithText(
            TextField, AppStrings.profileDeleteAccountPasswordHint),
        'errada',
      );
      await tester.tap(find.text(AppStrings.profileDeleteAccountConfirm));
      await tester.pumpAndSettle();

      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    });
  });
}
