import { getFirestore, Timestamp, type Transaction } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { eventCancelledNotificationId } from './account_cleanup.js';
import { requireTargetId } from './admin_deletion.js';
import { administrativeFunctionsRegion } from './config.js';
import { creatorIdOf } from './event_documents.js';
import { deletableEventOf, eventCleanupReferences, type DeletableEvent } from './event_deletion.js';
import { notificationExpiresAt } from './retention.js';

/**
 * Exclusão pelo Organizador (#37): quem criou o evento o apaga enquanto ele
 * não teve Encerramento, com motivo opcional, e os outros Participantes
 * recebem o aviso `eventCancelled` com `cancelledBy: 'organizer'`.
 *
 * É uma callable porque as regras não deixam o cliente apagar eventos nem
 * criar notificações. Não é a Exclusão Administrativa (`deleteEvent`): não
 * exige Administrador nem registro em `adminOperations`. A repetição é segura
 * sem esse registro: o aviso tem id determinístico e, depois do commit, o
 * evento sumido vira `not-found`, que o app trata como sucesso.
 */

export const maxOwnEventDeletionReasonLength = 200;

export interface OwnEventDeletionInput {
  readonly eventId: string;
  /** Aparado; `null` quando ausente ou vazio. */
  readonly reason: string | null;
}

export interface OwnDeletableEvent extends DeletableEvent {
  readonly creatorId: string;
  readonly ended: boolean;
  readonly title: string;
  readonly sport: string;
}

export interface EventCancelledNotice {
  readonly eventId: string;
  readonly eventTitle: string;
  readonly sport: string;
  readonly creatorId: string;
  readonly reason: string | null;
}

/** Operações de uma transação: a leitura antes das escritas. */
export interface OwnEventDeletionTransaction {
  readEvent(eventId: string): Promise<OwnDeletableEvent | null>;
  notifyCancelled(uid: string, notice: EventCancelledNotice): void;
  /** Apaga o que depende do evento e, no mesmo commit, o evento. */
  deleteEvent(eventId: string, event: DeletableEvent): void;
}

export interface OwnEventDeletionGateway {
  runTransaction<T>(work: (transaction: OwnEventDeletionTransaction) => Promise<T>): Promise<T>;
}

export interface OwnEventDeletionRequest {
  readonly data: unknown;
  readonly auth?: { readonly uid: string };
}

export interface OwnEventDeletionResult {
  readonly eventId: string;
  readonly notified: number;
}

function invalid(message: string): never {
  throw new HttpsError('invalid-argument', message);
}

/** Payload `{eventId, reason?}`, sem campos extras. */
export function parseOwnEventDeletionInput(data: unknown): OwnEventDeletionInput {
  if (data === null || typeof data !== 'object' || Array.isArray(data)) invalid('O payload deve ser um objeto.');
  const payload = data as Record<string, unknown>;
  if (Object.keys(payload).some((key) => key !== 'eventId' && key !== 'reason')) {
    invalid('O payload contém campos não permitidos.');
  }
  const eventId = requireTargetId(payload.eventId);
  const { reason } = payload;
  if (reason === undefined || reason === null) return { eventId, reason: null };
  if (typeof reason !== 'string') invalid('O motivo deve ser texto.');
  const trimmed = reason.trim();
  if (trimmed.length > maxOwnEventDeletionReasonLength) {
    invalid(`O motivo deve ter até ${maxOwnEventDeletionReasonLength} caracteres.`);
  }
  return { eventId, reason: trimmed.length === 0 ? null : trimmed };
}

/** Lê o documento `events/{id}`; os antigos sem `participantIds` também servem. */
export function ownDeletableEventOf(data: Record<string, unknown>): OwnDeletableEvent {
  return {
    ...deletableEventOf(data),
    creatorId: creatorIdOf(data),
    ended: data.endedAt !== undefined && data.endedAt !== null,
    title: typeof data.title === 'string' ? data.title : '',
    sport: typeof data.sport === 'string' ? data.sport : '',
  };
}

export function createDeleteOwnEventHandler(gateway: OwnEventDeletionGateway) {
  return async (request: OwnEventDeletionRequest): Promise<OwnEventDeletionResult> => {
    if (request.auth === undefined) {
      throw new HttpsError('unauthenticated', 'É necessário entrar para excluir o evento.');
    }
    const uid = request.auth.uid;
    const input = parseOwnEventDeletionInput(request.data);

    try {
      // Numa transação, e não num batch depois da leitura: quem entrar no
      // evento enquanto ele é excluído também recebe o aviso.
      return await gateway.runTransaction(async (transaction) => {
        const event = await transaction.readEvent(input.eventId);
        if (event === null) throw new HttpsError('not-found', 'Evento não encontrado.');
        if (event.creatorId !== uid) {
          throw new HttpsError('permission-denied', 'Só quem organiza pode excluir o evento.');
        }
        if (event.ended) throw new HttpsError('failed-precondition', 'Este evento já foi encerrado.');

        const notify = event.participantIds.filter((id) => id !== uid);
        for (const participant of notify) {
          transaction.notifyCancelled(participant, {
            eventId: input.eventId,
            eventTitle: event.title,
            sport: event.sport,
            creatorId: uid,
            reason: input.reason,
          });
        }
        transaction.deleteEvent(input.eventId, event);
        return { eventId: input.eventId, notified: notify.length };
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', 'Não foi possível excluir o evento.');
    }
  };
}

// ponytail: uma transação aceita 500 escritas (2 por participante + 2), o que
// cobre até 249 participantes; acima disso, dividir os avisos em lotes.
export function createFirestoreOwnEventDeletionGateway(): OwnEventDeletionGateway {
  const firestore = getFirestore();
  return {
    runTransaction: (work) =>
      firestore.runTransaction((transaction: Transaction) =>
        work({
          readEvent: async (eventId) => {
            const data = (await transaction.get(firestore.collection('events').doc(eventId))).data();
            return data === undefined ? null : ownDeletableEventOf(data);
          },
          // Os campos seguem o aviso da exclusão de conta (account_cleanup.ts);
          // `cancelledBy` é o que separa os dois textos no app.
          notifyCancelled: (uid, notice) => {
            transaction.set(
              firestore.collection('users').doc(uid).collection('notifications')
                .doc(eventCancelledNotificationId(notice.eventId)),
              {
                type: 'eventCancelled',
                eventId: notice.eventId,
                eventTitle: notice.eventTitle,
                sport: notice.sport,
                creatorId: notice.creatorId,
                endedAutomatically: false,
                cancelledBy: 'organizer',
                ...(notice.reason === null ? {} : { reason: notice.reason }),
                createdAt: Timestamp.now(),
                readAt: null,
                completedAt: null,
                expiresAt: notificationExpiresAt(),
              },
            );
          },
          deleteEvent: (eventId, event) => {
            for (const reference of eventCleanupReferences(firestore, eventId, event)) transaction.delete(reference);
            transaction.delete(firestore.collection('events').doc(eventId));
          },
        }),
      ),
  };
}

// Sem App Check imposto, pelo mesmo motivo da `submitEventRatings` (ver o
// comentário em event_ratings.ts).
export const deleteOwnEvent = onCall(
  { region: administrativeFunctionsRegion, enforceAppCheck: false },
  (request) => createDeleteOwnEventHandler(createFirestoreOwnEventDeletionGateway())(request),
);
