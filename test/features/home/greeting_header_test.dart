import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/features/home/presentation/widgets/greeting_header.dart';

void main() {
  /// O avatar é carregado por rede e no ambiente de teste isso falha sempre.
  /// Silenciar só a biblioteca de imagem mantém overflow e assert de layout
  /// ainda quebrando o teste, que é o que interessa aqui.
  void ignoreImageErrors() {
    final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.library == 'image resource service') return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  Future<void> pumpHeader(
    WidgetTester tester, {
    required VoidCallback onAvatarTap,
    required VoidCallback onSettingsTap,
  }) async {
    ignoreImageErrors();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GreetingHeader(
            userName: 'Gabriel',
            onAvatarTap: onAvatarTap,
            onSettingsTap: onSettingsTap,
          ),
        ),
      ),
    );
  }

  group('GreetingHeader', () {
    testWidgets('o avatar leva para o perfil', (tester) async {
      var avatarTaps = 0;
      var settingsTaps = 0;
      await pumpHeader(
        tester,
        onAvatarTap: () => avatarTaps++,
        onSettingsTap: () => settingsTaps++,
      );

      await tester.tap(find.bySemanticsLabel(AppStrings.navProfile));
      await tester.pump();

      expect(avatarTaps, 1);
      expect(settingsTaps, 0);
    });

    testWidgets('a engrenagem abre as configurações', (tester) async {
      var avatarTaps = 0;
      var settingsTaps = 0;
      await pumpHeader(
        tester,
        onAvatarTap: () => avatarTaps++,
        onSettingsTap: () => settingsTaps++,
      );

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump();

      expect(settingsTaps, 1);
      expect(avatarTaps, 0);
    });

    testWidgets('continua saudando pelo nome', (tester) async {
      await pumpHeader(tester, onAvatarTap: () {}, onSettingsTap: () {});
      expect(
        find.text('${AppStrings.homeGreetingPrefix} Gabriel'),
        findsOneWidget,
      );
    });
  });
}
