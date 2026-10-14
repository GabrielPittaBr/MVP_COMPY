import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import 'admin_places_repository.dart';

const adminPlaceSports = <String>[
  'futebol',
  'basquete',
  'volei',
  'tenisDeMesa',
  'futsal',
  'corrida',
  'ciclismo',
  'caminhada',
];

const adminBrazilianStates = <String>{
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

const adminTaquaraCenter = LatLng(-29.656276729317323, -50.787726691670045);
const adminTaquaraWarningRadiusKm = 50.0;

class AdminPlaceAddress {
  const AdminPlaceAddress({
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
    final formattedPostalCode = postalCode == null
        ? null
        : formatAdminPostalCode(postalCode!);
    final streetLine = <String>[street, ?number, ?complement].join(', ');
    return <String>[
      streetLine,
      ?neighborhood,
      '$city, $state',
      ?formattedPostalCode,
    ].join(' · ');
  }

  Map<String, Object> toFirestore() => <String, Object>{
    'street': street,
    'city': city,
    'cityLower': cityLower,
    'state': state,
    'number': ?number,
    'complement': ?complement,
    'neighborhood': ?neighborhood,
    'postalCode': ?postalCode,
  };

  factory AdminPlaceAddress.fromMap(Map<dynamic, dynamic> map) =>
      AdminPlaceAddress(
        street: map['street'] as String,
        city: map['city'] as String,
        cityLower: map['cityLower'] as String,
        state: map['state'] as String,
        number: _optionalNonBlank(map['number']),
        complement: _optionalNonBlank(map['complement']),
        neighborhood: _optionalNonBlank(map['neighborhood']),
        postalCode: _optionalNonBlank(map['postalCode']),
      );
}

class AdminPlaceRecord {
  const AdminPlaceRecord({
    required this.id,
    required this.name,
    required this.nameLower,
    required this.description,
    required this.address,
    required this.sports,
    required this.primarySport,
    required this.coordinates,
    required this.imageUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.isFromCache,
  });

  final String id;
  final String name;
  final String nameLower;
  final String description;
  final AdminPlaceAddress address;
  final List<String> sports;
  final String primarySport;
  final GeoPoint coordinates;
  final String imageUrl;
  final String status;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final bool isFromCache;

  bool get isActive => status == 'active';

  factory AdminPlaceRecord.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (!document.exists || data == null) {
      throw FormatException('Local ${document.id} não encontrado.');
    }
    final address = data['address'];
    final sports = data['sports'];
    if (data['name'] is! String ||
        data['nameLower'] is! String ||
        data['description'] is! String ||
        address is! Map ||
        sports is! List ||
        sports.any((value) => value is! String) ||
        data['primarySport'] is! String ||
        data['coordinates'] is! GeoPoint ||
        data['imageUrl'] is! String ||
        (data['status'] != 'active' && data['status'] != 'inactive') ||
        data['createdAt'] is! Timestamp ||
        data['updatedAt'] is! Timestamp) {
      throw FormatException('Documento places/${document.id} inválido.');
    }
    return AdminPlaceRecord(
      id: document.id,
      name: data['name'] as String,
      nameLower: data['nameLower'] as String,
      description: data['description'] as String,
      address: AdminPlaceAddress.fromMap(address),
      sports: List<String>.unmodifiable(sports.cast<String>()),
      primarySport: data['primarySport'] as String,
      coordinates: data['coordinates'] as GeoPoint,
      imageUrl: data['imageUrl'] as String,
      status: data['status'] as String,
      createdAt: data['createdAt'] as Timestamp,
      updatedAt: data['updatedAt'] as Timestamp,
      isFromCache: document.metadata.isFromCache,
    );
  }

  AdminPlaceDraft toDraft() => AdminPlaceDraft(
    name: name,
    description: description,
    street: address.street,
    number: address.number ?? '',
    complement: address.complement ?? '',
    neighborhood: address.neighborhood ?? '',
    city: address.city,
    state: address.state,
    postalCode: address.postalCode ?? '',
    sports: sports,
    primarySport: primarySport,
    latitude: coordinates.latitude,
    longitude: coordinates.longitude,
    imageUrl: imageUrl,
  );
}

class AdminPlaceDraft {
  const AdminPlaceDraft({
    required this.name,
    required this.description,
    required this.street,
    required this.number,
    required this.complement,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.sports,
    required this.primarySport,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
  });

  final String name;
  final String description;
  final String street;
  final String number;
  final String complement;
  final String neighborhood;
  final String city;
  final String state;
  final String postalCode;
  final List<String> sports;
  final String? primarySport;
  final double? latitude;
  final double? longitude;
  final String imageUrl;

  Map<String, String> validate() {
    final errors = <String, String>{};
    final cleanName = name.trim();
    final cleanDescription = description.trim();
    final cleanStreet = street.trim();
    final cleanCity = city.trim();
    final cleanState = state.trim().toUpperCase();
    if (cleanName.length < 3 || cleanName.length > 120) {
      errors['name'] = 'Informe um nome entre 3 e 120 caracteres.';
    }
    if (cleanDescription.length < 20 || cleanDescription.length > 1500) {
      errors['description'] =
          'A descrição deve ter entre 20 e 1.500 caracteres.';
    }
    if (cleanStreet.isEmpty || cleanStreet.length > 160) {
      errors['street'] = 'Informe uma rua com até 160 caracteres.';
    }
    if (cleanCity.isEmpty || cleanCity.length > 100) {
      errors['city'] = 'Informe uma cidade com até 100 caracteres.';
    }
    if (!adminBrazilianStates.contains(cleanState)) {
      errors['state'] = 'Selecione uma UF brasileira válida.';
    }
    _validateOptional(errors, 'number', number, 20, 'Número');
    _validateOptional(errors, 'complement', complement, 120, 'Complemento');
    _validateOptional(errors, 'neighborhood', neighborhood, 100, 'Bairro');
    if (postalCode.trim().isNotEmpty &&
        !RegExp(r'^\d{5}-?\d{3}$').hasMatch(postalCode.trim())) {
      errors['postalCode'] = 'O CEP deve conter exatamente 8 dígitos.';
    }
    if (sports.isEmpty ||
        sports.length > adminPlaceSports.length ||
        sports.toSet().length != sports.length ||
        sports.any((sport) => !adminPlaceSports.contains(sport))) {
      errors['sports'] = 'Selecione ao menos uma modalidade válida.';
    }
    if (primarySport == null || !sports.contains(primarySport)) {
      errors['primarySport'] =
          'A modalidade principal deve estar entre as selecionadas.';
    }
    if (latitude == null || latitude! < -90 || latitude! > 90) {
      errors['latitude'] = 'A latitude deve estar entre -90 e 90.';
    }
    if (longitude == null || longitude! < -180 || longitude! > 180) {
      errors['longitude'] = 'A longitude deve estar entre -180 e 180.';
    }
    final uri = Uri.tryParse(imageUrl.trim());
    if (imageUrl.trim().length > 2048 ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      errors['imageUrl'] = 'Informe uma URL HTTPS válida para a imagem.';
    }
    return errors;
  }

  Map<String, Object> toFirestoreFields() {
    final errors = validate();
    if (errors.isNotEmpty) {
      throw ArgumentError.value(errors, 'draft', 'Dados inválidos.');
    }
    final cleanName = name.trim();
    final cleanCity = city.trim();
    final postalDigits = postalCode.replaceAll(RegExp(r'\D'), '');
    final cleanNumber = _optionalNonBlank(number);
    final cleanComplement = _optionalNonBlank(complement);
    final cleanNeighborhood = _optionalNonBlank(neighborhood);
    final cleanPostalCode = postalDigits.isEmpty ? null : postalDigits;
    return <String, Object>{
      'name': cleanName,
      'nameLower': normalizeAdminSearch(cleanName),
      'description': description.trim(),
      'address': AdminPlaceAddress(
        street: street.trim(),
        city: cleanCity,
        cityLower: normalizeAdminSearch(cleanCity),
        state: state.trim().toUpperCase(),
        number: cleanNumber,
        complement: cleanComplement,
        neighborhood: cleanNeighborhood,
        postalCode: cleanPostalCode,
      ).toFirestore(),
      'sports': List<String>.unmodifiable(sports),
      'primarySport': primarySport!,
      'coordinates': GeoPoint(latitude!, longitude!),
      'imageUrl': imageUrl.trim(),
    };
  }

  bool get isFarFromTaquara {
    if (latitude == null || longitude == null) return false;
    return const Distance().as(
          LengthUnit.Kilometer,
          adminTaquaraCenter,
          LatLng(latitude!, longitude!),
        ) >
        adminTaquaraWarningRadiusKm;
  }
}

void _validateOptional(
  Map<String, String> errors,
  String key,
  String value,
  int maximum,
  String label,
) {
  final clean = value.trim();
  if (clean.isNotEmpty && clean.length > maximum) {
    errors[key] = '$label deve ter no máximo $maximum caracteres.';
  }
}

String? _optionalNonBlank(Object? value) {
  if (value is! String) return null;
  final clean = value.trim();
  return clean.isEmpty ? null : clean;
}

String formatAdminPostalCode(String value) => value.length == 8
    ? '${value.substring(0, 5)}-${value.substring(5)}'
    : value;

double adminDistanceKm(LatLng first, LatLng second) {
  const radius = 6371.0;
  final latitudeDelta = _degreesToRadians(second.latitude - first.latitude);
  final longitudeDelta = _degreesToRadians(second.longitude - first.longitude);
  final a =
      math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(_degreesToRadians(first.latitude)) *
          math.cos(_degreesToRadians(second.latitude)) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _degreesToRadians(double degrees) => degrees * (math.pi / 180);
