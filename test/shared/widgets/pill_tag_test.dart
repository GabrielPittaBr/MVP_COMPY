import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/shared/widgets/pill_tag.dart';

void main() {
  // No E2E da tarefa 14 as tags "Organizador", "Você" e "Opcional" ocupavam a
  // linha inteira: um Container com `alignment` dentro de um Wrap estica até
  // a largura máxima que recebe.
  testWidgets('dentro de um Wrap, a tag tem a largura do texto',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: Wrap(
            children: <Widget>[
              Text('Ana Criadora'),
              PillTag(label: 'Organizador'),
            ],
          ),
        ),
      ),
    ));

    final tag = tester.getSize(find.byType(PillTag));
    final texto = tester.getSize(find.text('Organizador'));
    // Texto mais o respiro dos dois lados (40% da altura cada).
    expect(tag.width, closeTo(texto.width + 2 * 22 * 0.4, 0.01));
    expect(tag.height, 22);
  });
}
