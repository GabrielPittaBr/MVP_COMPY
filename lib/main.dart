// COMPY — Ponto de entrada do aplicativo.
// O bootstrap completo (Firebase + ProviderScope + GoRouter) é configurado
// no commit 3. Este arquivo serve como esqueleto inicial do scaffold.

import 'package:flutter/material.dart';

void main() {
  runApp(const _BootstrapPlaceholder());
}

class _BootstrapPlaceholder extends StatelessWidget {
  const _BootstrapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'COMPY',
      home: Scaffold(
        body: Center(child: Text('COMPY — bootstrap em construção')),
      ),
    );
  }
}
