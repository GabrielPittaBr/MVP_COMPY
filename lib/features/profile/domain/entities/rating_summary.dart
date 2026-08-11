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

  /// Sem nota nenhuma a média vale 0 — e 0 exibido como nota é mentira.
  /// Mesmo contrato de `SportPlace.hasRatings`, que já resolve isso na tela
  /// de detalhes do local.
  bool get hasRatings => count > 0;

  @override
  List<Object?> get props => <Object?>[average, count, breakdown];
}
