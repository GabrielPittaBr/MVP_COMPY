import 'package:firebase_core/firebase_core.dart';

/// Classificação de erros do Firebase que indicam falta de conexão.
///
/// Criar evento e compartilhar local leem o local online numa transação, que
/// não entra na fila offline do Firestore: sem rede, a escrita falha. Os dois
/// fluxos usam este helper para decidir quando essa falha vira a mensagem de
/// "precisa de conexão", em vez de um erro genérico.
abstract final class FirebaseErrors {
  static const Set<String> _offlineCodes = <String>{
    'unavailable',
    'deadline-exceeded',
    'network-request-failed',
  };

  /// `true` quando [error] é um [FirebaseException] causado pela rede.
  static bool isOffline(Object error) =>
      error is FirebaseException && _offlineCodes.contains(error.code);
}
