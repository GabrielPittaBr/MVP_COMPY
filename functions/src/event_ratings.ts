import { FieldValue, getFirestore, Timestamp, type Transaction } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { administrativeFunctionsRegion } from './config.js';
import { creatorIdOf, participantIdsOf, toStringList } from './event_documents.js';
import { eventEndToleranceMs } from './event_lifecycle.js';
import { eventEndedNotificationId } from './event_notifications.js';

const maxEventIdLength = 128;
const maxCommentLength = 500;
/** Abaixo desta nota o comentário é obrigatório (o motivo da nota baixa). */
const reasonRequiredBelow = 3;
/** Eventos anteriores à tarefa 3 não têm `endsAt`; o app assume 1h. */
const legacyDurationMs = 60 * 60 * 1000;

export type RatingTargetType = 'event' | 'place' | 'user';

export interface RatingInput {
  readonly stars: number;
  /** Aparado; `null` quando vazio. */
  readonly comment: string | null;
}

export interface ParticipantRatingInput extends RatingInput {
  readonly uid: string;
}

export interface SubmitEventRatingsInput {
  readonly eventId: string;
  readonly event: RatingInput | null;
  readonly place: RatingInput | null;
  readonly participants: readonly ParticipantRatingInput[];
}

export interface RatingEventSnapshot {
  readonly creatorId: string;
  readonly participantIds: readonly string[];
  readonly placeId: string | null;
  readonly endedAt: Date | null;
  readonly plannedEnd: Date;
  readonly ratedBy: readonly string[];
}

export interface RatingWrite extends RatingInput {
  readonly eventId: string;
  readonly fromUid: string;
  readonly targetType: RatingTargetType;
  readonly targetId: string;
}

/** A notificação `eventEnded` de quem avalia, se existir. */
export interface RatingNotificationSnapshot {
  readonly isRead: boolean;
}

/** Operações de uma transação: todas as leituras antes das escritas. */
export interface RatingsTransaction {
  readEvent(eventId: string): Promise<RatingEventSnapshot | null>;
  readNotification(uid: string, eventId: string): Promise<RatingNotificationSnapshot | null>;
  /** Cria `ratings/{eventId}_{fromUid}_{tipo}_{alvo}`; se já existir, a transação falha. */
  createRating(rating: RatingWrite): void;
  /** Soma a nota em `ratingSummaries/{tipo}_{alvo}` com incremento. */
  incrementSummary(rating: RatingWrite): void;
  addRatedBy(eventId: string, uid: string): void;
  /** Marca a notificação como "Avaliado" (e como lida, se [markRead]). */
  completeNotification(uid: string, eventId: string, markRead: boolean): void;
}

export interface RatingsGateway {
  runTransaction<T>(work: (transaction: RatingsTransaction) => Promise<T>): Promise<T>;
}

export interface RatingsCallableRequest {
  readonly data: unknown;
  readonly auth?: { readonly uid: string };
}

export interface SubmitEventRatingsResult {
  readonly ratedTargets: number;
}

/** Erro que o gateway lança quando um `create` encontra o documento já existente. */
export class RatingAlreadyExistsError extends Error {
  constructor() {
    super('A avaliação já existe.');
    this.name = 'RatingAlreadyExistsError';
  }
}

function invalid(message: string): never {
  throw new HttpsError('invalid-argument', message);
}

function requirePlainObject(value: unknown, what: string): Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    invalid(`${what} deve ser um objeto.`);
  }
  return value as Record<string, unknown>;
}

function requireOnlyKeys(value: Record<string, unknown>, allowed: readonly string[], what: string): void {
  const allowedSet = new Set(allowed);
  if (Object.keys(value).some((key) => !allowedSet.has(key))) {
    invalid(`${what} contém campos não permitidos.`);
  }
}

function parseRating(value: unknown, what: string, extraKeys: readonly string[] = []): RatingInput {
  const rating = requirePlainObject(value, what);
  requireOnlyKeys(rating, ['stars', 'comment', ...extraKeys], what);
  const { stars, comment } = rating;
  if (typeof stars !== 'number' || !Number.isInteger(stars) || stars < 1 || stars > 5) {
    invalid(`${what}: a nota deve ser um inteiro de 1 a 5.`);
  }
  let trimmed: string | null = null;
  if (comment !== undefined) {
    if (typeof comment !== 'string') invalid(`${what}: o comentário deve ser texto.`);
    trimmed = comment.trim();
    if (trimmed.length > maxCommentLength) {
      invalid(`${what}: o comentário deve ter até ${maxCommentLength} caracteres.`);
    }
    if (trimmed.length === 0) trimmed = null;
  }
  if (stars < reasonRequiredBelow && trimmed === null) {
    invalid(`${what}: notas abaixo de ${reasonRequiredBelow} precisam de comentário.`);
  }
  return { stars, comment: trimmed };
}

/** Parse estrito do payload: chaves exatas, notas inteiras e motivo nas notas baixas. */
export function parseSubmitEventRatingsInput(data: unknown): SubmitEventRatingsInput {
  const payload = requirePlainObject(data, 'O payload');
  requireOnlyKeys(payload, ['eventId', 'event', 'place', 'participants'], 'O payload');

  const { eventId } = payload;
  if (typeof eventId !== 'string' || eventId.length === 0 || eventId.length > maxEventIdLength) {
    invalid('eventId inválido.');
  }
  if (!Array.isArray(payload.participants)) {
    invalid('participants deve ser uma lista (pode ser vazia).');
  }

  const participants: ParticipantRatingInput[] = [];
  const seen = new Set<string>();
  for (const raw of payload.participants as unknown[]) {
    const item = requirePlainObject(raw, 'Cada participante');
    const { uid } = item;
    if (typeof uid !== 'string' || uid.length === 0 || uid.length > maxEventIdLength) {
      invalid('Cada participante precisa de um uid.');
    }
    if (seen.has(uid)) invalid('Um participante foi avaliado mais de uma vez.');
    seen.add(uid);
    participants.push({ uid, ...parseRating(item, 'Participante', ['uid']) });
  }

  return {
    eventId,
    event: payload.event === undefined ? null : parseRating(payload.event, 'O evento'),
    place: payload.place === undefined ? null : parseRating(payload.place, 'O local'),
    participants,
  };
}

function requireAuth(request: RatingsCallableRequest): string {
  if (request.auth === undefined) {
    throw new HttpsError('unauthenticated', 'É necessário entrar para avaliar.');
  }
  return request.auth.uid;
}

/**
 * Valida a avaliação contra o evento e grava tudo numa transação: as
 * `ratings` (ids compostos, que impedem duplicidade), os agregados de
 * `ratingSummaries`, o `ratedBy` do evento e, se existir, a notificação
 * vira "Avaliado" (tarefa 14, §6.3).
 */
export function createSubmitEventRatingsHandler(gateway: RatingsGateway, now: () => Date) {
  return async (request: RatingsCallableRequest): Promise<SubmitEventRatingsResult> => {
    const uid = requireAuth(request);
    const input = parseSubmitEventRatingsInput(request.data);

    try {
      return await gateway.runTransaction(async (transaction) => {
        const event = await transaction.readEvent(input.eventId);
        if (event === null) throw new HttpsError('not-found', 'Evento não encontrado.');
        // A notificação pode não existir (o gatilho ainda não rodou, ou o
        // evento é anterior a ela): avaliar não depende dela.
        const notification = await transaction.readNotification(uid, input.eventId);

        const ended = event.endedAt !== null || now().getTime() >= event.plannedEnd.getTime() + eventEndToleranceMs;
        if (!ended) throw new HttpsError('failed-precondition', 'Este evento ainda não terminou.');
        if (!event.participantIds.includes(uid)) {
          throw new HttpsError('permission-denied', 'Só quem participou pode avaliar.');
        }
        if (event.ratedBy.includes(uid)) throw new HttpsError('already-exists', 'Você já avaliou este evento.');

        // D14: o criador avalia o local e quem jogou, não o próprio evento.
        const isCreator = event.creatorId === uid;
        if (isCreator && input.event !== null) invalid('O organizador não avalia o próprio evento.');
        if (!isCreator && input.event === null) invalid('Falta a nota do evento.');
        if (event.placeId === null && input.place !== null) invalid('Este evento não tem local para avaliar.');
        if (event.placeId !== null && input.place === null) invalid('Falta a nota do local.');
        for (const participant of input.participants) {
          if (participant.uid === uid || !event.participantIds.includes(participant.uid)) {
            invalid('Só dá para avaliar quem participou do evento, e não a si mesmo.');
          }
        }

        const writes: RatingWrite[] = [];
        const rate = (targetType: RatingTargetType, targetId: string, rating: RatingInput) =>
          writes.push({ eventId: input.eventId, fromUid: uid, targetType, targetId, ...rating });
        if (input.event !== null) rate('event', input.eventId, input.event);
        if (input.place !== null && event.placeId !== null) rate('place', event.placeId, input.place);
        for (const participant of input.participants) {
          rate('user', participant.uid, { stars: participant.stars, comment: participant.comment });
        }

        for (const write of writes) {
          transaction.createRating(write);
          transaction.incrementSummary(write);
        }
        transaction.addRatedBy(input.eventId, uid);
        if (notification !== null) {
          transaction.completeNotification(uid, input.eventId, !notification.isRead);
        }
        return { ratedTargets: writes.length };
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof RatingAlreadyExistsError) {
        throw new HttpsError('already-exists', 'Você já avaliou este evento.');
      }
      throw new HttpsError('internal', 'Não foi possível enviar a avaliação.');
    }
  };
}

/** Código gRPC ALREADY_EXISTS, que o `create` devolve no commit. */
const grpcAlreadyExists = 6;

export function createFirestoreRatingsGateway(): RatingsGateway {
  const firestore = getFirestore();
  const notificationRef = (uid: string, eventId: string) =>
    firestore.collection('users').doc(uid).collection('notifications').doc(eventEndedNotificationId(eventId));
  return {
    runTransaction: async (work) => {
      try {
        return await firestore.runTransaction((transaction: Transaction) =>
          work({
            readEvent: async (eventId) => {
              const snapshot = await transaction.get(firestore.collection('events').doc(eventId));
              const data = snapshot.data();
              if (data === undefined) return null;
              const startsAt = (data.dateTime as Timestamp | undefined)?.toDate() ?? new Date(0);
              const endsAt = (data.endsAt as Timestamp | undefined)?.toDate();
              return {
                creatorId: creatorIdOf(data),
                participantIds: participantIdsOf(data),
                placeId: typeof data.placeId === 'string' ? data.placeId : null,
                endedAt: (data.endedAt as Timestamp | undefined)?.toDate() ?? null,
                plannedEnd: endsAt ?? new Date(startsAt.getTime() + legacyDurationMs),
                ratedBy: toStringList(data.ratedBy),
              };
            },
            readNotification: async (uid, eventId) => {
              const snapshot = await transaction.get(notificationRef(uid, eventId));
              const data = snapshot.data();
              return data === undefined ? null : { isRead: data.readAt != null };
            },
            createRating: (rating) => {
              const id = `${rating.eventId}_${rating.fromUid}_${rating.targetType}_${rating.targetId}`;
              transaction.create(firestore.collection('ratings').doc(id), {
                eventId: rating.eventId,
                fromUid: rating.fromUid,
                targetType: rating.targetType,
                targetId: rating.targetId,
                stars: rating.stars,
                ...(rating.comment === null ? {} : { comment: rating.comment }),
                createdAt: FieldValue.serverTimestamp(),
              });
            },
            incrementSummary: (rating) => {
              const ref = firestore.collection('ratingSummaries').doc(`${rating.targetType}_${rating.targetId}`);
              transaction.set(
                ref,
                {
                  targetType: rating.targetType,
                  targetId: rating.targetId,
                  count: FieldValue.increment(1),
                  sum: FieldValue.increment(rating.stars),
                  starCounts: { [String(rating.stars)]: FieldValue.increment(1) },
                  updatedAt: FieldValue.serverTimestamp(),
                },
                { merge: true },
              );
            },
            addRatedBy: (eventId, uid) => {
              transaction.update(firestore.collection('events').doc(eventId), {
                ratedBy: FieldValue.arrayUnion(uid),
              });
            },
            completeNotification: (uid, eventId, markRead) => {
              transaction.update(notificationRef(uid, eventId), {
                completedAt: FieldValue.serverTimestamp(),
                ...(markRead ? { readAt: FieldValue.serverTimestamp() } : {}),
              });
            },
          }),
        );
      } catch (error) {
        if (typeof error === 'object' && error !== null && 'code' in error && error.code === grpcAlreadyExists) {
          throw new RatingAlreadyExistsError();
        }
        throw error;
      }
    },
  };
}

// App Check fica desligado nesta callable: o Firestore do MVP está sem
// imposição (docs/admin/firebase-deployment.md), a web não ativa App Check e
// o build debug do Android usa um token que precisaria de registro — com a
// imposição ligada, o teste no Chrome e o debug quebrariam. As callables do
// painel admin continuam com enforceAppCheck: true.
export const submitEventRatings = onCall(
  { region: administrativeFunctionsRegion, enforceAppCheck: false },
  (request) => createSubmitEventRatingsHandler(createFirestoreRatingsGateway(), () => new Date())(request),
);
