import 'package:intl/intl.dart';

/// Média de avaliação com vírgula decimal: "4,8", nunca "4.8".
abstract final class RatingFormat {
  static final NumberFormat _average = NumberFormat('0.0', 'pt_BR');

  static String average(double value) => _average.format(value);
}
