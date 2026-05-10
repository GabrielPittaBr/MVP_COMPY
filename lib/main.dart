// COMPY — Ponto de entrada do aplicativo.
//
// Bootstrap:
// 1. Garante widgets binding;
// 2. Tenta inicializar Firebase (silencioso quando firebase_options.dart
//    ainda não foi gerado — o app continua rodando com mocks);
// 3. Roda o app dentro de um ProviderScope (Riverpod).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.instance.ensureInitialized();
  runApp(const ProviderScope(child: CompyApp()));
}
