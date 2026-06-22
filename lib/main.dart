// COMPY — Ponto de entrada do aplicativo.
//
// Bootstrap:
// 1. Garante widgets binding;
// 2. Carrega locale pt_BR para o `intl` (datas em português);
// 3. Tenta inicializar Firebase de forma defensiva (segue rodando com
//    mocks quando `firebase_options.dart` ainda não foi gerado);
// 4. Faz login anônimo automático se não houver usuário logado;
// 5. Roda o app dentro de um ProviderScope (Riverpod).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  await FirebaseService.instance.ensureInitialized();

  // Login anônimo automático para garantir UID válido no creator de eventos.
  if (FirebaseService.instance.isInitialized) {
    try {
      final auth = FirebaseService.instance.auth;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
        if (kDebugMode) {
          debugPrint('[main] Login anônimo: ${auth.currentUser?.uid}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[main] Erro no login anônimo: $e');
      }
    }
  }

  runApp(const ProviderScope(child: CompyApp()));
}
