import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/maps/data/repositories/places_repository_impl.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/sport_place.dart';

void main() {
  const repository = PlacesRepositoryImpl();

  group('PlacesRepositoryImpl', () {
    test('getAll devolve o catálogo curado — nunca lista vazia', () async {
      // O bug que motivou a tarefa 6: com Firebase ligado o repositório
      // devolvia [] e o mapa ficava sem nenhum pin.
      final places = await repository.getAll();
      expect(places, isNotEmpty);
      expect(places, contains(SportPlace.parqueDoTrabalhador));
    });

    test('getBySport filtra pelos esportes permitidos', () async {
      for (final sport in Sport.values) {
        final places = await repository.getBySport(sport);
        expect(
          places.every((p) => p.allowedSports.contains(sport)),
          isTrue,
          reason: 'local sem $sport apareceu no filtro',
        );
      }

      final futebol = await repository.getBySport(Sport.futebol);
      expect(futebol, contains(SportPlace.parqueDoTrabalhador));
    });
  });

  test('todo local do catálogo tem ao menos um esporte', () {
    // primarySport (ícone do pin) lê allowedSports.first.
    for (final place in SportPlace.all) {
      expect(place.allowedSports, isNotEmpty, reason: place.id);
    }
  });
}
