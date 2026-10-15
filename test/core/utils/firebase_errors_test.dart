import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/utils/firebase_errors.dart';

FirebaseException _firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  group('FirebaseErrors.isOffline', () {
    for (final code in <String>[
      'unavailable',
      'deadline-exceeded',
      'network-request-failed',
    ]) {
      test('$code é falta de conexão', () {
        expect(FirebaseErrors.isOffline(_firestoreError(code)), isTrue);
      });
    }

    test('outros códigos do Firebase não são falta de conexão', () {
      expect(
        FirebaseErrors.isOffline(_firestoreError('permission-denied')),
        isFalse,
      );
    });

    test('erros que não vêm do Firebase não são falta de conexão', () {
      expect(FirebaseErrors.isOffline(StateError('falha')), isFalse);
    });
  });
}
