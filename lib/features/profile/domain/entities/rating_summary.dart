import 'package:equatable/equatable.dart';

/// Distribuição de avaliações públicas no perfil (RF06 — exibição).
///
/// `breakdown` mapeia estrelas (1..5) para a porcentagem de avaliações
/// recebidas naquela faixa.
class RatingSummary extends Equatable {
  const RatingSummary({
    required this.average,
    required this.count,
    required this.breakdown,
  });

  final double average;
  final int count;
  final Map<int, double> breakdown;

  @override
  List<Object?> get props => <Object?>[average, count, breakdown];
}
