import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/gestor_router.dart';
import 'core/theme/gestor_theme.dart';

class GestorApp extends ConsumerWidget {
  const GestorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    title: 'Painel do Local · COMPY',
    theme: GestorTheme.light,
    routerConfig: ref.watch(routerProvider),
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
  );
}
