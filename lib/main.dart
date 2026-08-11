// COMPY — Ponto de entrada do aplicativo.
//
// Bootstrap:
// 1. Garante widgets binding;
// 2. Carrega locale pt_BR para o `intl` (datas em português);
// 3. Tenta inicializar Firebase de forma defensiva (segue rodando com
//    mocks quando `firebase_options.dart` ainda não foi gerado);
// 4. Roda o app dentro de um ProviderScope (Riverpod).
//
// Nota: o login anônimo automático foi removido. O gate de autenticação
// é tratado pelo GoRouter (`redirect` em `app_router.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  await FirebaseService.instance.ensureInitialized();
  runApp(const ProviderScope(child: CompyApp()));
}
