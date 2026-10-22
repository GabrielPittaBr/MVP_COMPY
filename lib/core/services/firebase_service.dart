import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../constants/app_flags.dart';

/// Inicializa Firebase Core e expõe os serviços compartilhados do app.
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
      _initialized = true;
      if (kUseFirebaseEmulators) {
        await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
        FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
        // As callables do app ficam em southamerica-east1 (tarefa 14).
        FirebaseFunctions.instanceFor(region: kFunctionsRegion)
            .useFunctionsEmulator('localhost', 5001);
      }
      // Na web o App Check exigiria um provider reCAPTCHA; sem ele o
      // `activate()` só falha. A imposição está desligada no Console (ver
      // docs/checklist-publicacao.md), então pular não bloqueia nada.
      if (!kIsWeb) {
        try {
          await FirebaseAppCheck.instance.activate(
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
          );
        } catch (e) {
          if (kDebugMode) debugPrint('[FirebaseService] App Check: $e');
        }
      }
      if (kDebugMode) {
        debugPrint('[FirebaseService] Inicialização bem-sucedida.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirebaseService] Erro ao inicializar Firebase: $e');
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
