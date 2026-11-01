import 'package:flutter/widgets.dart';

/// Ícones das modalidades que não têm equivalente nos Material Icons.
///
/// Vêm da fonte `CompySportIcons` (`assets/fonts/`), gerada por
/// `tools/sport-icons/build_font.py` a partir de desenhos na grade 24×24 dos
/// Material Icons. Ser fonte, e não SVG, mantém `Sport.icon` como [IconData]:
/// os widgets que desenham o ícone do esporte não precisam saber de onde ele
/// vem.
///
/// Os code points são os do gerador e não mudam: trocar um deles aqui sem
/// regerar a fonte mostra o glifo errado, ou nenhum.
abstract final class CompySportIcons {
  static const String _family = 'CompySportIcons';

  /// Raquete furada, bola e a onda que marca os esportes de areia.
  static const IconData beachTennis = IconData(0xe800, fontFamily: _family);

  /// Bola de futebol sobre a rede, com a onda de areia.
  static const IconData futevolei = IconData(0xe801, fontFamily: _family);

  /// Bola de vôlei com a onda de areia.
  static const IconData voleiDePraia = IconData(0xe802, fontFamily: _family);

  /// Bola de futebol com a onda de areia.
  static const IconData futebolDeAreia = IconData(0xe803, fontFamily: _family);

  /// Duas raquetes furadas cruzadas e a bola.
  static const IconData padel = IconData(0xe804, fontFamily: _family);

  /// Bola de tênis com as duas costuras.
  static const IconData tenis = IconData(0xe805, fontFamily: _family);
}
