import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mvp_compy/features/events/data/datasources/in_memory_events_store.dart';
import 'package:mvp_compy/features/events/data/repositories/events_repository_impl.dart';
import 'package:mvp_compy/features/events/domain/entities/events_filter.dart';
import 'package:mvp_compy/shared/models/event.dart';
import 'package:mvp_compy/shared/models/skill_level.dart';
import 'package:mvp_compy/shared/models/sport.dart';
import 'package:mvp_compy/shared/models/user_summary.dart';

/// Relógio fixo dos testes. As fixtures ficam relativas a ele: com os
/// encerrados fora das listas (tarefa 14), um evento de data fixa no passado
/// sumiria de todas elas.
final _agora = DateTime.now();

void main() {
  // `_remote == null` força o ramo mock (InMemoryEventsStore), sem Firebase.
  final repo = EventsRepositoryImpl(null, clock: () => _agora);

  group('EventsRepositoryImpl.fetchPage', () {
    test('sem filtro devolve eventos de várias modalidades', () async {
      final page = await repo.fetchPage(pageSize: 50);
      expect(page.items, isNotEmpty);
      expect(page.items.map((e) => e.sport).toSet().length, greaterThan(1));
    });

    test('com filtro devolve só a modalidade pedida', () async {
      final page = await repo.fetchPage(
        pageSize: 50,
        filter: const EventsFilter(sport: Sport.futebol),
      );
      expect(page.items, isNotEmpty);
      expect(page.items.every((e) => e.sport == Sport.futebol), isTrue);
    });

    test('paginação percorre o conjunto filtrado, não o completo', () async {
      const filter = EventsFilter(sport: Sport.futebol);
      final all = await repo.fetchPage(pageSize: 50, filter: filter);
      final collected = <String>[];

      Object? cursor;
      var hasMore = true;
      // Páginas de 1 em 1: cada uma precisa vir cheia enquanto houver
      // eventos de futebol — o filtro é aplicado antes de paginar.
      while (hasMore) {
        final page =
            await repo.fetchPage(cursor: cursor, pageSize: 1, filter: filter);
        expect(page.items.every((e) => e.sport == Sport.futebol), isTrue);
        collected.addAll(page.items.map((e) => e.id));
        cursor = page.cursor;
        hasMore = page.hasMore;
      }

      expect(collected, all.items.map((e) => e.id).toList());
    });

    test('filtro por nível inclui os eventos abertos a todos os níveis',
        () async {
      final page = await repo.fetchPage(
        pageSize: 50,
        filter: const EventsFilter(skillLevel: SkillLevel.iniciante),
      );
      expect(
        page.items.every((e) =>
            e.skillLevel == SkillLevel.iniciante ||
            e.skillLevel == SkillLevel.todos),
        isTrue,
      );
    });

    test('filtro por dia recorta o intervalo [dia, dia+1)', () async {
      final todos = await repo.fetchPage(pageSize: 50);
      final referencia = todos.items.first.dateTime;
      final dia = DateTime(referencia.year, referencia.month, referencia.day);

      final page = await repo.fetchPage(
        pageSize: 50,
        filter: const EventsFilter().withDay(dia),
      );

      expect(page.items, isNotEmpty);
      expect(
        page.items.every((e) =>
            e.dateTime.year == dia.year &&
            e.dateTime.month == dia.month &&
            e.dateTime.day == dia.day),
        isTrue,
      );
    });

    test('critérios se somam em vez de se substituírem', () async {
      final base = await repo.fetchPage(
        pageSize: 50,
        filter: const EventsFilter(sport: Sport.futebol),
      );
      final combinado = await repo.fetchPage(
        pageSize: 50,
        filter: const EventsFilter(
          sport: Sport.futebol,
          skillLevel: SkillLevel.avancado,
        ).withDay(base.items.first.dateTime),
      );

      expect(combinado.items.length, lessThanOrEqualTo(base.items.length));
      expect(combinado.items.every((e) => e.sport == Sport.futebol), isTrue);
    });
  });

  group('EventsFilter', () {
    test('vazio por padrão e não-vazio com qualquer critério', () {
      expect(const EventsFilter().isEmpty, isTrue);
      expect(const EventsFilter(sport: Sport.corrida).isNotEmpty, isTrue);
      expect(
        const EventsFilter(skillLevel: SkillLevel.avancado).isNotEmpty,
        isTrue,
      );
    });

    test('cada with* limpa só o próprio critério', () {
      final filter = const EventsFilter(
        sport: Sport.volei,
        skillLevel: SkillLevel.iniciante,
      ).withDay(DateTime(2026, 8, 10));

      expect(filter.withSport(null).sport, isNull);
      expect(filter.withSport(null).skillLevel, SkillLevel.iniciante);
      expect(filter.withSport(null).day, DateTime(2026, 8, 10));
      expect(filter.withDay(null).day, isNull);
      expect(filter.withDay(null).sport, Sport.volei);
    });

    test('withDay normaliza para a meia-noite local', () {
      final filter =
          const EventsFilter().withDay(DateTime(2026, 8, 10, 21, 30));
      expect(filter.day, DateTime(2026, 8, 10));
      expect(filter.dayEnd, DateTime(2026, 8, 11));
    });

    test('nível de habilidade casa com o pedido e com "todos"', () {
      const filter = EventsFilter(skillLevel: SkillLevel.intermediario);
      expect(filter.matchesSkillLevel(SkillLevel.intermediario), isTrue);
      expect(filter.matchesSkillLevel(SkillLevel.todos), isTrue);
      expect(filter.matchesSkillLevel(SkillLevel.avancado), isFalse);
    });
  });

  group('Event.participantIds', () {
    test('espelha os ids de participants', () {
      final evento = _evento(
        id: 'evt_ids',
        criador: 'u_a',
        participantes: <UserSummary>[_usuario('u_a'), _usuario('u_b')],
      );
      expect(evento.participantIds, <String>['u_a', 'u_b']);
    });

    test('é gravado no documento — é ele que o Firestore consegue consultar',
        () {
      final evento = _evento(
        id: 'evt_ids',
        criador: 'u_a',
        participantes: <UserSummary>[_usuario('u_a'), _usuario('u_b')],
      );
      expect(evento.toMap()['participantIds'], <String>['u_a', 'u_b']);
    });
  });

  // Este grupo escreve no InMemoryEventsStore (singleton), por isso vem
  // depois dos testes de leitura acima.
  group('EventsRepositoryImpl — seções da aba Eventos', () {
    final store = InMemoryEventsStore.instance;

    test('fetchCreatedBy devolve só os do uid, ordenados por data', () async {
      const uid = 'u_criador_teste';
      // Inseridos fora de ordem de propósito: `add` empilha no topo, então
      // a ordenação por data tem que vir da consulta, não da inserção.
      store.add(_evento(
        id: 'evt_c_cedo',
        criador: uid,
        dateTime: _agora.add(const Duration(days: 1)),
      ));
      store.add(_evento(
        id: 'evt_c_tarde',
        criador: uid,
        dateTime: _agora.add(const Duration(days: 8)),
      ));
      store.add(_evento(id: 'evt_c_alheio', criador: 'u_outro_qualquer'));

      final criados = await repo.fetchCreatedBy(uid);

      expect(
        criados.map((e) => e.id),
        <String>['evt_c_cedo', 'evt_c_tarde'],
      );
    });

    test('fetchJoinedBy encontra o evento depois de entrar nele', () async {
      const uid = 'u_participante_teste';
      store.add(_evento(id: 'evt_p1', criador: 'u_dono_qualquer'));

      expect(await repo.fetchJoinedBy(uid), isEmpty);
      await repo.joinEvent('evt_p1', _usuario(uid));

      expect(
        (await repo.fetchJoinedBy(uid)).map((e) => e.id),
        contains('evt_p1'),
      );
    });

    test('trocar nome e avatar não tira o usuário da própria seção', () async {
      const uid = 'u_troca_teste';
      store.add(_evento(id: 'evt_troca', criador: 'u_dono_qualquer'));
      await repo.joinEvent(
        'evt_troca',
        const UserSummary(
          id: uid,
          name: 'Ana',
          handle: '@ana',
          avatarUrl: 'antigo.png',
        ),
      );

      // O evento guarda o UserSummary de quando a pessoa entrou. Se a
      // consulta dependesse do mapa inteiro (`arrayContains` sobre
      // `participants`, no Firestore), essa divergência a faria sumir da
      // própria lista — daí a busca ser pelo id.
      const identidadeNova = UserSummary(
        id: uid,
        name: 'Ana Paula',
        handle: '@ana',
        avatarUrl: 'novo.png',
      );
      expect(
          store.getById('evt_troca')!.participants.last, isNot(identidadeNova));

      expect(
        (await repo.fetchJoinedBy(identidadeNova.id)).map((e) => e.id),
        contains('evt_troca'),
      );
    });

    test('o filtro da folha também vale para as seções', () async {
      const uid = 'u_filtro_teste';
      store.add(_evento(id: 'evt_f_futebol', criador: uid));
      store.add(_evento(id: 'evt_f_volei', criador: uid, sport: Sport.volei));

      final criados = await repo.fetchCreatedBy(
        uid,
        filter: const EventsFilter(sport: Sport.volei),
      );

      expect(criados.map((e) => e.id), <String>['evt_f_volei']);
    });
  });

  // Também escreve no store singleton; ids e uids próprios para não cruzar
  // com os grupos acima.
  group('EventsRepositoryImpl — encerrados somem das listas (D17)', () {
    final store = InMemoryEventsStore.instance;
    const dono = 'u_dono_d17';
    const participante = 'u_participante_d17';
    const abertos = <String>{
      'evt_d17_agendado',
      'evt_d17_ao_vivo',
      'evt_d17_na_folga',
    };

    setUpAll(() {
      Event noRelogio(
        String id, {
        required Duration inicio,
        int durationMinutes = 60,
        DateTime? endedAt,
      }) =>
          _evento(
            id: id,
            criador: dono,
            participantes: <UserSummary>[
              _usuario(dono),
              _usuario(participante),
            ],
            dateTime: _agora.add(inicio),
            durationMinutes: durationMinutes,
            endedAt: endedAt,
          );

      store
        ..add(noRelogio('evt_d17_agendado', inicio: const Duration(days: 1)))
        ..add(
            noRelogio('evt_d17_ao_vivo', inicio: const Duration(minutes: -10)))
        // Passou do fim previsto, mas ainda está na folga de 1h.
        ..add(
            noRelogio('evt_d17_na_folga', inicio: const Duration(minutes: -80)))
        // O criador encerrou à mão antes do fim previsto.
        ..add(noRelogio(
          'evt_d17_encerrado_a_mao',
          inicio: const Duration(minutes: -10),
          endedAt: _agora.subtract(const Duration(minutes: 5)),
        ))
        // Fim previsto + 1h já passou: encerrado mesmo sem endedAt.
        ..add(noRelogio(
          'evt_d17_encerrado_pelo_tempo',
          inicio: const Duration(hours: -3),
        ));
    });

    Set<String> doTeste(Iterable<Event> events) => <String>{
          for (final e in events)
            if (e.id.startsWith('evt_d17')) e.id
        };

    test('"Todos os eventos" esconde os encerrados', () async {
      final page = await repo.fetchPage(pageSize: 500);
      expect(doTeste(page.items), abertos);
    });

    test('"Criados por mim" esconde os encerrados', () async {
      expect(doTeste(await repo.fetchCreatedBy(dono)), abertos);
    });

    test('"Participando" esconde os encerrados', () async {
      expect(doTeste(await repo.fetchJoinedBy(participante)), abertos);
    });

    test('a busca esconde os encerrados', () async {
      expect(doTeste(await repo.search('evt_d17')), abertos);
    });

    test('nas fixtures do mock, o ao vivo aparece e o encerrado não', () async {
      final todos =
          (await repo.fetchPage(pageSize: 500)).items.map((e) => e.id);
      final doJoao = (await repo.fetchJoinedBy('u_joao')).map((e) => e.id);

      expect(todos, contains('evt_005'));
      expect(todos, isNot(contains('evt_006')));
      expect(doJoao, contains('evt_005'));
      expect(doJoao, isNot(contains('evt_006')));
    });
  });
}

UserSummary _usuario(String id) =>
    UserSummary(id: id, name: id, handle: '@$id', avatarUrl: '');

Event _evento({
  required String id,
  required String criador,
  List<UserSummary>? participantes,
  Sport sport = Sport.futebol,
  DateTime? dateTime,
  int durationMinutes = 60,
  DateTime? endedAt,
}) {
  final dono = _usuario(criador);
  return Event(
    id: id,
    title: 'Evento $id',
    sport: sport,
    location: 'Taquara',
    coordinates: const LatLng(-29.6485, -50.7820),
    dateTime: dateTime ?? _agora.add(const Duration(days: 1)),
    durationMinutes: durationMinutes,
    endedAt: endedAt,
    skillLevel: SkillLevel.todos,
    totalSpots: 10,
    // O criador já ocupa uma vaga, como no formulário de criação.
    remainingSpots: 9,
    bannerUrl: '',
    creator: dono,
    participants: participantes ?? <UserSummary>[dono],
  );
}
