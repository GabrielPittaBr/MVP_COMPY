import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'admin_app_check_configuration.dart';
import 'admin_app_check_debug_token.dart';

abstract final class AdminFirebaseInitializer {
  static Future<void> initialize() async {
    if (!kIsWeb) {
      throw StateError('O Painel Administrativo do COMPY deve ser executado na Web.');
    }

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: CompyAdminFirebaseOptions.currentPlatform,
      );
    }

    final debugToken = const String.fromEnvironment(
      AdminAppCheckConfiguration.debugTokenDefine,
    );
    final provider = AdminAppCheckConfiguration.providerFor(
      releaseMode: kReleaseMode,
      hostname: Uri.base.host,
      recaptchaSiteKey: const String.fromEnvironment(
        AdminAppCheckConfiguration.recaptchaSiteKeyDefine,
      ),
      debugToken: debugToken,
    );
    if (!kReleaseMode) configureFirebaseAppCheckDebugToken(debugToken);
    await FirebaseAppCheck.instance.activate(webProvider: provider);
  }
}
