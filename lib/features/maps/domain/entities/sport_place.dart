import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../../../shared/models/sport.dart';

/// Local esportivo mapeado em Taquara/RS (RF04 + RN-04: somente locais
/// validados aparecem aqui).
class SportPlace extends Equatable {
  const SportPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.sport,
    required this.coordinates,
    required this.imageUrl,
    required this.rating,
    required this.ratingsCount,
    required this.description,
  });

  final String id;
  final String name;
  final String address;
  final Sport sport;
  final LatLng coordinates;
  final String imageUrl;
  final double rating;
  final int ratingsCount;
  final String description;

  @override
  List<Object?> get props => <Object?>[
        id,
        name,
        address,
        sport,
        coordinates,
        imageUrl,
        rating,
        ratingsCount,
        description,
      ];
}
