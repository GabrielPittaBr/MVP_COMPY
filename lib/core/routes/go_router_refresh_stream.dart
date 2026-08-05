import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adaptador que converte um [Stream] em [ChangeNotifier] para uso como
/// `refreshListenable` no GoRouter.
///
/// Descarta o valor emitido — o router só precisa saber *que* algo mudou,
/// não *o quê* mudou (a lógica fica no `redirect`).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  void notify() => notifyListeners();

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
