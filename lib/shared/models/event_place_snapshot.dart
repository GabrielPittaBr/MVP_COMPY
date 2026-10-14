import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import 'sport_place.dart';

/// Imagem imutável do Local Esportivo incorporada a um Evento Esportivo.
///
/// Não consulta `places` durante a leitura: o snapshot preserva o contexto
/// histórico mesmo após edição ou desativação do local.
class EventPlaceSnapshot extends Equatable {
  const EventPlaceSnapshot({
    required this.name,
    required this.address,
    required this.coordinates,
  });

  final String name;
  final PlaceAddress address;
  final LatLng coordinates;

  factory EventPlaceSnapshot.fromPlace(SportPlace place) => EventPlaceSnapshot(
        name: place.name,
        address: place.address,
        coordinates: place.coordinates,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'address': address.toMap(),
        'coordinates': GeoPoint(coordinates.latitude, coordinates.longitude),
      };

  static EventPlaceSnapshot? tryFromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (!map.keys.toSet().containsAll(
      const <String>{'name', 'address', 'coordinates'},
    )) {
      return null;
    }
    final name = map['name'];
    final address = PlaceAddress.tryFromMap(map['address']);
    final coordinates = map['coordinates'];
    if (name is! String ||
        name.trim().isEmpty ||
        address == null ||
        coordinates is! GeoPoint) {
      return null;
    }
    return EventPlaceSnapshot(
      name: name,
      address: address,
      coordinates: LatLng(coordinates.latitude, coordinates.longitude),
    );
  }

  @override
  List<Object?> get props => <Object?>[name, address, coordinates];
}
