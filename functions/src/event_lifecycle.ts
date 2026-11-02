import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { administrativeFunctionsRegion } from './config.js';

/**
 * Folga depois do fim previsto em que o evento ainda conta como acontecendo.
 * Espelha `kEventEndTolerance` (app) e `withinTolerance()` (firestore.rules):
 * passado o fim previsto + 1h, o app já mostra o evento como encerrado, e
 * esta Function grava o encerramento que o criador esqueceu de fazer.
 */
export const eventEndToleranceMs = 60 * 60 * 1000;

/**
 * Até onde a varredura olha para trás. A Function roda a cada 10 min, então
 * 2 dias cobrem com folga uma fila parada (deploy, falha do Scheduler) sem
 * reler o histórico inteiro a cada execução.
 */
export const autoEndLookbackMs = 2 * 24 * 60 * 60 * 1000;

/** Teto de eventos lidos por execução. */
export const autoEndBatchLimit = 500;

export interface OverdueCandidate {
  readonly id: string;
  readonly endsAt: Date;
  readonly hasEndedAt: boolean;
}

export interface AutoEndGateway {
  /** Eventos com `endsAt` em (fromExclusive, toInclusive], por `endsAt`. */
  listEndsAtBetween(fromExclusive: Date, toInclusive: Date): Promise<OverdueCandidate[]>;
  /**
   * Encerra numa transação que relê o evento: devolve `false` se ele sumiu
   * ou se alguém (o criador, ou outra execução) encerrou no meio do caminho.
   */
  endIfStillOpen(eventId: string, endedAt: Date): Promise<boolean>;
}

/**
 * Encerra os eventos que passaram 1h do fim previsto sem `endedAt`. Grava
 * `endsAt + 1h` — um valor determinístico, o mesmo instante em que o app
 * passou a mostrar o evento como encerrado — e devolve quantos encerrou.
 */
export function createAutoEndOverdueEventsHandler(gateway: AutoEndGateway, now: () => Date) {
  return async (): Promise<number> => {
    const cutoff = new Date(now().getTime() - eventEndToleranceMs);
    const from = new Date(cutoff.getTime() - autoEndLookbackMs);
    let ended = 0;
    for (const candidate of await gateway.listEndsAtBetween(from, cutoff)) {
      if (candidate.hasEndedAt) continue;
      const endedAt = new Date(candidate.endsAt.getTime() + eventEndToleranceMs);
      if (await gateway.endIfStillOpen(candidate.id, endedAt)) ended++;
    }
    return ended;
  };
}

export function createFirestoreAutoEndGateway(): AutoEndGateway {
  const firestore = getFirestore();
  const events = firestore.collection('events');
  return {
    // Não dá para filtrar `endedAt == null` na consulta: o campo fica
    // ausente nos eventos abertos, e o Firestore não casa campo ausente com
    // `== null`. O handler descarta os já encerrados. Eventos anteriores à
    // tarefa 3, sem `endsAt`, ficam fora da consulta — o app já os trata
    // como encerrados pelo tempo.
    listEndsAtBetween: async (fromExclusive, toInclusive) => {
      const snapshot = await events
        .where('endsAt', '>', Timestamp.fromDate(fromExclusive))
        .where('endsAt', '<=', Timestamp.fromDate(toInclusive))
        .orderBy('endsAt')
        .limit(autoEndBatchLimit)
        .get();
      return snapshot.docs.map((doc) => ({
        id: doc.id,
        endsAt: (doc.get('endsAt') as Timestamp).toDate(),
        hasEndedAt: doc.get('endedAt') != null,
      }));
    },
    endIfStillOpen: async (eventId, endedAt) =>
      firestore.runTransaction(async (transaction) => {
        const ref = events.doc(eventId);
        const snapshot = await transaction.get(ref);
        if (!snapshot.exists || snapshot.get('endedAt') != null) return false;
        transaction.update(ref, {
          endedAt: Timestamp.fromDate(endedAt),
          endedAutomatically: true,
        });
        return true;
      }),
  };
}

// A região vai nas próprias opções: os re-exports do index.ts rodam antes do
// setGlobalOptions (ESM), e um deploy antigo caiu em us-central1 por isso.
export const autoEndOverdueEvents = onSchedule(
  {
    schedule: 'every 10 minutes',
    region: administrativeFunctionsRegion,
    timeZone: 'America/Sao_Paulo',
  },
  async () => {
    await createAutoEndOverdueEventsHandler(createFirestoreAutoEndGateway(), () => new Date())();
  },
);
