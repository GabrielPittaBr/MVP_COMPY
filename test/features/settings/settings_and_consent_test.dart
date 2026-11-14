import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_links.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/providers/location_providers.dart';
import 'package:mvp_compy/core/services/age_signals_service.dart';
import 'package:mvp_compy/features/auth/domain/entities/auth_user.dart';
import 'package:mvp_compy/features/auth/domain/entities/legal_consent.dart';
import 'package:mvp_compy/features/auth/domain/repositories/auth_repository.dart';
import 'package:mvp_compy/features/auth/presentation/pages/consent_page.dart';
import 'package:mvp_compy/features/auth/presentation/providers/auth_providers.dart';
import 'package:mvp_compy/features/settings/presentation/pages/settings_page.dart';
import 'package:mvp_compy/features/settings/presentation/providers/settings_providers.dart';

class _NoAgeSignal extends AgeSignalsService {
  const _NoAgeSignal();
  @override
  Future<AgeSignal?> check() async => null;
}

/// Só o aceite tem corpo; o resto não é exercitado aqui.
class _FakeAuthRepository implements AuthRepository {
  final List<LegalConsentInput?> accepted = <LegalConsentInput?>[];

  @override
  Future<AuthUser> acceptLegalTerms({LegalConsentInput? consent}) async {
    accepted.add(consent);
    return AuthUser(
      uid: 'u1',
      email: 'a@b.c',
      displayName: 'Ana',
      hasUsername: true,
      hasFavoriteSports: true,
      legalVersion: AppLinks.legalVersion,
      birthDate: consent?.birthDate ?? DateTime.utc(2000),
    );
  }

  @override
  Future<void> signOut() async {}
  @override
  bool signedInWithPassword() => false;
  @override
  Future<void> deleteAccount({String? password}) async {}
  @override
  Future<void> abortUnderageSignup() async {}
  @override
  Stream<AuthUser?> authState() => const Stream<AuthUser?>.empty();
  @override
  Future<AuthUser> signInWithEmail({required String email, required String password}) =>
      throw UnimplementedError();
  @override
  Future<AuthUser> signUpWithEmail({
    required String name,
    required String username,
    required String email,
    required String password,
    required LegalConsentInput consent,
    Uint8List? photo,
  }) =>
      throw UnimplementedError();
  @override
  Future<AuthUser> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<bool> isUsernameAvailable(String username, {String? forUid}) => throw UnimplementedError();
  @override
  Future<void> setUsername({
    required String uid,
    required String username,
    required String name,
    required String email,
    required LegalConsentInput consent,
    Uint8List? photo,
    String? photoUrl,
  }) =>
      throw UnimplementedError();
}

AuthUser _user({DateTime? birthDate, DateTime? adultAt, String? version}) => AuthUser(
      uid: 'u1',
      email: 'a@b.c',
      displayName: 'Ana',
      hasUsername: true,
      hasFavoriteSports: true,
      legalVersion: version,
      birthDate: birthDate,
      adultAt: adultAt,
    );

void main() {
  late _FakeAuthRepository repository;

  setUp(() => repository = _FakeAuthRepository());

  Widget app(Widget page, AuthUser user, {List<Override> extra = const <Override>[]}) => ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith((ref) => Stream<AuthUser?>.value(user)),
          ageSignalsServiceProvider.overrideWithValue(const _NoAgeSignal()),
          locationAccessProvider.overrideWith((ref) async => LocationAccess.notGranted),
          ...extra,
        ],
        child: MaterialApp(home: page),
      );

  group('ConsentPage', () {
    testWidgets('conta antiga informa a data, aceita e grava o aceite', (tester) async {
      await tester.pumpWidget(app(const ConsentPage(), _user()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.consentBodyFirst), findsOneWidget);
      await tester.tap(find.text(AppStrings.consentContinue));
      await tester.pumpAndSettle();
      // Sem data e sem a caixa marcada, não segue.
      expect(find.text(AppStrings.ageInvalidFormat), findsOneWidget);
      expect(find.text(AppStrings.legalAcceptRequired), findsOneWidget);
      expect(repository.accepted, isEmpty);

      await tester.enterText(find.byType(TextFormField), '01052000');
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text(AppStrings.consentContinue));
      await tester.pumpAndSettle();

      expect(repository.accepted.single?.birthDate, DateTime.utc(2000, 5, 1));
    });

    testWidgets('menos de 16 anos não entra e vê a opção de excluir a conta', (tester) async {
      await tester.pumpWidget(app(const ConsentPage(), _user()));
      await tester.pumpAndSettle();

      final int year = DateTime.now().year - 12;
      await tester.enterText(find.byType(TextFormField), '0101$year');
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text(AppStrings.consentContinue));
      await tester.pumpAndSettle();

      expect(repository.accepted, isEmpty);
      expect(find.text(AppStrings.consentUnderageTitle), findsOneWidget);
      expect(find.text(AppStrings.consentUnderageDelete), findsOneWidget);
    });

    testWidgets('Termos novos: só pede o aceite, sem a data', (tester) async {
      await tester.pumpWidget(app(
        const ConsentPage(),
        _user(birthDate: DateTime.utc(2000), version: '2020-01-01'),
      ));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.consentBodyRenew), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text(AppStrings.consentContinue));
      await tester.pumpAndSettle();

      expect(repository.accepted, <LegalConsentInput?>[null]);
    });
  });

  group('SettingsPage', () {
    testWidgets('reúne os direitos do titular e a exclusão de conta', (tester) async {
      await tester.pumpWidget(app(
        const SettingsPage(),
        _user(birthDate: DateTime.utc(2000), version: AppLinks.legalVersion),
      ));
      await tester.pumpAndSettle();

      for (final String text in <String>[
        AppStrings.settingsPrivacyPolicy,
        AppStrings.settingsTerms,
        AppStrings.settingsDownloadData,
        AppStrings.settingsLocationOff,
        AppStrings.settingsBlocked,
        AppStrings.settingsContact,
        AppStrings.settingsDeleteAccount,
      ]) {
        await tester.scrollUntilVisible(find.text(text), 100);
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text(AppStrings.consentMinorNotice), findsNothing);
    });

    testWidgets('quem tem 16 ou 17 anos vê a proteção extra', (tester) async {
      final DateTime now = DateTime.now();
      await tester.pumpWidget(app(
        const SettingsPage(),
        _user(
          birthDate: DateTime.utc(now.year - 17),
          adultAt: DateTime.utc(now.year + 1),
          version: AppLinks.legalVersion,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.consentMinorNotice), findsOneWidget);
    });

    testWidgets('"Baixar meus dados" gera o JSON e abre o compartilhamento', (tester) async {
      final List<String> shared = <String>[];
      await tester.pumpWidget(app(
        const SettingsPage(),
        _user(birthDate: DateTime.utc(2000), version: AppLinks.legalVersion),
        extra: <Override>[
          dataExportRemoteProvider.overrideWithValue(null),
          shareDataFileProvider.overrideWithValue((String json) async => shared.add(json)),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.settingsDownloadData));
      await tester.pumpAndSettle();

      expect(shared.single, contains('compy-dados-v1'));
    });
  });
}
