import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'core/firebase/admin_firebase_initializer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(
    ProviderScope(
      child: CompyAdminBootstrap(
        initialize: AdminFirebaseInitializer.initialize,
      ),
    ),
  );
}
