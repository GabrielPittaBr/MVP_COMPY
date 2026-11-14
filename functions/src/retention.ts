import { Timestamp } from 'firebase-admin/firestore';

/**
 * Prazos de retenção da Política de Privacidade (chore/lgpd).
 *
 * Os documentos levam `expiresAt`, e as políticas de TTL do Firestore
 * (`firestore.indexes.json`, `fieldOverrides`) os apagam depois do prazo. Mudou
 * um prazo, muda também a tabela da seção 6 de `site/privacidade.html`.
 */
export const notificationRetentionDays = 90;
export const moderationRecordRetentionYears = 5;

const dayMs = 24 * 60 * 60 * 1000;

/** Instante [days] dias depois de [nowMs]. */
export function expiresAfterDays(days: number, nowMs: number = Date.now()): Timestamp {
  return Timestamp.fromMillis(nowMs + days * dayMs);
}

/** `expiresAt` de uma notificação criada agora. */
export const notificationExpiresAt = (nowMs: number = Date.now()) =>
  expiresAfterDays(notificationRetentionDays, nowMs);

/** `expiresAt` de um registro de `adminOperations` criado agora. */
export function moderationRecordExpiresAt(nowMs: number = Date.now()): Timestamp {
  const date = new Date(nowMs);
  date.setUTCFullYear(date.getUTCFullYear() + moderationRecordRetentionYears);
  return Timestamp.fromDate(date);
}
