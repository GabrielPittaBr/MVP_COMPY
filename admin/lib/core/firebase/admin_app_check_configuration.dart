import 'package:firebase_app_check/firebase_app_check.dart';

/// Resolves the App Check provider from external build configuration.
///
/// This panel's pinned FlutterFire 0.3 API does not expose a typed Web debug
/// provider. The official Firebase Web debug-token global is set immediately
/// before activating App Check; the ReCaptcha provider remains the release
/// provider and is also required by the FlutterFire activation API.
///
/// A local debug token is deliberately required rather than silently falling
/// back to an unattested provider. Use the literal `generate` once to ask the
/// Firebase Web SDK to generate a token, then register it and pass that token
/// through the same external define on subsequent runs.
abstract final class AdminAppCheckConfiguration {
  static const String recaptchaSiteKeyDefine = 'COMPY_RECAPTCHA_V3_SITE_KEY';
  static const String debugTokenDefine = 'COMPY_APPCHECK_DEBUG_TOKEN';
  static const String generateDebugTokenValue = 'generate';

  static ReCaptchaV3Provider providerFor({
    required bool releaseMode,
    required String hostname,
    required String recaptchaSiteKey,
    required String debugToken,
  }) {
    if (releaseMode) {
      final siteKey = recaptchaSiteKey.trim();
      if (siteKey.isEmpty) {
        throw StateError(
          'Defina $recaptchaSiteKeyDefine com a site key reCAPTCHA v3 antes '
          'de compilar ou executar o Painel Administrativo em release.',
        );
      }
      return ReCaptchaV3Provider(siteKey);
    }

    if (!_isLoopbackHost(hostname)) {
      throw StateError(
        'O provedor App Check de debug só pode ser usado em localhost, '
        '127.0.0.1 ou ::1.',
      );
    }

    final token = debugToken.trim();
    if (token.isEmpty) {
      throw StateError(
        'Defina $debugTokenDefine externamente. Use `generate` na primeira '
        'execução local para gerar um token e registrá-lo no Firebase Console.',
      );
    }

    final siteKey = recaptchaSiteKey.trim();
    if (siteKey.isEmpty) {
      throw StateError(
        'Defina $recaptchaSiteKeyDefine externamente para ativar App Check '
        'antes de iniciar o painel local.',
      );
    }

    return ReCaptchaV3Provider(siteKey);
  }

  static bool _isLoopbackHost(String hostname) {
    final normalized = hostname.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }
}
