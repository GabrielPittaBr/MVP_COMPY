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

class AdminPlaceImage {
  const AdminPlaceImage({required this.url, this.source});

  final String url;
  final String? source;

  factory AdminPlaceImage.fromMap(Map<dynamic, dynamic> map) => AdminPlaceImage(
    url: map['url'] as String,
    source: _optionalNonBlank(map['source']),
  );

  Map<String, Object> toFirestore() => <String, Object>{
    'url': url.trim(),
    'source': ?_optionalNonBlank(source),
  };
}

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
    this.images = const <AdminPlaceImage>[],
    this.accessType,
    this.contactPhone,
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
  final List<AdminPlaceImage> images;
  final String? accessType;
  final String? contactPhone;
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
        (data['accessType'] != null &&
            data['accessType'] != 'public' &&
            data['accessType'] != 'private') ||
        (data['contactPhone'] != null && data['contactPhone'] is! String) ||
        (data['status'] != 'active' && data['status'] != 'inactive') ||
        data['createdAt'] is! Timestamp ||
        data['updatedAt'] is! Timestamp) {
      throw FormatException('Documento places/${document.id} inválido.');
    }
    final imageUrl = data['imageUrl'] as String;
    final rawImages = data['images'];
    final images = rawImages == null
        ? <AdminPlaceImage>[AdminPlaceImage(url: imageUrl)]
        : rawImages is List &&
              rawImages.isNotEmpty &&
              rawImages.length <= 8 &&
              rawImages.every(
                (image) =>
                    image is Map &&
                    image['url'] is String &&
                    (image['source'] == null || image['source'] is String),
              )
        ? rawImages
              .cast<Map<dynamic, dynamic>>()
              .map(AdminPlaceImage.fromMap)
              .toList()
        : throw FormatException(
            'Galeria do documento places/${document.id} inválida.',
          );
    if (images.first.url != imageUrl) {
      throw FormatException(
        'Capa do documento places/${document.id} não corresponde à galeria.',
      );
    }
    final accessType = data['accessType'] as String?;
    final contactPhone = data['contactPhone'] as String?;
    if (accessType == 'private' &&
        (contactPhone == null || !isValidAdminBrazilianPhone(contactPhone))) {
      throw FormatException(
        'Telefone do documento places/${document.id} inválido.',
      );
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
      imageUrl: imageUrl,
      images: List<AdminPlaceImage>.unmodifiable(images),
      accessType: accessType,
      contactPhone: contactPhone,
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
    images: images,
    accessType: accessType,
    contactPhone: contactPhone ?? '',
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
    this.images = const <AdminPlaceImage>[],
    this.accessType = 'public',
    this.contactPhone = '',
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
  final List<AdminPlaceImage> images;
  final String? accessType;
  final String contactPhone;

  List<AdminPlaceImage> get effectiveImages => images.isEmpty
      ? <AdminPlaceImage>[AdminPlaceImage(url: imageUrl)]
      : images;

  Map<String, String> validate({bool requireAccessType = false}) {
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
    if (effectiveImages.isEmpty || effectiveImages.length > 8) {
      errors['images'] = 'Adicione de 1 a 8 imagens para o local.';
    }
    for (var i = 0; i < effectiveImages.length; i++) {
      final image = effectiveImages[i];
      final uri = Uri.tryParse(image.url.trim());
      if (image.url.trim().length > 2048 ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty) {
        errors['images'] = 'Informe uma URL HTTPS válida para cada imagem.';
        errors['imageUrl'] = errors['images']!;
        break;
      }
      if ((image.source?.trim().length ?? 0) > 200) {
        errors['images'] = 'A fonte da imagem deve ter até 200 caracteres.';
        break;
      }
    }
    if (requireAccessType && accessType == null) {
      errors['accessType'] = 'Selecione se o local é público ou privado.';
    } else if (accessType != null &&
        accessType != 'public' &&
        accessType != 'private') {
      errors['accessType'] = 'Selecione um tipo de local válido.';
    }
    if (accessType == 'private' && !isValidAdminBrazilianPhone(contactPhone)) {
      errors['contactPhone'] = 'Informe um telefone brasileiro válido com DDD.';
    }
    return errors;
  }

  Map<String, Object> toFirestoreFields({bool requireAccessType = false}) {
    final errors = validate(requireAccessType: requireAccessType);
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
    final cleanImages = effectiveImages
        .map((image) => image.toFirestore())
        .toList(growable: false);
    final phoneDigits = contactPhone.replaceAll(RegExp(r'\D'), '');
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
      'imageUrl': effectiveImages.first.url.trim(),
      'images': cleanImages,
      'accessType': ?accessType,
      if (accessType == 'private') 'contactPhone': phoneDigits,
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

bool isValidAdminBrazilianPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return RegExp(r'^[1-9][0-9][0-9]{8,9}$').hasMatch(digits);
}

String formatAdminBrazilianPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.length <= 2) return '($digits';
  final ddd = digits.substring(0, 2);
  final subscriber = digits.substring(2);
  final separatorAt = subscriber.length > 8 ? 5 : 4;
  final formattedSubscriber = subscriber.length > separatorAt
      ? '${subscriber.substring(0, separatorAt)}-${subscriber.substring(separatorAt)}'
      : subscriber;
  return '($ddd) $formattedSubscriber';
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
