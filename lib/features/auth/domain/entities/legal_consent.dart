import 'package:equatable/equatable.dart';

/// O que o cadastro e a tela de aceite enviam para registrar o aceite dos
/// Termos (chore/lgpd): a data de nascimento declarada e, quando a Google
/// Play informar, a faixa etária dela.
class LegalConsentInput extends Equatable {
  const LegalConsentInput({
    required this.birthDate,
    this.ageSignalLower,
    this.ageSignalUpper,
  });

  final DateTime birthDate;
  final int? ageSignalLower;
  final int? ageSignalUpper;

  bool get hasAgeSignal => ageSignalLower != null || ageSignalUpper != null;

  @override
  List<Object?> get props => <Object?>[birthDate, ageSignalLower, ageSignalUpper];
}

/// A pessoa tem menos de 16 anos: pela data declarada ou pela Google Play.
class UnderageException implements Exception {
  const UnderageException();
  @override
  String toString() => 'UnderageException';
}
