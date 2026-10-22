import 'package:equatable/equatable.dart';

/// Alvos que recebem nota (o mesmo `targetType` da callable e de
/// `ratingSummaries/{targetType}_{targetId}`).
enum RatingTargetType { event, place, user }

/// O que se avalia: o tipo e o id do alvo.
typedef RatingTarget = ({RatingTargetType type, String id});

/// Média e distribuição das notas de um alvo (perfil, Local Esportivo ou
/// evento encerrado). Nenhum comentário passa por aqui (D13).
///
/// `breakdown` mapeia estrelas (1..5) para a fração de notas naquela faixa.
class RatingSummary extends Equatable {
  const RatingSummary({
    required this.average,
    required this.count,
    required this.breakdown,
  });

  /// A partir do agregado de `ratingSummaries` (tarefa 14): a callable só
  /// soma contagem, soma das estrelas e contagem por estrela, e a média sai
  /// daqui (`soma / contagem`).
  factory RatingSummary.fromAggregate({
    required int count,
    required int sum,
    required Map<int, int> starCounts,
  }) {
    if (count <= 0) return empty;
    return RatingSummary(
      average: sum / count,
      count: count,
      breakdown: <int, double>{
        for (var stars = 1; stars <= 5; stars++)
          stars: (starCounts[stars] ?? 0) / count,
      },
    );
  }

  static const RatingSummary empty =
      RatingSummary(average: 0, count: 0, breakdown: <int, double>{});

  final double average;
  final int count;
  final Map<int, double> breakdown;

  /// Sem nota nenhuma a média vale 0 — e 0 exibido como nota é mentira.
  bool get hasRatings => count > 0;

  @override
  List<Object?> get props => <Object?>[average, count, breakdown];
}
