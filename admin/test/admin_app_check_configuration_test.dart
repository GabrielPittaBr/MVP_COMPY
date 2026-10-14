import 'package:compy_admin/core/firebase/admin_app_check_configuration.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminAppCheckConfiguration', () {
    test('release usa reCAPTCHA v3 e exige site key externa', () {
      final provider = AdminAppCheckConfiguration.providerFor(
        releaseMode: true,
        hostname: 'compy-admin.web.app',
        recaptchaSiteKey: ' public-site-key ',
        debugToken: '',
      );

      expect(provider, isA<ReCaptchaV3Provider>());
      expect(provider.siteKey, 'public-site-key');
      expect(
        () => AdminAppCheckConfiguration.providerFor(
          releaseMode: true,
          hostname: 'compy-admin.web.app',
          recaptchaSiteKey: '',
          debugToken: '',
        ),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(AdminAppCheckConfiguration.recaptchaSiteKeyDefine),
        )),
      );
    });

    test('debug exige site key, token externo e aceita somente hosts loopback', () {
      final provider = AdminAppCheckConfiguration.providerFor(
        releaseMode: false,
        hostname: 'LOCALHOST',
        recaptchaSiteKey: ' local-site-key ',
        debugToken: 'registered-debug-token',
      );

      expect(provider, isA<ReCaptchaV3Provider>());
      expect(provider.siteKey, 'local-site-key');
      expect(
        () => AdminAppCheckConfiguration.providerFor(
          releaseMode: false,
          hostname: 'localhost',
          recaptchaSiteKey: '',
          debugToken: ' ',
        ),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(AdminAppCheckConfiguration.debugTokenDefine),
        )),
      );
      expect(
        () => AdminAppCheckConfiguration.providerFor(
          releaseMode: false,
          hostname: 'admin.example.com',
          recaptchaSiteKey: '',
          debugToken: 'registered-debug-token',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('generate delega a emissão de token ao SDK web', () {
      final provider = AdminAppCheckConfiguration.providerFor(
        releaseMode: false,
        hostname: '127.0.0.1',
        recaptchaSiteKey: 'local-site-key',
        debugToken: AdminAppCheckConfiguration.generateDebugTokenValue,
      );

      expect(provider, isA<ReCaptchaV3Provider>());
    });
  });
}
