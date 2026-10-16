import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'core/firebase/admin_firebase_initializer.dart';
import 'core/routing/admin_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(
    ProviderScope(
      child: CompyAdminBootstrap(
        initialize: AdminFirebaseInitializer.initialize,
        // Lido antes do primeiro frame: as telas de carregamento trocam a URL.
        initialLocation: adminInitialLocationFromUrl(Uri.base),
      ),
    ),
  );
}
