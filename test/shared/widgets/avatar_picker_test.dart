import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mvp_compy/core/constants/app_assets.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/shared/widgets/avatar_picker.dart';

void main() {
  Widget host(AvatarPicker picker) =>
      MaterialApp(home: Scaffold(body: Center(child: picker)));

  testWidgets('sem foto: mostra a inicial e só oferece adicionar',
      (WidgetTester tester) async {
    await tester.pumpWidget(host(AvatarPicker(
      name: 'gabriel',
      // O placeholder do placehold.co é o "sem foto" que o perfil guarda.
      photoUrl: AppAssets.avatar('gabriel'),
      onPicked: (_) {},
      onRemoved: () {},
    )));

    expect(find.text('G'), findsOneWidget);
    expect(find.text(AppStrings.photoAdd), findsOneWidget);
    expect(find.text(AppStrings.photoRemove), findsNothing);
  });

  testWidgets('com foto: oferece trocar e remover', (WidgetTester tester) async {
    var removed = false;
    await tester.pumpWidget(host(AvatarPicker(
      name: 'gabriel',
      photoBytes: img.encodePng(img.Image(width: 4, height: 4)),
      onPicked: (_) {},
      onRemoved: () => removed = true,
    )));

    expect(find.text('G'), findsNothing);
    expect(find.text(AppStrings.photoChange), findsOneWidget);

    await tester.tap(find.text(AppStrings.photoRemove));
    expect(removed, isTrue);
  });

  testWidgets('enviando: botões travados', (WidgetTester tester) async {
    var removed = false;
    await tester.pumpWidget(host(AvatarPicker(
      name: 'gabriel',
      photoBytes: img.encodePng(img.Image(width: 4, height: 4)),
      busy: true,
      onPicked: (_) {},
      onRemoved: () => removed = true,
    )));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text(AppStrings.photoRemove));
    expect(removed, isFalse);
  });
}
