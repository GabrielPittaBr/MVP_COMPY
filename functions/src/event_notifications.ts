import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';

import { administrativeFunctionsRegion } from './config.js';
import { creatorIdOf, participantIdsOf } from './event_documents.js';

/** Id determinístico: a reentrega do gatilho não duplica a notificação. */
export const eventEndedNotificationId = (eventId: string) => `eventEnded_${eventId}`;

/** Rascunho de uma notificação `eventEnded` para um participante. */
export interface EventEndedNotificationDraft {
  readonly uid: string;
  readonly id: string;
  readonly eventId: string;
  readonly eventTitle: string;
  readonly sport: string;
  readonly creatorId: string;
  readonly endedAutomatically: boolean;
  /**
   * O criador que encerrou à mão já foi direto avaliar: a notificação dele
   * nasce lida. No encerramento automático ela nasce não lida, e é ela que
   * dispara o aviso único no app (D5).
   */
  readonly readOnCreate: boolean;
}

const hasValue = (value: unknown) => value !== undefined && value !== null;

/**
 * Uma notificação por participante quando o evento passa de "sem
 * `endedAt`" para "com `endedAt`". Qualquer outra atualização (join,
 * `ratedBy`, edição) não cria nada.
 */
export function planEventEndedNotifications(
  eventId: string,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
): EventEndedNotificationDraft[] {
  if (after === undefined || hasValue(before?.endedAt) || !hasValue(after.endedAt)) return [];

  const creatorId = creatorIdOf(after);
  const endedAutomatically = after.endedAutomatically === true;
  return participantIdsOf(after).map((uid) => ({
    uid,
    id: eventEndedNotificationId(eventId),
    eventId,
    eventTitle: typeof after.title === 'string' ? after.title : '',
    sport: typeof after.sport === 'string' ? after.sport : '',
    creatorId,
    endedAutomatically,
    readOnCreate: uid === creatorId && !endedAutomatically,
  }));
}

export interface NotificationsGateway {
  /** Cria a notificação; devolve `false` se ela já existia (reentrega). */
  createIfAbsent(draft: EventEndedNotificationDraft): Promise<boolean>;
}

export function createOnEventEndedHandler(gateway: NotificationsGateway) {
  return async (
    eventId: string,
    before: Record<string, unknown> | undefined,
    after: Record<string, unknown> | undefined,
  ): Promise<number> => {
    let created = 0;
    for (const draft of planEventEndedNotifications(eventId, before, after)) {
      if (await gateway.createIfAbsent(draft)) created++;
    }
    return created;
  };
}

/** Código gRPC ALREADY_EXISTS, que o `create` devolve. */
const grpcAlreadyExists = 6;

export function createFirestoreNotificationsGateway(): NotificationsGateway {
  const firestore = getFirestore();
  return {
    // `create`, e nunca `set`: numa reentrega, o `set` zeraria o `readAt` de
    // quem já leu.
    createIfAbsent: async (draft) => {
      const ref = firestore.collection('users').doc(draft.uid).collection('notifications').doc(draft.id);
      try {
        await ref.create({
          type: 'eventEnded',
          eventId: draft.eventId,
          eventTitle: draft.eventTitle,
          sport: draft.sport,
          creatorId: draft.creatorId,
          endedAutomatically: draft.endedAutomatically,
          createdAt: FieldValue.serverTimestamp(),
          readAt: draft.readOnCreate ? FieldValue.serverTimestamp() : null,
          completedAt: null,
        });
        return true;
      } catch (error) {
        if (typeof error === 'object' && error !== null && 'code' in error && error.code === grpcAlreadyExists) {
          return false;
        }
        throw error;
      }
    },
  };
}

// Cobre o encerramento manual (criador) e o automático (Function) pelo mesmo
// caminho: os dois gravam `endedAt`. Região nas próprias opções, como as
// demais Functions do codebase.
export const onEventEnded = onDocumentUpdated(
  { document: 'events/{eventId}', region: administrativeFunctionsRegion },
  async (event) => {
    const change = event.data;
    if (change === undefined) return;
    await createOnEventEndedHandler(createFirestoreNotificationsGateway())(
      event.params.eventId,
      change.before.data(),
      change.after.data(),
    );
  },
);
