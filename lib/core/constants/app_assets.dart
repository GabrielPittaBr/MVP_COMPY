/// URLs de placeholders de imagens usadas em todo o app (avatares,
/// banners de evento, fotos de galeria). Trocar por assets reais ou
/// uploads do usuário quando o backend estiver completo.
abstract final class AppAssets {
  /// Gera URL de avatar placeholder com a inicial do nome.
  static String avatar(String seed, {int size = 100}) =>
      'https://placehold.co/${size}x$size/png?text=${Uri.encodeComponent(seed.isNotEmpty ? seed[0].toUpperCase() : '?')}';

  /// Imagens de banner para eventos / locais por modalidade.
  static const String soccerBanner =
      'https://images.unsplash.com/photo-1551958219-acbc608c6377?w=600';
  static const String basketballBanner =
      'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=600';
  static const String volleyballBanner =
      'https://images.unsplash.com/photo-1592656094267-764a45160876?w=600';
  static const String tableTennisBanner =
      'https://images.unsplash.com/photo-1611251135345-18c56206b863?w=600';
  static const String genericSportBanner =
      'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=600';
  static const String runningBanner =
      'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=600';
  static const String cyclingBanner =
      'https://images.unsplash.com/photo-1541625602330-2277a4c46182?w=600';
  static const String walkingBanner =
      'https://images.unsplash.com/photo-1483721310020-03333e577078?w=600';

  /// Foto de galeria placeholder (um time em campo).
  static const String galleryTeamPhoto =
      'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=600';

  // ------- Carrossel da tela de login -------

  /// 4 fotos esportivas para o carrossel do login (telas largas: w=800).
  static const List<String> loginCarousel = <String>[
    'https://images.unsplash.com/photo-1551958219-acbc608c6377?w=800', // futebol
    'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=800', // basquete
    'https://images.unsplash.com/photo-1592656094267-764a45160876?w=800', // vôlei
    'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=800', // esporte geral
  ];

  /// Caminho local da logo (PNG fornecido pelo usuário).
  static const String logoAsset = 'assets/images/logo.png';
}
