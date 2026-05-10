import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_flags.dart';

/// Inicializa o Firebase de forma defensiva.
///
/// Em desenvolvimento (`kUseFirebaseRepos == false`) tentamos chamar
/// `Firebase.initializeApp()` mesmo assim, mas qualquer falha (por exemplo,
/// `firebase_options.dart` ausente) é absorvida — o app segue funcionando
/// 100% via mocks. Quando o time configurar o projeto via
/// `flutterfire configure`, basta ligar a flag.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (e) {
      // Ausência de firebase_options é esperada antes do flutterfire configure.
      if (kDebugMode) {
        debugPrint(
          '[FirebaseService] Inicialização ignorada (modo mock): $e',
        );
      }
      _initialized = false;
    }
  }

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
}

/// Atalho para checagem rápida de modo nas Datasources.
bool get firebaseEnabled =>
    kUseFirebaseRepos && FirebaseService.instance.isInitialized;
