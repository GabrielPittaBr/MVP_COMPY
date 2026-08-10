import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_compy/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:mvp_compy/features/profile/domain/usecases/search_users.dart';

void main() {
  // Sem datasource remoto o repositório serve o catálogo mockado — é o mesmo
  // caminho que o app usa com `kUseFirebaseRepos = false`.
  final repository = ProfileRepositoryImpl(null);
  final search = SearchUsers(repository);

  group('SearchUsers', () {
    test('prefixo curto demais não consulta nada', () async {
      expect(await search.call(''), isEmpty);
      expect(await search.call('d'), isEmpty);
      expect(await search.call('@'), isEmpty);
    });

    test('acha pelo começo do handle', () async {
      final results = await search.call('dou');

      expect(results, hasLength(1));
      expect(results.single.handle, '@douglas');
    });

    test('o @ digitado não atrapalha', () async {
      final comArroba = await search.call('@dou');
      final semArroba = await search.call('dou');

      expect(comArroba.map((u) => u.id), semArroba.map((u) => u.id));
    });

    test('prefixo em maiúsculas encontra o handle minúsculo', () async {
      final results = await search.call('DOU');

      expect(results.single.handle, '@douglas');
    });

    test('não devolve o próprio usuário', () async {
      final semFiltro = await search.call('dud');
      final comFiltro = await search.call('dud', excludeUid: 'u_dudu');

      expect(semFiltro.map((u) => u.id), contains('u_dudu'));
      expect(comFiltro, isEmpty);
    });

    test('prefixo sem correspondência devolve lista vazia, não erro', () async {
      expect(await search.call('zzzz'), isEmpty);
    });

    test('respeita o limite pedido', () async {
      // Todos os handles mockados, cortados no primeiro.
      final results = await repository.searchByHandle('', limit: 1);
      expect(results.length, lessThanOrEqualTo(1));
    });
  });
}
