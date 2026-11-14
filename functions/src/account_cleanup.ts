import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { onDocumentDeleted } from 'firebase-functions/v2/firestore';

import { deleteDocuments } from './admin_deletion.js';
import { administrativeFunctionsRegion } from './config.js';
import { createFirestoreEventDeletionGateway } from './event_deletion.js';
import { creatorIdOf, participantIdsOf, toStringList } from './event_documents.js';
import { notificationExpiresAt } from './retention.js';

/**
 * Limpeza da exclusão de conta (chore/lgpd; LGPD arts. 15–16 e Marco Civil,
 * art. 7º, X).
 *
 * O app (`deleteAccount`) e o painel (`deleteUserAccount`) apagam a conta, a
 * foto e os documentos de `users/{uid}`; o que sobra espalhado pelo banco sai
 * aqui, no servidor, quando o perfil some:
 *
 * - eventos futuros criados pela pessoa são cancelados e os participantes,
 *   avisados; nos futuros em que ela só participava, a vaga volta;
 * - nos eventos passados e nas conversas, o nome e a foto viram "Conta
 *   excluída";
 * - as mensagens que ela enviou são apagadas;
 * - o comentário das avaliações que ela fez é apagado (a nota fica só na
 *   média), e as avaliações e a média que ela recebeu saem;
 * - o que ainda restar no Storage e em `users/{uid}` (subcoleções) é apagado.
 *
 * As denúncias e os registros de moderação ficam pelos prazos da Política.
 * Tudo é idempotente: o gatilho roda com `retry` e uma repetição só termina o
 * que faltou.
 */

export const deletedAccountName = 'Conta excluída';

/** O `UserSummary` que fica no lugar do de quem excluiu a conta. */
export const deletedAccountSummary = (uid: string) => ({
  id: uid,
  name: deletedAccountName,
  handle: '',
  avatarUrl: '',
});

/** Id determinístico: a reentrega do gatilho não duplica o aviso. */
export const eventCancelledNotificationId = (eventId: string) => `eventCancelled_${eventId}`;

export interface CleanupEvent {
  readonly id: string;
  readonly data: Record<string, unknown>;
  /** Início do evento em milissegundos; `null` quando não há `dateTime`. */
  readonly startsAtMs: number | null;
}

export type EventCleanupAction =
  | {
    readonly kind: 'cancel';
    readonly eventId: string;
    readonly notifyUids: readonly string[];
    readonly eventTitle: string;
    readonly sport: string;
  }
  | { readonly kind: 'update'; readonly eventId: string; readonly fields: Record<string, unknown> }
  | { readonly kind: 'none'; readonly eventId: string };

const hasValue = (value: unknown) => value !== undefined && value !== null;
const text = (value: unknown) => (typeof value === 'string' ? value : '');
const idOf = (participant: unknown) =>
  participant !== null && typeof participant === 'object'
    ? (participant as Record<string, unknown>).id
    : undefined;

/**
 * O que fazer com um evento ligado a quem excluiu a conta. "Futuro" é o que
 * ainda não começou nem foi encerrado; o que está acontecendo conta como
 * passado, porque já tem gente lá.
 */
export function planEventCleanup(uid: string, event: CleanupEvent, nowMs: number): EventCleanupAction {
  const { data } = event;
  const createdByUser = creatorIdOf(data) === uid;
  const upcoming = event.startsAtMs !== null && event.startsAtMs > nowMs && !hasValue(data.endedAt);
  const participants = Array.isArray(data.participants) ? data.participants : [];
  const participantIds = participantIdsOf(data);

  if (createdByUser && upcoming) {
    return {
      kind: 'cancel',
      eventId: event.id,
      notifyUids: participantIds.filter((id) => id !== uid),
      eventTitle: text(data.title),
      sport: text(data.sport),
    };
  }

  if (upcoming) {
    if (!participantIds.includes(uid)) return { kind: 'none', eventId: event.id };
    const fields: Record<string, unknown> = {
      participants: participants.filter((participant) => idOf(participant) !== uid),
    };
    if (Array.isArray(data.participantIds)) {
      fields.participantIds = toStringList(data.participantIds).filter((id) => id !== uid);
    }
    if (typeof data.remainingSpots === 'number') {
      const total = typeof data.totalSpots === 'number' ? data.totalSpots : Number.POSITIVE_INFINITY;
      fields.remainingSpots = Math.min(total, data.remainingSpots + 1);
    }
    return { kind: 'update', eventId: event.id, fields };
  }

  const fields: Record<string, unknown> = {};
  if (createdByUser) fields.creator = deletedAccountSummary(uid);
  if (participants.some((participant) => idOf(participant) === uid)) {
    fields.participants = participants.map((participant) =>
      idOf(participant) === uid
        ? { ...(participant as Record<string, unknown>), ...deletedAccountSummary(uid) }
        : participant,
    );
  }
  return Object.keys(fields).length === 0
    ? { kind: 'none', eventId: event.id }
    : { kind: 'update', eventId: event.id, fields };
}

export type EventCleanupResult = 'cancelled' | 'updated' | 'unchanged';

export interface AccountCleanupGateway {
  /** O perfil voltou a existir (conta recriada antes do gatilho). */
  profileExists(uid: string): Promise<boolean>;
  /** Ids dos eventos criados pela pessoa ou de que ela participa. */
  eventIdsOf(uid: string): Promise<string[]>;
  /** Lê o evento numa transação, aplica [planEventCleanup] e, se for o caso, cancela. */
  cleanEvent(eventId: string, uid: string, nowMs: number): Promise<EventCleanupResult>;
  conversationIdsOf(uid: string): Promise<string[]>;
  /** Apaga as mensagens enviadas pela pessoa e troca a identificação dela. */
  cleanConversation(conversationId: string, uid: string): Promise<void>;
  /** Apaga o comentário das avaliações feitas; devolve quantas mudaram. */
  anonymizeRatingsBy(uid: string): Promise<number>;
  /** Apaga as avaliações e a média recebidas; devolve quantas saíram. */
  deleteRatingsAbout(uid: string): Promise<number>;
  deleteStorage(uid: string): Promise<void>;
  /** Reserva do @username e tudo o que restar em `users/{uid}`. */
  deletePrivateData(uid: string): Promise<void>;
}

export interface AccountCleanupReport {
  readonly skipped: boolean;
  readonly eventsCancelled: number;
  readonly eventsUpdated: number;
  readonly conversations: number;
  readonly ratingsAnonymized: number;
  readonly ratingsDeleted: number;
}

export function createAccountCleanupHandler(gateway: AccountCleanupGateway, now: () => number = Date.now) {
  return async (uid: string): Promise<AccountCleanupReport> => {
    if (await gateway.profileExists(uid)) {
      return {
        skipped: true,
        eventsCancelled: 0,
        eventsUpdated: 0,
        conversations: 0,
        ratingsAnonymized: 0,
        ratingsDeleted: 0,
      };
    }

    let eventsCancelled = 0;
    let eventsUpdated = 0;
    for (const eventId of new Set(await gateway.eventIdsOf(uid))) {
      const result = await gateway.cleanEvent(eventId, uid, now());
      if (result === 'cancelled') eventsCancelled++;
      if (result === 'updated') eventsUpdated++;
    }

    const conversations = await gateway.conversationIdsOf(uid);
    for (const conversationId of conversations) await gateway.cleanConversation(conversationId, uid);

    const ratingsAnonymized = await gateway.anonymizeRatingsBy(uid);
    const ratingsDeleted = await gateway.deleteRatingsAbout(uid);
    await gateway.deleteStorage(uid);
    await gateway.deletePrivateData(uid);

    return {
      skipped: false,
      eventsCancelled,
      eventsUpdated,
      conversations: conversations.length,
      ratingsAnonymized,
      ratingsDeleted,
    };
  };
}

const millisOf = (value: unknown): number | null => {
  if (value instanceof Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return null;
};

/** Código gRPC ALREADY_EXISTS, que o `create` devolve. */
const grpcAlreadyExists = 6;
const writeChunk = 400;

export function createFirestoreAccountCleanupGateway(): AccountCleanupGateway {
  const firestore = getFirestore();
  const eventDeletion = createFirestoreEventDeletionGateway();

  const notifyCancelled = async (uid: string, action: Extract<EventCleanupAction, { kind: 'cancel' }>) => {
    const ref = firestore.collection('users').doc(uid).collection('notifications')
      .doc(eventCancelledNotificationId(action.eventId));
    try {
      await ref.create({
        type: 'eventCancelled',
        eventId: action.eventId,
        eventTitle: action.eventTitle,
        sport: action.sport,
        creatorId: '',
        endedAutomatically: false,
        createdAt: Timestamp.now(),
        readAt: null,
        completedAt: null,
        expiresAt: notificationExpiresAt(),
      });
    } catch (error) {
      if (!(typeof error === 'object' && error !== null && 'code' in error && error.code === grpcAlreadyExists)) {
        throw error;
      }
    }
  };

  return {
    profileExists: async (uid) => (await firestore.collection('users').doc(uid).get()).exists,

    eventIdsOf: async (uid) => {
      const [created, joined] = await Promise.all([
        firestore.collection('events').where('creator.id', '==', uid).get(),
        firestore.collection('events').where('participantIds', 'array-contains', uid).get(),
      ]);
      return [...created.docs, ...joined.docs].map((doc) => doc.id);
    },

    cleanEvent: async (eventId, uid, nowMs) => {
      const ref = firestore.collection('events').doc(eventId);
      const action = await firestore.runTransaction(async (transaction) => {
        const data = (await transaction.get(ref)).data();
        if (data === undefined) return { kind: 'none', eventId } as const;
        const plan = planEventCleanup(uid, { id: eventId, data, startsAtMs: millisOf(data.dateTime) }, nowMs);
        if (plan.kind === 'update') transaction.update(ref, plan.fields);
        return plan;
      });

      if (action.kind === 'cancel') {
        for (const participant of action.notifyUids) await notifyCancelled(participant, action);
        const deletable = await eventDeletion.readEvent(eventId);
        if (deletable !== null) await eventDeletion.deleteEvent(eventId, deletable);
        return 'cancelled';
      }
      return action.kind === 'update' ? 'updated' : 'unchanged';
    },

    conversationIdsOf: async (uid) =>
      (await firestore.collection('conversations').where('members', 'array-contains', uid).get())
        .docs.map((doc) => doc.id),

    cleanConversation: async (conversationId, uid) => {
      const ref = firestore.collection('conversations').doc(conversationId);
      for (;;) {
        const sent = await ref.collection('messages').where('senderId', '==', uid).limit(300).get();
        if (sent.empty) break;
        await deleteDocuments(firestore, sent.docs.map((doc) => doc.ref));
      }
      const data = (await ref.get()).data();
      if (data === undefined) return;
      const latest = await ref.collection('messages').orderBy('sentAt', 'desc').limit(1).get();
      const update: Record<string, unknown> = {
        [`memberSummaries.${uid}`]: deletedAccountSummary(uid),
        lastMessage: latest.empty ? '' : text(latest.docs[0].data().text),
      };
      // Numa conversa 1:1, tudo o que o outro não leu veio de quem saiu, e
      // essas mensagens acabaram de ser apagadas.
      for (const member of toStringList(data.members)) {
        if (member !== uid) update[`unreadCounts.${member}`] = 0;
      }
      await ref.update(update);
    },

    anonymizeRatingsBy: async (uid) => {
      const ratings = await firestore.collection('ratings').where('fromUid', '==', uid).get();
      const withComment = ratings.docs.filter((doc) => hasValue(doc.data().comment));
      for (let start = 0; start < withComment.length; start += writeChunk) {
        const batch = firestore.batch();
        for (const doc of withComment.slice(start, start + writeChunk)) batch.update(doc.ref, { comment: null });
        await batch.commit();
      }
      return withComment.length;
    },

    deleteRatingsAbout: async (uid) => {
      const ratings = await firestore.collection('ratings')
        .where('targetType', '==', 'user').where('targetId', '==', uid).get();
      await deleteDocuments(firestore, [
        ...ratings.docs.map((doc) => doc.ref),
        firestore.collection('ratingSummaries').doc(`user_${uid}`),
      ]);
      return ratings.size;
    },

    deleteStorage: async (uid) => {
      await getStorage().bucket().deleteFiles({ prefix: `users/${uid}/` });
    },

    deletePrivateData: async (uid) => {
      const usernames = await firestore.collection('usernames').where('uid', '==', uid).get();
      await deleteDocuments(firestore, usernames.docs.map((doc) => doc.ref));
      await firestore.recursiveDelete(firestore.collection('users').doc(uid));
    },
  };
}

// Dispara para a exclusão pelo app e pelo painel, que apagam `users/{uid}`.
export const onProfileDeletedCleanup = onDocumentDeleted(
  { document: 'users/{uid}', region: administrativeFunctionsRegion, retry: true, timeoutSeconds: 300 },
  async (event) => {
    await createAccountCleanupHandler(createFirestoreAccountCleanupGateway())(event.params.uid);
  },
);
