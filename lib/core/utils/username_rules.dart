import 'package:flutter/services.dart';

import '../constants/app_strings.dart';

/// Limite do nome completo — usado no cadastro por e-mail e na tela
/// pós-login Google. Fica aqui para os dois formulários de conta lerem o
/// mesmo número.
const int kMaxDisplayNameLength = 60;

/// Regra única de username, compartilhada pelo cadastro por e-mail
/// ([SignupPage]) e pela tela pós-login Google ([UsernamePage]).
///
/// Formato: de [minLength] a [maxLength] caracteres, apenas `a-z`, `0-9`,
/// `_` e `.`, sem começar nem terminar com ponto.
///
/// O datasource já normaliza com `toLowerCase()` antes de gravar; os
/// [inputFormatters] antecipam isso na digitação para o usuário não escrever
/// "João" e descobrir depois que foi salvo "joao".
abstract final class UsernameRules {
  static const int minLength = 3;
  static const int maxLength = 20;

  /// Conjunto de caracteres aceitos no campo.
  static final RegExp _allowedChars = RegExp(r'[a-z0-9._]');

  /// Formato completo: não começa nem termina com ponto.
  static final RegExp _validFormat = RegExp(r'^[a-z0-9_][a-z0-9._]*[a-z0-9_]$');

  /// Formatters do campo: minúscula forçada, tamanho limitado e qualquer
  /// caractere fora do conjunto bloqueado já na digitação.
  static List<TextInputFormatter> get inputFormatters => <TextInputFormatter>[
        const _LowercaseFormatter(),
        FilteringTextInputFormatter.allow(_allowedChars),
        LengthLimitingTextInputFormatter(maxLength),
      ];

  /// Validador para o `TextFormField`. Retorna `null` quando válido.
  static String? validate(String? raw) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) return AppStrings.authErrorUsernameEmpty;
    if (value.length < minLength) return AppStrings.authErrorUsernameTooShort;
    if (value.length > maxLength) return AppStrings.authErrorUsernameTooLong;
    if (!_validFormat.hasMatch(value)) {
      return AppStrings.authErrorUsernameInvalidChars;
    }
    return null;
  }
}

/// Converte a digitação para minúsculo sem descartar o caractere — se
/// deixássemos o `FilteringTextInputFormatter` resolver, "João" viraria "o"
/// em vez de "joo".
class _LowercaseFormatter extends TextInputFormatter {
  const _LowercaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // `toLowerCase()` preserva o tamanho da string, então a seleção do
    // cursor continua válida.
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}
