import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Faixa etária que a Google Play informa (Play Age Signals API).
///
/// [upper] nulo é a faixa aberta do topo (18+). O ECA Digital (arts. 12–14)
/// manda receber esse sinal da loja; o app o usa só para adequar a
/// experiência à idade, como pedem os termos da API.
class AgeSignal {
  const AgeSignal({this.lower, this.upper});

  final int? lower;
  final int? upper;

  /// A Play diz que a pessoa tem menos de [age] anos.
  bool isBelow(int age) => upper != null && upper! < age;
}

/// Ponte com `MainActivity.kt` (canal `br.com.compy.app/age_signals`).
///
/// Nunca lança: fora do Android, instalado fora da Play (APK do GitHub), com a
/// Play desatualizada ou sem o usuário aceitar compartilhar, devolve `null` e
/// o app segue com a data de nascimento declarada.
class AgeSignalsService {
  const AgeSignalsService();

  static const MethodChannel _channel =
      MethodChannel('br.com.compy.app/age_signals');

  Future<AgeSignal?> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final Map<String, Object?>? result = await _channel
          .invokeMapMethod<String, Object?>('check')
          .timeout(const Duration(seconds: 15));
      if (result == null || result['status'] != 'shared') return null;
      final int? lower = result['ageLower'] as int?;
      final int? upper = result['ageUpper'] as int?;
      if (lower == null && upper == null) return null;
      return AgeSignal(lower: lower, upper: upper);
    } catch (error) {
      debugPrint('[AgeSignals] consulta indisponível: $error');
      return null;
    }
  }
}

final ageSignalsServiceProvider =
    Provider<AgeSignalsService>((_) => const AgeSignalsService());
