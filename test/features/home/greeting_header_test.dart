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
    VoidCallback? onNotificationsTap,
    int unreadNotifications = 0,
  }) async {
    ignoreImageErrors();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GreetingHeader(
            userName: 'Gabriel',
            onAvatarTap: onAvatarTap,
            onSettingsTap: onSettingsTap,
            onNotificationsTap: onNotificationsTap ?? () {},
            unreadNotifications: unreadNotifications,
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

    testWidgets('o sino abre a central e mostra as não lidas', (tester) async {
      var taps = 0;
      await pumpHeader(
        tester,
        onAvatarTap: () {},
        onSettingsTap: () {},
        onNotificationsTap: () => taps++,
        unreadNotifications: 2,
      );

      expect(find.text('2'), findsOneWidget);
      expect(
        find.byTooltip(AppStrings.notificationsBellSemantics(2)),
        findsOneWidget,
      );
      expect(AppStrings.notificationsBellSemantics(2),
          'Notificações, 2 não lidas');
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a partir de 10 o badge mostra "9+"', (tester) async {
      await pumpHeader(
        tester,
        onAvatarTap: () {},
        onSettingsTap: () {},
        unreadNotifications: 12,
      );

      expect(find.text('9+'), findsOneWidget);
    });

    testWidgets('sem não lidas, nada de badge', (tester) async {
      await pumpHeader(tester, onAvatarTap: () {}, onSettingsTap: () {});

      expect(find.text('0'), findsNothing);
      expect(
        find.byTooltip(AppStrings.notificationsTitle),
        findsOneWidget,
      );
    });

    testWidgets('"COMPY" continua no centro com o sino', (tester) async {
      await pumpHeader(
        tester,
        onAvatarTap: () {},
        onSettingsTap: () {},
        unreadNotifications: 3,
      );

      final titulo = tester.getCenter(find.text(AppStrings.appName));
      final tela = tester.getCenter(find.byType(Scaffold));
      expect(titulo.dx, closeTo(tela.dx, 0.5));
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
