import 'package:equatable/equatable.dart';

import '../../../../shared/models/event.dart';
import '../../../../shared/models/skill_level.dart';
import '../../../../shared/models/sport.dart';

/// Critérios da listagem de eventos, escolhidos na folha de filtros.
///
/// Tudo aqui é aplicado na consulta (Firestore `where`), nunca depois de
/// buscar: filtrar no cliente com paginação de 10 em 10 produz páginas
/// quase vazias e scroll infinito que não carrega nada.
class EventsFilter extends Equatable {
  const EventsFilter({this.sport, this.skillLevel, this.day});

  final Sport? sport;

  /// Nível pedido pelo usuário — nunca [SkillLevel.todos], que na folha
  /// significa "qualquer nível" e é representado por `null`.
  final SkillLevel? skillLevel;

  /// Dia escolhido, à meia-noite local. Filtra o intervalo `[day, day+1)`.
  final DateTime? day;

  bool get isEmpty => sport == null && skillLevel == null && day == null;
  bool get isNotEmpty => !isEmpty;

  /// Níveis que satisfazem o filtro. Um evento aberto a [SkillLevel.todos]
  /// também serve para quem procura um nível específico — quem não exige
  /// nível aceita qualquer um. Vazio quando não há filtro de nível.
  List<SkillLevel> get matchingSkillLevels => skillLevel == null
      ? const <SkillLevel>[]
      : <SkillLevel>[skillLevel!, SkillLevel.todos];

  /// Início do intervalo de data (inclusivo), ou `null` sem filtro de dia.
  DateTime? get dayStart => day;

  /// Fim do intervalo de data (exclusivo), ou `null` sem filtro de dia.
  DateTime? get dayEnd =>
      day == null ? null : DateTime(day!.year, day!.month, day!.day + 1);

  /// Um evento passa no filtro? Usado pelo modo mock, que precisa aplicar
  /// os mesmos critérios que o Firestore aplicaria.
  bool matchesSport(Sport candidate) => sport == null || candidate == sport;

  bool matchesSkillLevel(SkillLevel candidate) =>
      skillLevel == null || matchingSkillLevels.contains(candidate);

  bool matchesDay(DateTime candidate) =>
      day == null ||
      (!candidate.isBefore(dayStart!) && candidate.isBefore(dayEnd!));

  /// Um evento satisfaz **todos** os critérios? Usado onde o filtro roda no
  /// cliente: o modo mock e as seções "Criados por mim" / "Participando",
  /// que não são paginadas (ver `EventsRepositoryImpl.fetchCreatedBy`).
  bool matches(Event event) =>
      matchesSport(event.sport) &&
      matchesSkillLevel(event.skillLevel) &&
      matchesDay(event.dateTime);

  /// Cada `with*` aceita `null` para limpar aquele critério — é assim que
  /// o "x" de cada chip da lista funciona.
  EventsFilter withSport(Sport? value) =>
      EventsFilter(sport: value, skillLevel: skillLevel, day: day);

  EventsFilter withSkillLevel(SkillLevel? value) =>
      EventsFilter(sport: sport, skillLevel: value, day: day);

  EventsFilter withDay(DateTime? value) => EventsFilter(
        sport: sport,
        skillLevel: skillLevel,
        // Normaliza para meia-noite local: a comparação é por dia.
        day: value == null
            ? null
            : DateTime(value.year, value.month, value.day),
      );

  @override
  List<Object?> get props => <Object?>[sport, skillLevel, day];
}
