import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/core/utils/username_rules.dart';

void main() {
  group('UsernameRules.validate', () {
    test('aceita usernames dentro da regra', () {
      expect(UsernameRules.validate('joao'), isNull);
      expect(UsernameRules.validate('joao_silva'), isNull);
      expect(UsernameRules.validate('joao.silva'), isNull);
      expect(UsernameRules.validate('j0a0'), isNull);
      expect(UsernameRules.validate('abc'), isNull);
      expect(UsernameRules.validate('a' * 20), isNull);
    });

    test('rejeita vazio', () {
      expect(UsernameRules.validate(null), AppStrings.authErrorUsernameEmpty);
      expect(UsernameRules.validate('   '), AppStrings.authErrorUsernameEmpty);
    });

    test('rejeita fora da faixa de tamanho', () {
      expect(UsernameRules.validate('ab'), AppStrings.authErrorUsernameTooShort);
      expect(
        UsernameRules.validate('a' * 21),
        AppStrings.authErrorUsernameTooLong,
      );
    });

    test('rejeita caracteres fora do conjunto', () {
      expect(
        UsernameRules.validate('João'),
        AppStrings.authErrorUsernameInvalidChars,
      );
      expect(
        UsernameRules.validate('joao silva'),
        AppStrings.authErrorUsernameInvalidChars,
      );
      expect(
        UsernameRules.validate('joao-silva'),
        AppStrings.authErrorUsernameInvalidChars,
      );
    });

    test('rejeita ponto no começo ou no fim', () {
      expect(
        UsernameRules.validate('.joao'),
        AppStrings.authErrorUsernameInvalidChars,
      );
      expect(
        UsernameRules.validate('joao.'),
        AppStrings.authErrorUsernameInvalidChars,
      );
    });
  });

  group('UsernameRules.inputFormatters', () {
    /// Aplica a cadeia de formatters como o `TextField` faria.
    String format(String input) {
      TextEditingValue value = TextEditingValue.empty;
      for (final formatter in UsernameRules.inputFormatters) {
        value = formatter.formatEditUpdate(
          value,
          TextEditingValue(
            text: input,
            selection: TextSelection.collapsed(offset: input.length),
          ),
        );
        input = value.text;
      }
      return value.text;
    }

    test('força minúscula em vez de descartar o caractere', () {
      expect(format('Joao'), 'joao');
      expect(format('JOAO'), 'joao');
    });

    test('remove caracteres fora do conjunto', () {
      expect(format('joao silva'), 'joaosilva');
      expect(format('joao-silva!'), 'joaosilva');
    });

    test('limita o tamanho máximo', () {
      expect(format('a' * 30).length, UsernameRules.maxLength);
    });
  });
}
