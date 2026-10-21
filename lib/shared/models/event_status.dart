import 'event.dart';

/// Fase do ciclo de vida de um Evento Esportivo (tarefa 14).
///
/// Não é gravada: o cliente deriva a fase a partir do relógio, então a tela
/// muda de "agendado" para "acontecendo" sem esperar nenhuma escrita.
enum EventStatus { scheduled, happening, ended }

/// Folga depois do fim previsto em que o evento ainda conta como
/// acontecendo. Espelhada na Function `autoEndOverdueEvents` e nas regras
/// do Firestore: passada a folga, o evento está encerrado mesmo antes de a
/// Function gravar `endedAt`.
const Duration kEventEndTolerance = Duration(hours: 1);

/// Duração máxima aceita no formulário de criação (12h). As listas usam o
/// mesmo teto para saber até quando um evento ainda pode estar aberto.
const int kMaxEventDurationMinutes = 720;

/// Início mais antigo de um evento que ainda pode estar aberto em [now]:
/// a duração máxima mais a folga. As consultas de listas usam como limite
/// inferior de `dateTime` (D17: encerrados somem das listas), o que também
/// impede os eventos passados de empurrarem os atuais para fora do `limit`.
DateTime openEventsNotBefore(DateTime now) => now.subtract(
      const Duration(minutes: kMaxEventDurationMinutes) + kEventEndTolerance,
    );

extension EventLifecycle on Event {
  /// Fase do evento no instante [now]:
  /// - `endedAt` gravado → encerrado, mesmo que antes do início;
  /// - antes de [Event.dateTime] → agendado;
  /// - até [Event.endsAt] + [kEventEndTolerance] (exclusive) → acontecendo;
  /// - depois disso → encerrado.
  EventStatus statusAt(DateTime now) {
    if (endedAt != null) return EventStatus.ended;
    if (now.isBefore(dateTime)) return EventStatus.scheduled;
    if (now.isBefore(endsAt.add(kEventEndTolerance))) {
      return EventStatus.happening;
    }
    return EventStatus.ended;
  }

  /// Acontecendo, mas já passou do fim previsto: está na folga de 1h em que
  /// o criador ainda pode encerrar antes da Function.
  bool isOverdueAt(DateTime now) =>
      statusAt(now) == EventStatus.happening && !now.isBefore(endsAt);

  /// Se [uid] já enviou a avaliação deste evento.
  bool hasRated(String uid) => ratedBy.contains(uid);
}

/// Tira de [events] os encerrados em [now], mantendo a ordem. É o filtro de
/// cliente que completa o limite inferior das consultas: um evento de 15 min
/// que terminou de manhã, ou um encerrado à mão, ainda cai dentro da janela.
List<Event> withoutEnded(Iterable<Event> events, DateTime now) => <Event>[
      for (final event in events)
        if (event.statusAt(now) != EventStatus.ended) event,
    ];
