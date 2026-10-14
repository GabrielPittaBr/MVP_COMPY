import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../core/utils/text_normalizer.dart';
import 'sport.dart';

enum PlaceStatus { active, inactive }

class PlaceAddress extends Equatable {
  const PlaceAddress({
    required this.street,
    required this.city,
    required this.cityLower,
    required this.state,
    this.number,
    this.complement,
    this.neighborhood,
    this.postalCode,
  });

  final String street;
  final String city;
  final String cityLower;
  final String state;
  final String? number;
  final String? complement;
  final String? neighborhood;
  final String? postalCode;

  String get formatted {
    final streetLine = <String>[street, if (number != null) number!]
        .where((part) => part.isNotEmpty)
        .join(', ');
    return <String>[
      if (streetLine.isNotEmpty) streetLine,
      if (complement?.isNotEmpty == true) complement!,
      if (neighborhood?.isNotEmpty == true) neighborhood!,
      '$city - $state',
    ].join(' · ');
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'street': street,
        'city': city,
        'cityLower': cityLower,
        'state': state,
        if (number != null) 'number': number,
        if (complement != null) 'complement': complement,
        if (neighborhood != null) 'neighborhood': neighborhood,
        if (postalCode != null) 'postalCode': postalCode,
      };

  static PlaceAddress? tryFromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    const allowed = <String>{
      'street',
      'city',
      'cityLower',
      'state',
      'number',
      'complement',
      'neighborhood',
      'postalCode',
    };
    if (!allowed.containsAll(map.keys) ||
        !map.keys
            .toSet()
            .containsAll(<String>{'street', 'city', 'cityLower', 'state'})) {
      return null;
    }
    for (final key in map.keys) {
      if (map[key] is! String) return null;
    }
    final street = (map['street'] as String).trim();
    final city = (map['city'] as String).trim();
    final cityLower = map['cityLower'] as String;
    final state = map['state'] as String;
    final number = _optionalTrimmed(map['number']);
    final complement = _optionalTrimmed(map['complement']);
    final neighborhood = _optionalTrimmed(map['neighborhood']);
    final postalCode = map['postalCode'] as String?;
    const validStates = <String>{
      'AC',
      'AL',
      'AP',
      'AM',
      'BA',
      'CE',
      'DF',
      'ES',
      'GO',
      'MA',
      'MT',
      'MS',
      'MG',
      'PA',
      'PB',
      'PR',
      'PE',
      'PI',
      'RJ',
      'RN',
      'RS',
      'RO',
      'RR',
      'SC',
      'SP',
      'SE',
      'TO',
    };
    if (street.isEmpty ||
        street.length > 160 ||
        city.isEmpty ||
        city.length > 100 ||
        cityLower != TextNormalizer.normalize(city) ||
        !validStates.contains(state) ||
        (number != null && number.length > 20) ||
        (complement != null && complement.length > 120) ||
        (neighborhood != null && neighborhood.length > 100) ||
        (postalCode != null && !RegExp(r'^\d{8}$').hasMatch(postalCode))) {
      return null;
    }
    return PlaceAddress(
      street: street,
      city: city,
      cityLower: cityLower,
      state: state,
      number: number,
      complement: complement,
      neighborhood: neighborhood,
      postalCode: postalCode,
    );
  }

  static String? _optionalTrimmed(Object? value) {
    if (value == null) return null;
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props => <Object?>[
        street,
        city,
        cityLower,
        state,
        number,
        complement,
        neighborhood,
        postalCode,
      ];
}

/// Local Esportivo parseado do contrato Firestore `places/{placeId}`.
class SportPlace extends Equatable {
  const SportPlace({
    required this.id,
    required this.name,
    required this.nameLower,
    required this.description,
    required this.address,
    required this.coordinates,
    required this.sports,
    required this.primarySport,
    required this.status,
    required this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String nameLower;
  final String description;
  final PlaceAddress address;
  final LatLng coordinates;
  final List<Sport> sports;
  final Sport primarySport;
  final PlaceStatus status;
  final String imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Compatibilidade temporária dos consumidores existentes; os tickets de
  // mapa/eventos/mensagens migram esses acessos para o contrato explícito.
  String get city => address.city;
  String get formattedAddress => address.formatted;
  List<Sport> get allowedSports => sports;

  SportPlace copyWithStatus(PlaceStatus newStatus) => SportPlace(
        id: id,
        name: name,
        nameLower: nameLower,
        description: description,
        address: address,
        coordinates: coordinates,
        sports: sports,
        primarySport: primarySport,
        status: newStatus,
        imageUrl: imageUrl,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static SportPlace? tryFromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    try {
      const allowedFields = <String>{
        'name',
        'nameLower',
        'description',
        'address',
        'sports',
        'primarySport',
        'coordinates',
        'imageUrl',
        'status',
        'createdAt',
        'updatedAt',
      };
      if (!allowedFields.containsAll(data.keys) ||
          !data.keys.toSet().containsAll(allowedFields)) {
        return null;
      }
      final name = data['name'];
      final nameLower = data['nameLower'];
      final description = data['description'];
      final imageUrl = data['imageUrl'];
      final statusRaw = data['status'];
      final coordinatesRaw = data['coordinates'];
      final sportsRaw = data['sports'];
      final primarySport = Sport.tryParse(data['primarySport']);
      final address = PlaceAddress.tryFromMap(data['address']);
      final createdAt = data['createdAt'];
      final updatedAt = data['updatedAt'];
      final sports = Sport.parseList(sportsRaw);
      if (imageUrl is! String || imageUrl.length > 2048) return null;
      final uri = Uri.tryParse(imageUrl);
      if (name is! String ||
          name.trim().length < 3 ||
          name.trim().length > 120 ||
          nameLower is! String ||
          nameLower != TextNormalizer.normalize(name) ||
          description is! String ||
          description.trim().length < 20 ||
          description.trim().length > 1500 ||
          address == null ||
          sportsRaw is! List ||
          sports.isEmpty ||
          sports.length > 8 ||
          sports.length != sportsRaw.length ||
          sports.toSet().length != sports.length ||
          primarySport == null ||
          !sports.contains(primarySport) ||
          coordinatesRaw is! GeoPoint ||
          !coordinatesRaw.latitude.isFinite ||
          !coordinatesRaw.longitude.isFinite ||
          coordinatesRaw.latitude < -90 ||
          coordinatesRaw.latitude > 90 ||
          coordinatesRaw.longitude < -180 ||
          coordinatesRaw.longitude > 180 ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          statusRaw is! String ||
          !<String>{'active', 'inactive'}.contains(statusRaw) ||
          createdAt is! Timestamp ||
          updatedAt is! Timestamp) {
        return null;
      }
      return SportPlace(
        id: id,
        name: name.trim(),
        nameLower: nameLower,
        description: description.trim(),
        address: address,
        coordinates: LatLng(coordinatesRaw.latitude, coordinatesRaw.longitude),
        sports: List<Sport>.unmodifiable(sports),
        primarySport: primarySport,
        status: PlaceStatus.values.byName(statusRaw),
        imageUrl: imageUrl,
        createdAt: createdAt.toDate(),
        updatedAt: updatedAt.toDate(),
      );
    } catch (_) {
      // Documento incompatível/malformado é ignorado sem derrubar o stream.
      return null;
    }
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        name,
        nameLower,
        description,
        address,
        coordinates,
        sports,
        primarySport,
        status,
        imageUrl,
        createdAt,
        updatedAt,
      ];
}
