import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';

import { administrativeCallableOptions, type AdministrativeCallableRequest } from './admin_auth_read.js';
import {
  createFirestoreDeletionOperationsGateway,
  deleteDocuments,
  parseDeletionInput,
  refuseDeletion,
  requireAdministrator,
  runDeletionOperation,
  type DeletionOperationsGateway,
} from './admin_deletion.js';
import { participantIdsOf, toStringList } from './event_documents.js';
import { eventEndedNotificationId } from './event_notifications.js';

/** O que a exclusão precisa saber do evento para limpar o que depende dele. */
export interface DeletableEvent {
  readonly participantIds: readonly string[];
  readonly ratedBy: readonly string[];
}

export interface EventDeletionGateway {
  readEvent(eventId: string): Promise<DeletableEvent | null>;
  /**
   * Apaga o que só existe por causa do evento e, por último, o evento. Com o
   * evento por último, uma falha no meio deixa o evento lá e a repetição
   * refaz tudo.
   */
  deleteEvent(eventId: string, event: DeletableEvent): Promise<void>;
}

export interface EventDeletionResult {
  readonly eventId: string;
  readonly completedAt: string;
}

export function createDeleteEventHandler(events: EventDeletionGateway, operations: DeletionOperationsGateway) {
  return async (request: AdministrativeCallableRequest): Promise<EventDeletionResult> => {
    const input = parseDeletionInput(requireAdministrator(request), request.data, 'deleteEvent', 'eventId');
    const result = await runDeletionOperation(operations, input, async ({ isNew }) => {
      const event = await events.readEvent(input.targetId);
      if (event === null) {
        // Numa repetição, o evento sumido é a tentativa anterior que chegou
        // até o fim sem conseguir registrar o sucesso.
        if (isNew) refuseDeletion('not-found');
        return;
      }
      await events.deleteEvent(input.targetId, event);
    });
    return { eventId: result.targetId, completedAt: result.completedAt };
  };
}

export function createFirestoreEventDeletionGateway(): EventDeletionGateway {
  const firestore = getFirestore();
  return {
    readEvent: async (eventId) => {
      const data = (await firestore.collection('events').doc(eventId).get()).data();
      if (data === undefined) return null;
      return { participantIds: participantIdsOf(data), ratedBy: toStringList(data.ratedBy) };
    },
    // Saem junto: a Notificação de fim de evento de cada Participante (senão
    // a central apontaria para um evento que não existe), as Avaliações do
    // próprio evento e a Média dele. As Avaliações do Local e dos
    // Participantes ficam, para as médias deles continuarem íntegras.
    deleteEvent: async (eventId, event) => {
      await deleteDocuments(firestore, [
        ...event.participantIds.map((uid) =>
          firestore.collection('users').doc(uid).collection('notifications').doc(eventEndedNotificationId(eventId)),
        ),
        ...event.ratedBy.map((uid) => firestore.collection('ratings').doc(`${eventId}_${uid}_event_${eventId}`)),
        firestore.collection('ratingSummaries').doc(`event_${eventId}`),
      ]);
      await firestore.collection('events').doc(eventId).delete();
    },
  };
}

export const deleteEvent = onCall(administrativeCallableOptions, (request) =>
  createDeleteEventHandler(createFirestoreEventDeletionGateway(), createFirestoreDeletionOperationsGateway())(request),
);
