import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import 'sport.dart';

/// Local pré-cadastrado onde eventos podem acontecer (pin fixo no mapa).
///
/// Os locais são curados pela equipe de desenvolvimento: cada pin define
/// as coordenadas exatas e a lista de esportes praticáveis ali. O usuário
/// só pode criar eventos em locais desta lista e com esportes compatíveis
/// (RN: impedir esportes incompatíveis com a estrutura do local).
class EventLocation extends Equatable {
  const EventLocation({
    required this.id,
    required this.name,
    required this.city,
    required this.coordinates,
    required this.allowedSports,
  });

  final String id;
  final String name;
  final String city;
  final LatLng coordinates;
  final List<Sport> allowedSports;

  /// Parque do Trabalhador — o local mais famoso para esportes em Taquara.
  /// Base para os demais locais que serão cadastrados futuramente.
  static const EventLocation parqueDoTrabalhador = EventLocation(
    id: 'parque_do_trabalhador',
    name: 'Parque do Trabalhador',
    city: 'Taquara',
    coordinates: LatLng(-29.656276729317323, -50.787726691670045),
    allowedSports: <Sport>[
      Sport.basquete,
      Sport.futsal,
      Sport.volei,
      Sport.corrida,
      Sport.ciclismo,
      Sport.caminhada,
    ],
  );

  /// Locais disponíveis para seleção no app.
  static const List<EventLocation> all = <EventLocation>[parqueDoTrabalhador];

  @override
  List<Object?> get props => <Object?>[id, name, city, coordinates, allowedSports];
}
