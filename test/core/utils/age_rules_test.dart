import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_links.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/utils/age_rules.dart';
import 'package:mvp_compy/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mvp_compy/features/auth/domain/entities/auth_user.dart';
import 'package:mvp_compy/features/auth/domain/entities/legal_consent.dart';

void main() {
  final DateTime today = DateTime.utc(2026, 11, 14);

  group('AgeRules.parseBirthDate', () {
    test('lê dd/mm/aaaa', () {
      expect(AgeRules.parseBirthDate('01/05/2008'), DateTime.utc(2008, 5, 1));
    });

    test('recusa datas que não existem e formatos errados', () {
      expect(AgeRules.parseBirthDate('31/02/2008'), isNull);
      expect(AgeRules.parseBirthDate('00/13/2008'), isNull);
      expect(AgeRules.parseBirthDate('1/5/2008'), isNull);
      expect(AgeRules.parseBirthDate(''), isNull);
    });
  });

  group('AgeRules.validate', () {
    test('16 anos completos hoje passa; um dia antes não', () {
      expect(AgeRules.validate('14/11/2010', today), isNull);
      expect(AgeRules.validate('15/11/2010', today), AppStrings.ageUnderMinimum);
    });

    test('sem exigir a idade mínima, só confere a forma', () {
      expect(AgeRules.validate('15/11/2015', today, enforceMinimum: false), isNull);
      expect(AgeRules.validate('15/11', today, enforceMinimum: false), AppStrings.ageInvalidFormat);
    });

    test('recusa datas no futuro e antes de 1900', () {
      expect(AgeRules.validate('01/01/2030', today), AppStrings.ageInvalidDate);
      expect(AgeRules.validate('01/01/1899', today), AppStrings.ageInvalidDate);
    });
  });

  group('AgeRules — idade e maioridade', () {
    test('a idade só sobe no aniversário', () {
      expect(AgeRules.ageOn(DateTime.utc(2009, 11, 15), today), 16);
      expect(AgeRules.ageOn(DateTime.utc(2009, 11, 14), today), 17);
    });

    test('quem nasceu em 29/02 faz 18 em 01/03', () {
      expect(AgeRules.adultAt(DateTime.utc(2008, 2, 29)), DateTime.utc(2026, 3, 1));
    });

    test('a máscara coloca as barras sozinha', () {
      TextEditingValue value = const TextEditingValue();
      for (final String digit in '01052008'.split('')) {
        TextEditingValue next = TextEditingValue(text: value.text + digit);
        for (final TextInputFormatter formatter in AgeRules.inputFormatters) {
          next = formatter.formatEditUpdate(value, next);
        }
        value = next;
      }
      expect(value.text, '01/05/2008');
    });
  });

  group('AuthUser — aceite e adolescência', () {
    final AuthUser base = AuthUser(
      uid: 'u1',
      email: 'a@b.c',
      displayName: 'A',
      hasUsername: true,
      hasFavoriteSports: true,
      legalVersion: AppLinks.legalVersion,
      birthDate: DateTime.utc(2009, 1, 1),
      adultAt: DateTime.utc(2027, 1, 1),
    );

    test('aceite atual exige a versão atual e a data de nascimento', () {
      expect(base.hasCurrentConsent, isTrue);
      expect(base.copyWith(legalVersion: '2020-01-01').hasCurrentConsent, isFalse);
    });

    test('16 ou 17 anos pela data ou pela faixa da Google Play', () {
      expect(base.isMinorAt(today), isTrue);
      expect(base.isMinorAt(DateTime.utc(2027, 2, 1)), isFalse);
      final AuthUser adulto = base.copyWith(adultAt: DateTime.utc(2020, 1, 1));
      expect(adulto.isMinorAt(today), isFalse);
      expect(adulto.copyWith(ageSignalUpper: 17).isMinorAt(today), isTrue);
    });
  });

  test('o aceite gravado tem o formato que as regras validam', () {
    final Map<String, dynamic> data = AuthRemoteDataSource.consentData(
      LegalConsentInput(birthDate: DateTime.utc(2008, 5, 1), ageSignalLower: 16, ageSignalUpper: 17),
    );
    expect(data['termsVersion'], AppLinks.legalVersion);
    expect(data['acceptedAt'], isA<FieldValue>());
    expect(data['birthDate'], Timestamp.fromDate(DateTime.utc(2008, 5, 1)));
    expect(data['adultAt'], Timestamp.fromDate(DateTime.utc(2026, 5, 1)));
    expect((data['ageSignal'] as Map<String, dynamic>).keys, containsAll(<String>['lower', 'upper', 'checkedAt']));
    expect(
      AuthRemoteDataSource.consentData(LegalConsentInput(birthDate: DateTime.utc(2000, 1, 1))).containsKey('ageSignal'),
      isFalse,
    );
  });
}
