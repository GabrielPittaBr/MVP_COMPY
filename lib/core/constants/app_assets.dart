/// URLs de placeholders de imagens usadas em todo o app (avatares,
/// banners de evento, fotos de galeria). Trocar por assets reais ou
/// uploads do usuário quando o backend estiver completo.
abstract final class AppAssets {
  /// Gera URL de avatar placeholder com a inicial do nome.
  static String avatar(String seed, {int size = 100}) =>
      'https://placehold.co/${size}x$size/png?text=${Uri.encodeComponent(seed.isNotEmpty ? seed[0].toUpperCase() : '?')}';

  /// `true` quando [url] não é foto de verdade: vazia ou o placeholder de
  /// [avatar], que é o que o perfil guarda quando o usuário fica sem foto.
  static bool isPlaceholderAvatar(String? url) =>
      url == null || url.isEmpty || url.startsWith('https://placehold.co/');

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

  // Capas das modalidades da issue 30. Todas sob a Unsplash License, que
  // dispensa atribuição; a origem fica registrada mesmo assim, para conferir
  // a licença e citar no artigo. Escolhidas pelo recorte no círculo de 72 px
  // da Home, que é onde a foto aparece menor.

  /// Raquete de beach tennis e bola na areia, com a rede ao fundo.
  /// Yohann Fernandes (@yohfernads01), Unsplash License:
  /// https://unsplash.com/photos/uvfnNME8NS0
  static const String beachTennisBanner =
      'https://images.unsplash.com/photo-1705077739769-270a45d9b5df?w=600';

  /// Bicicleta sobre a rede de vôlei, com bola de futebol, na areia.
  /// chaim weingarten (@chaim_weingarten), Unsplash License:
  /// https://unsplash.com/photos/_dD7i0CNJjU
  static const String footvolleyBanner =
      'https://images.unsplash.com/photo-1761129040460-8aa5c7e4ab37?w=600';

  /// Ataque na rede de vôlei de praia ao pôr do sol.
  /// Colton Duke (@csoref), Unsplash License:
  /// https://unsplash.com/photos/V5qPDfTTVL8
  static const String beachVolleyballBanner =
      'https://images.unsplash.com/photo-1521138054413-5a47d349b7af?w=600';

  /// Bola de futebol na areia, com jogadores ao fundo.
  /// T R A V E L E R G E E K (@travelergeek), Unsplash License:
  /// https://unsplash.com/photos/vPljorO7RyE
  static const String beachSoccerBanner =
      'https://images.unsplash.com/photo-1506964001924-75319510163f?w=600';

  /// Raquetes de padel e bolas sobre a quadra azul.
  /// Sergio Contreras (@contarcos), Unsplash License:
  /// https://unsplash.com/photos/wLAtpQ53Pfw
  static const String padelBanner =
      'https://images.unsplash.com/photo-1658723826297-fe4d1b1e6600?w=600';

  /// Salto de skate numa pista de concreto ao entardecer.
  /// Tom Morbey (@tommorbey), Unsplash License:
  /// https://unsplash.com/photos/r1SwcagHVG0
  static const String skateBanner =
      'https://images.unsplash.com/photo-1597019558926-3eef445fdf60?w=600';

  /// Raquete e bola de tênis sobre a quadra.
  /// Guilherme Maggieri (@gmaggieri), Unsplash License:
  /// https://unsplash.com/photos/OH5g9IgcMWs
  static const String tennisBanner =
      'https://images.unsplash.com/photo-1542144582-1ba00456b5e3?w=600';

  /// Jogada de handebol em quadra coberta.
  /// Kryštof Zajíček (@krystof_007), Unsplash License:
  /// https://unsplash.com/photos/YN2xypsV_cM
  static const String handballBanner =
      'https://images.unsplash.com/photo-1584196825674-e6f64590b914?w=600';

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
