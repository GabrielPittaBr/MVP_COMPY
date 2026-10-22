import '../../../../core/utils/text_normalizer.dart';
import '../../../../shared/models/sport.dart';
import '../../../../shared/models/sport_place.dart';

/// Filtro de descoberta aplicado sobre o stream ativo já carregado.
List<SportPlace> filterMapPlaces(
  Iterable<SportPlace> places, {
  String query = '',
  Sport? sport,
}) {
  final normalizedQuery = TextNormalizer.normalize(query);
  return places
      .where((place) => place.status == PlaceStatus.active)
      .where((place) =>
          normalizedQuery.isEmpty ||
          place.nameLower.startsWith(normalizedQuery))
      .where((place) => sport == null || place.sports.contains(sport))
      .toList(growable: false);
}
