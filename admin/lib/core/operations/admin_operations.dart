import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';

/// Identificador idempotente das operações administrativas (UUID v4).
///
/// O painel reenvia o mesmo id quando não sabe se a chamada anterior chegou
/// ao fim; o servidor usa o id para não repetir nem duplicar a operação.
String newAdminOperationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Motivo como o servidor o registra: sem espaços repetidos nas pontas ou
/// no meio.
String normalizeAdminReason(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Mesmo limite das Callables: de 10 a 500 caracteres após normalização.
bool isValidAdminReason(String normalized) =>
    normalized.length >= 10 && normalized.length <= 500;

/// Falha em que repetir não adianta: o servidor recusou ou já registrou o
/// desfecho, então a próxima tentativa recebe um novo id. Nas demais, o id
/// é reaproveitado para a repetição não duplicar a operação.
bool isTerminalAdminOperationFailure(Object error) {
  if (error is! FirebaseFunctionsException) return false;
  if (error.details is Map &&
      (error.details as Map)['operationStatus'] == 'failed') {
    return true;
  }
  return const <String>{
    'invalid-argument',
    'not-found',
    'permission-denied',
    'failed-precondition',
    'already-exists',
  }.contains(error.code);
}
