import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../constants/app_flags.dart';

/// Inicializa o Firebase de forma defensiva.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[FirebaseService] Inicialização bem-sucedida.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[FirebaseService] Erro ao inicializar Firebase (usando mocks): $e',
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
