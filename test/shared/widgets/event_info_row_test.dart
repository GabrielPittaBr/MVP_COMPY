import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/core/constants/app_strings.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/widgets/event_info_row.dart';

void main() {
  testWidgets('leitor de tela recebe o contexto do nível uma única vez',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: EventInfoRow.skillLevel(level: SkillLevel.todos),
      )));
      expect(find.text(AppStrings.eventAllSkillLevels), findsOneWidget);
      expect(
          find.bySemanticsLabel(
              '${AppStrings.eventSkillLevel}: ${AppStrings.eventAllSkillLevels}'),
          findsOneWidget);
      expect(
          find.bySemanticsLabel(AppStrings.eventAllSkillLevels), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('nível e data quebram linha sem cortes com texto grande',
      (tester) async {
    tester.view.physicalSize = const Size(280, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            EventInfoRow.skillLevel(level: SkillLevel.todos),
            const SizedBox(height: 8),
            const EventInfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Quarta-feira, 19:00 – 20:00'),
          ]),
        ),
      ),
    )));
    for (final text in [
      find.text(AppStrings.eventAllSkillLevels),
      find.text('Quarta-feira, 19:00 – 20:00')
    ]) {
      expect(tester.getSize(text).height, greaterThan(24));
      expect(tester.widget<Text>(text).maxLines, isNull);
    }
    expect(tester.takeException(), isNull);
  });
}
