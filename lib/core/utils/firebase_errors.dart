import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Classificação de erros do Firebase que indicam falta de conexão.
///
/// Criar evento e compartilhar local leem o local online numa transação, que
/// não entra na fila offline do Firestore: sem rede, a escrita falha. Os dois
/// fluxos usam este helper para decidir quando essa falha vira a mensagem de
/// "precisa de conexão", em vez de um erro genérico.
abstract final class FirebaseErrors {
  /// Não registra mensagem/payload: podem conter dados pessoais ou tokens.
  static void logFailure(String operation, Object error, StackTrace stack) {
    final details = error is FirebaseException
        ? 'plugin=${error.plugin} code=${error.code}'
        : 'type=${error.runtimeType}';
    debugPrint('[$operation] $details');
    debugPrintStack(stackTrace: stack);
  }

  static const Set<String> _offlineCodes = <String>{
    'unavailable',
    'deadline-exceeded',
    'network-request-failed',
  };

  /// `true` quando [error] é um [FirebaseException] causado pela rede.
  static bool isOffline(Object error) =>
      error is FirebaseException && _offlineCodes.contains(error.code);
}
