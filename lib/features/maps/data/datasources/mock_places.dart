import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../shared/models/sport.dart';
import '../../domain/entities/sport_place.dart';

/// Locais esportivos mockados em Taquara/RS (validados — RN-04).
abstract final class MockPlaces {
  static List<SportPlace> get all => <SportPlace>[
        const SportPlace(
          id: 'plc_001',
          name: 'Mesa pública de tênis de mesa',
          address: 'Rua exemplo, 123, Centro, Taquara, RS',
          sport: Sport.tenisDeMesa,
          coordinates: LatLng(-29.6503, -50.7795),
          imageUrl: AppAssets.tableTennisBanner,
          rating: 4.3,
          ratingsCount: 21,
          description:
              'Mesa com rede de ferro para jogadores iniciantes e amadores. Perfeito para jogar com amigos.',
        ),
        const SportPlace(
          id: 'plc_002',
          name: 'Campo do Parque do Trabalhador',
          address: 'Parque do Trabalhador, Taquara, RS',
          sport: Sport.futebol,
          coordinates: LatLng(-29.6520, -50.7825),
          imageUrl: AppAssets.soccerBanner,
          rating: 4.6,
          ratingsCount: 87,
          description: 'Campo gramado aberto, ideal para amistosos no fim de semana.',
        ),
        const SportPlace(
          id: 'plc_003',
          name: 'Quadra Coberta do Centro',
          address: 'Av. Júlio de Castilhos, Centro, Taquara, RS',
          sport: Sport.basquete,
          coordinates: LatLng(-29.6478, -50.7762),
          imageUrl: AppAssets.basketballBanner,
          rating: 4.1,
          ratingsCount: 42,
          description: 'Quadra coberta com piso oficial e duas tabelas.',
        ),
        const SportPlace(
          id: 'plc_004',
          name: 'Areia do Vôlei (Mercado Marques)',
          address: 'Mercado Marques, Taquara, RS',
          sport: Sport.volei,
          coordinates: LatLng(-29.6465, -50.7750),
          imageUrl: AppAssets.volleyballBanner,
          rating: 4.4,
          ratingsCount: 31,
          description: 'Quadra de areia oficial 2x2 / 4x4.',
        ),
        const SportPlace(
          id: 'plc_005',
          name: 'Quadra Aberta da Praça',
          address: 'Praça Henrique Bier, Taquara, RS',
          sport: Sport.futebol,
          coordinates: LatLng(-29.6492, -50.7780),
          imageUrl: AppAssets.soccerBanner,
          rating: 4.0,
          ratingsCount: 15,
          description: 'Quadra de futsal aberta, iluminada à noite.',
        ),
        const SportPlace(
          id: 'plc_006',
          name: 'Ginásio Municipal',
          address: 'Bairro Empresa, Taquara, RS',
          sport: Sport.basquete,
          coordinates: LatLng(-29.6535, -50.7800),
          imageUrl: AppAssets.basketballBanner,
          rating: 4.5,
          ratingsCount: 64,
          description: 'Ginásio coberto com arquibancada — usado para competições.',
        ),
      ];
}
