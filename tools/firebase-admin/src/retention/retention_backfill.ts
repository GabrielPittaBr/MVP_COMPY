import { FieldPath, Timestamp, type Firestore } from 'firebase-admin/firestore';

/**
 * Prazos da Política de Privacidade (chore/lgpd) para documentos criados antes
 * das políticas de TTL: as notificações expiram 90 dias depois de criadas e os
 * registros de `adminOperations`, 5 anos depois. Os documentos novos já nascem
 * com `expiresAt` (functions/src/retention.ts); este backfill só completa os
 * antigos e nunca mexe em quem já tem o campo.
 */
export const notificationRetentionDays = 90;
export const moderationRecordRetentionYears = 5;

const dayMs = 24 * 60 * 60 * 1000;

export interface RetentionCandidate {
  readonly path: string;
  readonly createdAt: unknown;
  readonly expiresAt: unknown;
}

export interface RetentionBackfillGateway {
  listNotifications(): AsyncIterable<RetentionCandidate>;
  listAdminOperations(): AsyncIterable<RetentionCandidate>;
  setExpiresAt(path: string, expiresAt: Timestamp): Promise<void>;
}

export interface RetentionBackfillResult {
  readonly notificationsUpdated: number;
  readonly operationsUpdated: number;
  readonly unchanged: number;
}

const millisOf = (value: unknown): number | null =>
  value instanceof Timestamp ? value.toMillis() : value instanceof Date ? value.getTime() : null;

export function notificationExpiry(createdAt: unknown, nowMs: number): Timestamp {
  return Timestamp.fromMillis((millisOf(createdAt) ?? nowMs) + notificationRetentionDays * dayMs);
}

export function operationExpiry(createdAt: unknown, nowMs: number): Timestamp {
  const date = new Date(millisOf(createdAt) ?? nowMs);
  date.setUTCFullYear(date.getUTCFullYear() + moderationRecordRetentionYears);
  return Timestamp.fromDate(date);
}

export async function backfillRetentionExpiry(
  gateway: RetentionBackfillGateway,
  { dryRun, nowMs = Date.now() }: { readonly dryRun: boolean; readonly nowMs?: number },
): Promise<RetentionBackfillResult> {
  let notificationsUpdated = 0;
  let operationsUpdated = 0;
  let unchanged = 0;

  for await (const notification of gateway.listNotifications()) {
    if (notification.expiresAt !== undefined && notification.expiresAt !== null) {
      unchanged += 1;
      continue;
    }
    if (!dryRun) await gateway.setExpiresAt(notification.path, notificationExpiry(notification.createdAt, nowMs));
    notificationsUpdated += 1;
  }

  for await (const operation of gateway.listAdminOperations()) {
    if (operation.expiresAt !== undefined && operation.expiresAt !== null) {
      unchanged += 1;
      continue;
    }
    if (!dryRun) await gateway.setExpiresAt(operation.path, operationExpiry(operation.createdAt, nowMs));
    operationsUpdated += 1;
  }

  return { notificationsUpdated, operationsUpdated, unchanged };
}

export function createFirestoreRetentionBackfillGateway(firestore: Firestore): RetentionBackfillGateway {
  async function* paged(query: FirebaseFirestore.Query): AsyncIterable<RetentionCandidate> {
    let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    do {
      const page = await (last === undefined ? query : query.startAfter(last)).limit(250).get();
      for (const document of page.docs) {
        const data = document.data();
        yield { path: document.ref.path, createdAt: data.createdAt, expiresAt: data.expiresAt };
      }
      last = page.docs.at(-1);
    } while (last !== undefined);
  }

  return {
    listNotifications: () => paged(firestore.collectionGroup('notifications').orderBy(FieldPath.documentId())),
    listAdminOperations: () => paged(firestore.collection('adminOperations').orderBy(FieldPath.documentId())),
    setExpiresAt: async (path, expiresAt) => {
      await firestore.doc(path).update({ expiresAt });
    },
  };
}
