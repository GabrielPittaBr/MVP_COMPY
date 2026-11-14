import 'package:flutter/services.dart';

import '../constants/app_strings.dart';

/// Idade mínima e maioridade (chore/lgpd; ECA Digital).
///
/// O COMPY é para quem tem 16 anos ou mais. Quem tem 16 ou 17 entra com as
/// proteções de adolescente (ver `firestore.rules`, `canTalk`). A data de
/// nascimento é digitada como `dd/mm/aaaa`: num calendário, chegar até 2008
/// custa dezenas de toques.
abstract final class AgeRules {
  static const int minimumAge = 16;
  static const int adultAge = 18;

  static final RegExp _pattern = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

  /// Data digitada, ou `null` quando não é uma data real (31/02, 00/13...).
  static DateTime? parseBirthDate(String? text) {
    final Match? match = _pattern.firstMatch((text ?? '').trim());
    if (match == null) return null;
    final int day = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int year = int.parse(match.group(3)!);
    final DateTime date = DateTime.utc(year, month, day);
    // `DateTime` normaliza 31/02 para 03/03: se mudou, a data não existe.
    if (date.day != day || date.month != month || date.year != year) {
      return null;
    }
    return date;
  }

  /// Idade completa em [today].
  static int ageOn(DateTime birthDate, DateTime today) {
    int age = today.year - birthDate.year;
    final bool hadBirthday = today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hadBirthday) age--;
    return age;
  }

  /// O 18º aniversário. Quem nasceu em 29/02 faz 18 em 01/03.
  static DateTime adultAt(DateTime birthDate) =>
      DateTime.utc(birthDate.year + adultAge, birthDate.month, birthDate.day);

  static bool isMinorOn(DateTime birthDate, DateTime today) =>
      ageOn(birthDate, today) < adultAge;

  /// Mensagem de erro para o campo, ou `null` quando a data serve.
  ///
  /// Com [enforceMinimum] `false`, só a forma da data é conferida: depois do
  /// login com Google a conta já existe, e quem tem menos de 16 precisa
  /// conseguir enviar para que o app apague essa conta.
  static String? validate(String? text, DateTime today, {bool enforceMinimum = true}) {
    final DateTime? birthDate = parseBirthDate(text);
    if (birthDate == null) return AppStrings.ageInvalidFormat;
    if (birthDate.year < 1900 || birthDate.isAfter(today)) {
      return AppStrings.ageInvalidDate;
    }
    if (enforceMinimum && ageOn(birthDate, today) < minimumAge) {
      return AppStrings.ageUnderMinimum;
    }
    return null;
  }

  /// Só dígitos, com as barras entrando sozinhas: `01052008` → `01/05/2008`.
  static final List<TextInputFormatter> inputFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(8),
    const _BirthDateFormatter(),
  ];
}

class _BirthDateFormatter extends TextInputFormatter {
  const _BirthDateFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text;
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }
    final String text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
