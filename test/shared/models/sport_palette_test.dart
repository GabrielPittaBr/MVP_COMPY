import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/shared/models/sport.dart';

/// Contraste de [color] sobre o branco, pela fórmula do WCAG 2.x.
double contrasteComBranco(Color color) =>
    1.05 / (color.computeLuminance() + 0.05);

void main() {
  // Modalidades que entraram na issue 30.
  const novos = <Sport>[
    Sport.handebol,
    Sport.tenis,
    Sport.padel,
    Sport.futebolDeAreia,
    Sport.voleiDePraia,
    Sport.futevolei,
    Sport.beachTennis,
    Sport.skate,
  ];
  const deAreia = <Sport>[
    Sport.futebolDeAreia,
    Sport.voleiDePraia,
    Sport.futevolei,
    Sport.beachTennis,
  ];

  test('o enum tem 16 modalidades, com a fileira de areia inteira', () {
    expect(Sport.values, hasLength(16));
    // As grades têm 4 colunas: a terceira fileira é só de esportes de areia.
    expect(Sport.values.sublist(8, 12), deAreia);
  });

  test('cada esporte novo tem contraste de pelo menos 3:1 com o branco', () {
    // WCAG 1.4.11: a cor desenha o ícone e o pin do mapa sobre fundo branco.
    for (final sport in novos) {
      expect(
        contrasteComBranco(sport.color),
        greaterThanOrEqualTo(3),
        reason: '${sport.label} (${sport.color})',
      );
    }
  });

  test('esportes de areia têm cores diferentes entre si e do vôlei', () {
    final cores = <Color>{for (final sport in deAreia) sport.color};
    expect(cores, hasLength(deAreia.length));
    expect(cores, isNot(contains(Sport.volei.color)));
  });

  test('o ícone de cada esporte novo não é usado por nenhum outro', () {
    for (final sport in novos) {
      final outros =
          Sport.values.where((s) => s != sport && s.icon == sport.icon);
      expect(outros, isEmpty,
          reason: '${sport.label} repete o ícone de $outros');
    }
  });

  test('os ícones desenhados vêm da fonte registrada no pubspec', () {
    final desenhados = novos
        .where((s) => s.icon.fontFamily == 'CompySportIcons')
        .map((s) => s.label);
    expect(desenhados, hasLength(6));

    // Fonte ausente ou fora do pubspec vira quadradinho vazio, sem erro.
    expect(File('assets/fonts/CompySportIcons.otf').existsSync(), isTrue);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('assets/fonts/CompySportIcons.otf'),
    );
  });

  test('cada esporte novo tem capa própria, no padrão das demais', () {
    final capas = Sport.values.map((s) => s.banner).toList();
    for (final sport in novos) {
      expect(sport.banner, startsWith('https://images.unsplash.com/photo-'));
      expect(sport.banner, endsWith('?w=600'));
      expect(
        capas.where((b) => b == sport.banner),
        hasLength(1),
        reason: '${sport.label} divide a capa com outro esporte',
      );
    }
  });
}
